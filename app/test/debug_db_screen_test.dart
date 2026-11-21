import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals_logger/data/database.dart';
import 'package:vitals_logger/data/readings_repository.dart';
import 'package:vitals_logger/debug_db_screen.dart';
import 'package:vitals_logger/providers.dart';

void main() {
  testWidgets('shows counts per status and the error of a failed row', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final repo = ReadingsRepository(db);
    await tester.runAsync(() async {
      final a = await repo.addReading(
        type: 'bp',
        systolic: 120,
        diastolic: 80,
        pulse: 70,
        measuredAt: DateTime.utc(2026, 1, 1),
      );
      await repo.addReading(
        type: 'temperature',
        temperatureF: 98.6,
        measuredAt: DateTime.utc(2026, 1, 2),
      );
      final c = await repo.addReading(
        type: 'bp',
        systolic: 130,
        diastolic: 85,
        pulse: 72,
        measuredAt: DateTime.utc(2026, 1, 3),
      );
      await repo.markSynced(a.id);
      await repo.recordFailure(c.id, 'connectionTimeout', maxAttempts: 1);
    });

    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [readingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: DebugDbScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.textContaining('3 rows'), findsOneWidget);
    expect(
      find.textContaining('pending 1 · synced 1 · failed 1'),
      findsOneWidget,
    );
    expect(find.textContaining('connectionTimeout'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(
      const Duration(milliseconds: 10),
    ); // fires the timer Drift created on unmount
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });
}
