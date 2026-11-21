import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// The only class that talks to Drift. UI and sync code go through this.
class ReadingsRepository {
  ReadingsRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Saves a reading locally as `pending`. The id is created here, on the
  /// device, so the server can recognise retries of the same reading.
  Future<Reading> addReading({
    required String type,
    int? systolic,
    int? diastolic,
    int? pulse,
    double? temperatureF,
    required DateTime measuredAt,
  }) async {
    final row = ReadingsCompanion.insert(
      id: _uuid.v4(),
      type: type,
      systolic: Value(systolic),
      diastolic: Value(diastolic),
      pulse: Value(pulse),
      temperatureF: Value(temperatureF),
      measuredAt: measuredAt.toUtc(),
      createdAt: DateTime.now().toUtc(),
    );
    return _db.into(_db.readings).insertReturning(row);
  }

  /// Newest first. Drift re-emits whenever the table changes.
  Stream<List<Reading>> watchAll() {
    final query = _db.select(_db.readings)
      ..orderBy([(r) => OrderingTerm.desc(r.measuredAt)]);
    return query.watch();
  }

  /// Readings measured in [from, to], oldest first. Used by the charts.
  Stream<List<Reading>> watchRange(DateTime from, DateTime to) {
    final query = _db.select(_db.readings)
      ..where((r) => r.measuredAt.isBetweenValues(from.toUtc(), to.toUtc()))
      ..orderBy([(r) => OrderingTerm.asc(r.measuredAt)]);
    return query.watch();
  }

  /// Everything that is not `synced` (pending and failed) counts as "not synced yet".
  Stream<int> watchUnsyncedCount() {
    final count = _db.readings.id.count();
    final query = _db.selectOnly(_db.readings)
      ..addColumns([count])
      ..where(_db.readings.syncStatus.equals(SyncStatus.synced.name).not());
    return query.map((row) => row.read(count)!).watchSingle();
  }

  Future<Reading?> getById(String id) {
    return (_db.select(
      _db.readings,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Rows that still need uploading, oldest first.
  Future<List<Reading>> getUploadQueue({required int maxAttempts}) {
    final query = _db.select(_db.readings)
      ..where(
        (r) =>
            r.syncStatus.equals(SyncStatus.synced.name).not() &
            r.attempts.isSmallerThanValue(maxAttempts),
      )
      ..orderBy([(r) => OrderingTerm.asc(r.measuredAt)]);
    return query.get();
  }

  Future<void> markSynced(String id) {
    return (_db.update(_db.readings)..where((r) => r.id.equals(id))).write(
      ReadingsCompanion(
        syncStatus: Value(SyncStatus.synced),
        lastError: const Value(null),
      ),
    );
  }

  /// Network trouble: remember why, but keep the row `pending` and do not
  /// count an attempt, so an outage of any length never turns it into `failed`.
  Future<void> recordNetworkError(String id, String error) {
    return (_db.update(_db.readings)..where((r) => r.id.equals(id))).write(
      ReadingsCompanion(lastError: Value(error)),
    );
  }

  /// Counts the attempt and keeps the error. Once [maxAttempts] is reached
  /// the row is marked `failed` and the queue stops picking it up.
  Future<void> recordFailure(
    String id,
    String error, {
    required int maxAttempts,
  }) async {
    final row = await getById(id);
    if (row == null) return;
    final attempts = row.attempts + 1;
    await (_db.update(_db.readings)..where((r) => r.id.equals(id))).write(
      ReadingsCompanion(
        attempts: Value(attempts),
        lastError: Value(error),
        syncStatus: Value(
          attempts >= maxAttempts ? SyncStatus.failed : SyncStatus.pending,
        ),
      ),
    );
  }
}
