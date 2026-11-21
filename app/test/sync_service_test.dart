import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals_logger/data/database.dart';
import 'package:vitals_logger/data/readings_repository.dart';
import 'package:vitals_logger/sync/readings_api.dart';
import 'package:vitals_logger/sync/sync_service.dart';

/// Stands in for the server. Like the real one, it stores by id and accepts repeats.
class FakeApi implements ReadingsApi {
  final Map<String, Reading> serverStore = {};
  final List<String> calls = []; // ids, in the order they were sent
  final List<DateTime> callTimes = []; // when each call was made (fake time in fakeAsync tests)
  Future<void> Function(Reading r)? onUpload; // set to make the call fail or hang
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<void> upload(Reading r) async {
    calls.add(r.id);
    callTimes.add(clock.now());
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await onUpload?.call(r);
      serverStore[r.id] = r;
    } finally {
      inFlight--;
    }
  }
}

DioException httpError(int status) => DioException(
      requestOptions: RequestOptions(path: '/readings'),
      response: Response(requestOptions: RequestOptions(path: '/readings'), statusCode: status),
      type: DioExceptionType.badResponse,
    );

DioException networkError(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/readings'), type: type);

void main() {
  late AppDatabase db;
  late ReadingsRepository repo;
  late FakeApi api;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = ReadingsRepository(db);
    api = FakeApi();
  });
  tearDown(() => db.close());

  SyncService makeService({int maxAttempts = 5, void Function(DateTime)? onSynced}) => SyncService(
        repo: repo,
        api: api,
        maxAttempts: maxAttempts,
        onSynced: onSynced,
      );

  Future<Reading> addBp(DateTime at) =>
      repo.addReading(type: 'bp', systolic: 120, diastolic: 80, pulse: 70, measuredAt: at);

  test('success: uploads oldest first, marks synced, reports last sync time', () async {
    final newer = await addBp(DateTime.utc(2026, 1, 2));
    final older = await addBp(DateTime.utc(2026, 1, 1));
    DateTime? lastSync;

    await makeService(onSynced: (t) => lastSync = t).syncNow();

    expect(api.calls, [older.id, newer.id]);
    expect((await repo.getById(older.id))!.syncStatus, SyncStatus.synced);
    expect((await repo.getById(newer.id))!.syncStatus, SyncStatus.synced);
    expect(lastSync, isNotNull);
  });

  test('server 500: stays pending, attempt counted, error stored', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    api.onUpload = (_) async => throw httpError(500);

    final service = makeService();
    await service.syncNow();
    service.dispose(); // cancel the scheduled retry

    final row = (await repo.getById(r.id))!;
    expect(row.syncStatus, SyncStatus.pending);
    expect(row.attempts, 1);
    expect(row.lastError, 'HTTP 500');
  });

  test('timeout: error is stored, but it is the network, so no attempt is used up', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    api.onUpload = (_) async => throw networkError(DioExceptionType.receiveTimeout);

    final service = makeService();
    await service.syncNow();
    service.dispose();

    final row = (await repo.getById(r.id))!;
    expect(row.lastError, 'receiveTimeout');
    expect(row.syncStatus, SyncStatus.pending);
    expect(row.attempts, 0);
  });

  test('which errors count as network errors', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(SyncService.isNetworkError(networkError(type)), isTrue, reason: type.name);
    }
    expect(SyncService.isNetworkError(httpError(500)), isFalse); // server answered
    expect(SyncService.isNetworkError(httpError(400)), isFalse);
    expect(SyncService.isNetworkError(Exception('bug')), isFalse);
  });

  test('backoff stays capped even after a huge number of failures', () {
    final service = makeService();
    expect(service.backoffDelay(100), const Duration(minutes: 1));
    expect(service.backoffDelay(10000), const Duration(minutes: 1));
  });

  test('a long outage never makes the reading fail, and it syncs when the network is back', () {
    fakeAsync((time) {
      void settle([Duration d = Duration.zero]) {
        time.elapse(d);
        time.flushMicrotasks();
      }

      late Reading r;
      addBp(DateTime.utc(2026, 1, 1)).then((v) => r = v);
      settle();

      var offline = true;
      api.onUpload = (_) async {
        if (offline) throw networkError(DioExceptionType.connectionError);
      };
      final service = makeService(maxAttempts: 3);
      service.syncNow();
      settle(const Duration(hours: 2)); // far more tries than maxAttempts

      Reading? row;
      repo.getById(r.id).then((v) => row = v);
      settle();
      expect(api.calls.length, greaterThan(100));
      expect(row!.syncStatus, SyncStatus.pending);
      expect(row!.attempts, 0);
      expect(row!.lastError, 'connectionError');

      offline = false; // network is back: the next scheduled retry gets it through
      settle(const Duration(minutes: 2));
      repo.getById(r.id).then((v) => row = v);
      settle();
      expect(row!.syncStatus, SyncStatus.synced);
      expect(api.serverStore.length, 1);
      service.dispose();
    });
  });

  test('network retries wait 2, 4, 8, 16, 32 s and then stay at 60 s', () {
    fakeAsync((time) {
      void settle([Duration d = Duration.zero]) {
        time.elapse(d);
        time.flushMicrotasks();
      }

      addBp(DateTime.utc(2026, 1, 1));
      settle();
      api.onUpload = (_) async => throw networkError(DioExceptionType.connectionTimeout);
      final service = makeService();
      service.syncNow();
      settle(const Duration(minutes: 6));

      final gaps = [
        for (var i = 1; i < api.callTimes.length; i++) api.callTimes[i].difference(api.callTimes[i - 1]).inSeconds
      ];
      expect(gaps.take(8), [2, 4, 8, 16, 32, 60, 60, 60]);
      service.dispose();
    });
  });

  test('a new trigger (e.g. connectivity back) retries now and starts the backoff over', () {
    fakeAsync((time) {
      void settle([Duration d = Duration.zero]) {
        time.elapse(d);
        time.flushMicrotasks();
      }

      addBp(DateTime.utc(2026, 1, 1));
      settle();
      api.onUpload = (_) async => throw networkError(DioExceptionType.connectionError);
      final service = makeService();
      service.syncNow();
      settle(const Duration(seconds: 15)); // calls at 0, 2, 6, 14 s: next wait would be 16 s
      final before = api.calls.length;
      expect(before, 4);

      service.syncNow(); // e.g. Wi-Fi came back
      settle();
      expect(api.calls.length, before + 1); // tried immediately, did not wait for the 16 s timer

      settle(const Duration(seconds: 2));
      expect(api.calls.length, before + 2); // and the wait is 2 s again, not 32 s
      service.dispose();
    });
  });

  test('server rejections still count: 500 uses attempts, network errors do not', () async {
    final a = await addBp(DateTime.utc(2026, 1, 1));
    api.onUpload = (_) async => throw httpError(500);
    final service = makeService(maxAttempts: 1);
    await service.syncNow();
    expect((await repo.getById(a.id))!.syncStatus, SyncStatus.failed);

    final b = await addBp(DateTime.utc(2026, 1, 2));
    api.onUpload = (_) async => throw networkError(DioExceptionType.connectionError);
    await service.syncNow();
    service.dispose();
    final row = (await repo.getById(b.id))!;
    expect((row.syncStatus, row.attempts), (SyncStatus.pending, 0));
  });

  test('duplicate send: server keeps one copy and the row still ends up synced', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    final service = makeService();
    await service.syncNow();

    // Pretend the app never learned the first upload succeeded.
    await db.customStatement("UPDATE readings SET sync_status = 'pending' WHERE id = '${r.id}'");
    await service.syncNow();

    expect(api.calls, [r.id, r.id]);
    expect(api.serverStore.length, 1);
    expect((await repo.getById(r.id))!.syncStatus, SyncStatus.synced);
  });

  test('app killed mid-sync: row stays pending, next start sends it again without a duplicate', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));

    // Run 1: the request reaches the "server" but the response never comes back
    // (we never complete it), as if the process died right there.
    api.onUpload = (_) => Completer<void>().future;
    unawaited(makeService().syncNow());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await repo.getById(r.id))!.syncStatus, SyncStatus.pending);

    // Run 2: a fresh service on the same database.
    api.onUpload = null;
    await makeService().syncNow();

    expect((await repo.getById(r.id))!.syncStatus, SyncStatus.synced);
    expect(api.serverStore.length, 1);
  });

  test('two syncNow calls at once never run two loops', () async {
    await addBp(DateTime.utc(2026, 1, 1));
    await addBp(DateTime.utc(2026, 1, 2));
    api.onUpload = (_) => Future<void>.delayed(const Duration(milliseconds: 20));

    final service = makeService();
    await Future.wait([service.syncNow(), service.syncNow(), service.syncNow()]);

    expect(api.maxInFlight, 1);
    expect(api.calls.length, 2); // each reading sent once
  });

  test('backoff delay doubles and is capped', () {
    final service = makeService();
    expect(
      [for (var i = 1; i <= 7; i++) service.backoffDelay(i).inSeconds],
      [2, 4, 8, 16, 32, 60, 60],
    );
  });

  test('retries happen after the backoff delay (fake time) and stop at max attempts', () {
    fakeAsync((time) {
      // Drift futures need microtasks flushed, so each step is flush + elapse.
      void settle([Duration d = Duration.zero]) {
        time.elapse(d);
        time.flushMicrotasks();
      }

      late Reading r;
      addBp(DateTime.utc(2026, 1, 1)).then((v) => r = v);
      settle();

      api.onUpload = (_) async => throw httpError(500);
      final service = makeService(maxAttempts: 3);
      service.syncNow();
      settle();
      expect(api.calls.length, 1); // attempt 1 happened immediately

      settle(const Duration(milliseconds: 1999));
      expect(api.calls.length, 1); // 2s backoff not over yet
      settle(const Duration(milliseconds: 1));
      expect(api.calls.length, 2); // attempt 2 at 2s

      settle(const Duration(seconds: 3));
      expect(api.calls.length, 2); // next backoff is 4s
      settle(const Duration(seconds: 1));
      expect(api.calls.length, 3); // attempt 3 at +4s -> max reached

      settle(const Duration(minutes: 10));
      expect(api.calls.length, 3); // no more retries

      Reading? row;
      repo.getById(r.id).then((v) => row = v);
      settle();
      expect(row!.syncStatus, SyncStatus.failed);
      expect(row!.attempts, 3);
    });
  });

  test('a failed row is not picked up again after max attempts', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    api.onUpload = (_) async => throw httpError(500);
    final service = makeService(maxAttempts: 1);
    await service.syncNow();
    api.calls.clear();
    await service.syncNow();

    expect(api.calls, isEmpty);
    expect((await repo.getById(r.id))!.syncStatus, SyncStatus.failed);
  });

  group('DioReadingsApi', () {
    Future<void> uploadWithStatus(int status) async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _StatusAdapter(status);
      final r = await addBp(DateTime.utc(2026, 1, 1));
      await DioReadingsApi(dio).upload(r);
    }

    test('201 and 200 (duplicate) both count as success', () async {
      await uploadWithStatus(201);
      await uploadWithStatus(200);
    });

    test('500 throws', () async {
      expect(uploadWithStatus(500), throwsA(isA<DioException>()));
    });
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
