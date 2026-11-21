import 'package:flutter_test/flutter_test.dart';
import 'package:vitals_logger/data/database.dart';
import 'package:vitals_logger/data/readings_repository.dart';

void main() {
  late AppDatabase db;
  late ReadingsRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = ReadingsRepository(db);
  });
  tearDown(() => db.close());

  Future<Reading> addBp(DateTime at) => repo.addReading(
    type: 'bp',
    systolic: 120,
    diastolic: 80,
    pulse: 70,
    measuredAt: at,
  );

  test('new reading is saved as pending with a device-made id', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    expect(r.syncStatus, SyncStatus.pending);
    expect(r.attempts, 0);
    expect(r.id, isNotEmpty);
    expect((await repo.getById(r.id))!.systolic, 120);
  });

  test('watchAll emits again when a reading is added, newest first', () async {
    final emissions = <List<Reading>>[];
    final sub = repo.watchAll().listen(emissions.add);
    await addBp(DateTime.utc(2026, 1, 1));
    await addBp(DateTime.utc(2026, 1, 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.last.length, 2);
    expect(
      emissions.last.first.measuredAt.isAfter(emissions.last.last.measuredAt),
      isTrue,
    );
  });

  test('unsynced count drops after markSynced', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    await addBp(DateTime.utc(2026, 1, 2));
    expect(await repo.watchUnsyncedCount().first, 2);
    await repo.markSynced(r.id);
    expect(await repo.watchUnsyncedCount().first, 1);
  });

  test('upload queue is oldest first and skips synced rows', () async {
    final newer = await addBp(DateTime.utc(2026, 1, 2));
    final older = await addBp(DateTime.utc(2026, 1, 1));
    final done = await addBp(DateTime.utc(2025, 12, 1));
    await repo.markSynced(done.id);

    final queue = await repo.getUploadQueue(maxAttempts: 5);
    expect(queue.map((r) => r.id), [older.id, newer.id]);
  });

  test('recordNetworkError keeps the error but not an attempt, and the row stays pending', () async {
    final r = await addBp(DateTime.utc(2026, 1, 1));
    for (var i = 0; i < 10; i++) {
      await repo.recordNetworkError(r.id, 'connectionError');
    }
    final row = (await repo.getById(r.id))!;
    expect(
      (row.attempts, row.lastError, row.syncStatus),
      (0, 'connectionError', SyncStatus.pending),
    );
    expect(await repo.getUploadQueue(maxAttempts: 5), hasLength(1));
  });

  test(
    'recordFailure counts attempts, keeps the error, then marks failed',
    () async {
      final r = await addBp(DateTime.utc(2026, 1, 1));
      await repo.recordFailure(r.id, 'HTTP 500', maxAttempts: 2);
      var row = (await repo.getById(r.id))!;
      expect(
        (row.attempts, row.lastError, row.syncStatus),
        (1, 'HTTP 500', SyncStatus.pending),
      );

      await repo.recordFailure(r.id, 'HTTP 500', maxAttempts: 2);
      row = (await repo.getById(r.id))!;
      expect((row.attempts, row.syncStatus), (2, SyncStatus.failed));
      expect(await repo.getUploadQueue(maxAttempts: 2), isEmpty);
    },
  );
}
