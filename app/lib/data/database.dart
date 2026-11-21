import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum SyncStatus { pending, synced, failed }

class Readings extends Table {
  TextColumn get id => text()(); // uuid created on the device
  TextColumn get type => text()(); // 'bp' | 'temperature'
  IntColumn get systolic => integer().nullable()();
  IntColumn get diastolic => integer().nullable()();
  IntColumn get pulse => integer().nullable()();
  RealColumn get temperatureF => real().nullable()();
  DateTimeColumn get measuredAt => dateTime()(); // stored as UTC
  TextColumn get syncStatus => textEnum<SyncStatus>().withDefault(Constant(SyncStatus.pending.name))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Readings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database, used by tests.
  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

AppDatabase openFileDatabase() {
  return AppDatabase(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(File(p.join(dir.path, 'vitals.sqlite')));
  }));
}
