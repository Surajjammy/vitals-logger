import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'data/readings_repository.dart';
import 'device/fake_bp_cuff.dart';
import 'sync/readings_api.dart';
import 'sync/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = openFileDatabase();
  ref.onDispose(db.close);
  return db;
});

final readingsRepositoryProvider = Provider<ReadingsRepository>(
  (ref) => ReadingsRepository(ref.watch(databaseProvider)),
);

// The UI reads these streams (local DB), never the network.
final readingsProvider = StreamProvider<List<Reading>>(
  (ref) => ref.watch(readingsRepositoryProvider).watchAll(),
);

final unsyncedCountProvider = StreamProvider<int>(
  (ref) => ref.watch(readingsRepositoryProvider).watchUnsyncedCount(),
);

/// Chart date range, last 30 days by default.
class ChartRangeNotifier extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() {
    final today = DateTime.now();
    return DateTimeRange(
      start: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 29)),
      end: DateTime(today.year, today.month, today.day, 23, 59, 59),
    );
  }

  void set(DateTimeRange range) => state = range;
}

final chartRangeProvider = NotifierProvider<ChartRangeNotifier, DateTimeRange>(
  ChartRangeNotifier.new,
);

final chartReadingsProvider = StreamProvider<List<Reading>>((ref) {
  final range = ref.watch(chartRangeProvider);
  return ref
      .watch(readingsRepositoryProvider)
      .watchRange(range.start, range.end);
});

final bpCuffProvider = Provider<BpCuff>((ref) {
  final cuff = FakeBpCuff();
  ref.onDispose(cuff.dispose);
  return cuff;
});

// ---- Sync ----

// Android (phone or emulator) reaches the laptop's server through a USB/adb tunnel:
//   adb reverse tcp:3000 tcp:3000
// Override with: flutter run --dart-define=SERVER_URL=http://<address>:3000
const _configuredUrl = String.fromEnvironment('SERVER_URL');
String get _serverUrl =>
    _configuredUrl.isNotEmpty ? _configuredUrl : 'http://127.0.0.1:3000';

final readingsApiProvider = Provider<ReadingsApi>(
  (ref) => DioReadingsApi(createDio(_serverUrl)),
);

/// Last successful upload in this app session (not persisted).
class LastSyncNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void set(DateTime time) => state = time;
}

final lastSyncProvider = NotifierProvider<LastSyncNotifier, DateTime?>(
  LastSyncNotifier.new,
);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    repo: ref.watch(readingsRepositoryProvider),
    api: ref.watch(readingsApiProvider),
    onSynced: (time) => ref.read(lastSyncProvider.notifier).set(time),
  );

  // Trigger: connectivity came back.
  final sub = Connectivity().onConnectivityChanged.listen((results) {
    if (results.any((r) => r != ConnectivityResult.none)) service.syncNow();
  });
  ref.onDispose(() {
    sub.cancel();
    service.dispose();
  });

  // Trigger: app start (the provider is first read when the home screen builds).
  service.syncNow();
  return service;
});
