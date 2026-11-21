import 'dart:async';

import 'package:dio/dio.dart';

import '../data/readings_repository.dart';
import 'readings_api.dart';

/// Outbox sync: the database is the queue. A row only becomes `synced` after
/// the server confirmed it, so a crash at any point leaves it `pending`.
class SyncService {
  SyncService({
    required this.repo,
    required this.api,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 1),
    this.onSynced,
  });

  final ReadingsRepository repo;
  final ReadingsApi api;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final void Function(DateTime time)? onSynced;

  bool _running = false;
  Timer? _retryTimer;

  /// Failures in a row caused by the network (not counted as attempts), only
  /// used to grow the wait between retries.
  int _networkFailures = 0;

  /// 2s, 4s, 8s ... capped at [maxDelay]. [failures] is the number of failures so far.
  Duration backoffDelay(int failures) {
    // Clamp the exponent: a huge shift would overflow to 0 and retry with no wait.
    final ms = baseDelay.inMilliseconds * (1 << (failures - 1).clamp(0, 20));
    return Duration(milliseconds: ms > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : ms);
  }

  /// Safe to call from anywhere, any number of times (app start, new reading,
  /// connectivity back). A new trigger also starts the backoff over, since
  /// something may just have changed.
  Future<void> syncNow() {
    _networkFailures = 0;
    return _run();
  }

  /// If a loop is already running the call is ignored: that loop re-reads the
  /// queue each round, so it will see new rows anyway.
  Future<void> _run() async {
    if (_running) return;
    _running = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      await _drainQueue();
    } finally {
      _running = false;
    }
  }

  void dispose() => _retryTimer?.cancel();

  Future<void> _drainQueue() async {
    while (true) {
      final queue = await repo.getUploadQueue(maxAttempts: maxAttempts);
      if (queue.isEmpty) return;
      final reading = queue.first; // oldest first, one at a time

      try {
        await api.upload(reading);
      } catch (e) {
        if (isNetworkError(e)) {
          // Offline, timeout or unreachable server is not the reading's fault:
          // keep it pending, don't use up an attempt, and keep trying as long as it takes.
          await repo.recordNetworkError(reading.id, _describe(e));
          _networkFailures++;
          _retryTimer = Timer(backoffDelay(_networkFailures), _run);
          return;
        }

        // The server answered and refused (or something else broke): this counts.
        await repo.recordFailure(reading.id, _describe(e), maxAttempts: maxAttempts);
        final attempts = reading.attempts + 1;
        if (attempts >= maxAttempts) continue; // now `failed`, move on to the next row
        // Stop the loop, so newer rows are not sent before this older one.
        _retryTimer = Timer(backoffDelay(attempts), _run);
        return;
      }

      _networkFailures = 0;
      await repo.markSynced(reading.id);
      onSynced?.call(DateTime.now());
    }
  }

  /// True when the request never got a reply from the server.
  static bool isNetworkError(Object e) {
    return e is DioException &&
        (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError);
  }

  String _describe(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      return status != null ? 'HTTP $status' : e.type.name;
    }
    return e.toString();
  }
}
