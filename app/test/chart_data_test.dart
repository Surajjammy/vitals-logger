import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vitals_logger/charts/chart_data.dart';
import 'package:vitals_logger/charts/charts_screen.dart';
import 'package:vitals_logger/data/database.dart';
import 'package:vitals_logger/data/readings_repository.dart';
import 'package:vitals_logger/providers.dart';

Reading bp(
  DateTime at,
  int sys,
  int dia,
  int pulse, {
  SyncStatus status = SyncStatus.synced,
}) => Reading(
  id: '${at.microsecondsSinceEpoch}-$sys',
  type: 'bp',
  systolic: sys,
  diastolic: dia,
  pulse: pulse,
  temperatureF: null,
  measuredAt: at,
  syncStatus: status,
  attempts: 0,
  lastError: null,
  createdAt: at,
);

Reading temp(DateTime at, double f) => Reading(
  id: 't${at.microsecondsSinceEpoch}',
  type: 'temperature',
  systolic: null,
  diastolic: null,
  pulse: null,
  temperatureF: f,
  measuredAt: at,
  syncStatus: SyncStatus.synced,
  attempts: 0,
  lastError: null,
  createdAt: at,
);

void main() {
  // Local noon, so the local calendar date is the same in any time zone.
  DateTime noon(int y, int m, int d, [int h = 12]) => DateTime(y, m, d, h);

  group('aggregate', () {
    test('averages several readings of the same day', () {
      final points = bpPoints([
        bp(noon(2026, 3, 2, 8), 120, 80, 70),
        bp(noon(2026, 3, 2, 20), 130, 90, 80),
      ], weekly: false);

      expect(points.length, 1);
      expect(points.single.values, [125, 85, 75]);
    });

    test('different days stay separate and are sorted by day', () {
      final points = bpPoints([
        bp(noon(2026, 3, 3), 130, 85, 72),
        bp(noon(2026, 3, 2), 120, 80, 70),
      ], weekly: false);

      expect(points.map((p) => p.values.first), [120, 130]);
      expect(points[1].day - points[0].day, 1);
    });

    test(
      'weekly buckets: Mon-Sun go together, next Monday starts a new bucket',
      () {
        // 2026-03-02 is a Monday.
        final points = bpPoints([
          bp(noon(2026, 3, 2), 100, 60, 60), // Mon
          bp(noon(2026, 3, 8), 120, 80, 80), // Sun, same week
          bp(noon(2026, 3, 9), 140, 100, 100), // next Mon
        ], weekly: true);

        expect(points.length, 2);
        expect(points[0].values, [110, 70, 70]);
        expect(points[1].values, [140, 100, 100]);
        expect(points[1].day - points[0].day, 7);
        expect(dateOfDayNumber(points[0].day).weekday, DateTime.monday);
      },
    );

    test(
      'a bucket is marked unsynced if any reading in it is pending or failed',
      () {
        final points = bpPoints([
          bp(noon(2026, 3, 2, 8), 120, 80, 70),
          bp(noon(2026, 3, 2, 9), 120, 80, 70, status: SyncStatus.pending),
          bp(noon(2026, 3, 3), 120, 80, 70),
          bp(noon(2026, 3, 4), 120, 80, 70, status: SyncStatus.failed),
        ], weekly: false);

        expect(points.map((p) => p.hasUnsynced), [true, false, true]);
      },
    );

    test('bp and temperature readings do not mix', () {
      final rows = [
        bp(noon(2026, 3, 2), 120, 80, 70),
        temp(noon(2026, 3, 2), 98.6),
      ];
      expect(bpPoints(rows, weekly: false).single.values.length, 3);
      expect(temperaturePoints(rows, weekly: false).single.values, [98.6]);
    });

    test('empty input gives no points', () {
      expect(bpPoints([], weekly: false), isEmpty);
    });

    test('a year of readings (4 per day) shrinks to 53 weekly points', () {
      final start = noon(2025, 1, 6); // a Monday
      final rows = [
        for (var d = 0; d < 365; d++)
          for (final h in [6, 10, 16, 21])
            bp(start.add(Duration(days: d)).copyWith(hour: h), 120, 80, 70),
      ];
      expect(rows.length, 1460);

      final points = bpPoints(rows, weekly: true);
      expect(
        points.length,
        53,
      ); // 365 days starting on a Monday touches 53 weeks
    });
  });

  test('weekly buckets are used only for ranges over 60 days', () {
    final from = DateTime(2026, 1, 1);
    expect(useWeeklyBuckets(from, from.add(const Duration(days: 60))), isFalse);
    expect(useWeeklyBuckets(from, from.add(const Duration(days: 61))), isTrue);
  });

  group('repository.watchRange', () {
    test('returns only readings inside the range, oldest first', () async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      final repo = ReadingsRepository(db);
      for (final d in [5, 1, 20]) {
        await repo.addReading(
          type: 'bp',
          systolic: 120,
          diastolic: 80,
          pulse: 70,
          measuredAt: DateTime.utc(2026, 3, d, 12),
        );
      }

      final rows = await repo
          .watchRange(DateTime.utc(2026, 3, 2), DateTime.utc(2026, 3, 10))
          .first;
      expect(rows.map((r) => r.measuredAt.toUtc().day), [5]);

      final all = await repo
          .watchRange(DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 31))
          .first;
      expect(all.map((r) => r.measuredAt.toUtc().day), [1, 5, 20]);
    });
  });

  group('ChartsScreen', () {
    // Drift closes its streams with a timer; unmount and let it run before the test ends.
    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(
        const Duration(milliseconds: 10),
      ); // fires the timer Drift created on unmount
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }

    Future<void> pump(WidgetTester tester, AppDatabase db) async {
      tester.view.physicalSize = const Size(800, 2000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readingsRepositoryProvider.overrideWithValue(
              ReadingsRepository(db),
            ),
          ],
          child: const MaterialApp(home: ChartsScreen()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    testWidgets('shows empty messages when there is no data', (tester) async {
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      await pump(tester, db);

      expect(find.text('No readings in this range'), findsNWidgets(2));
      expect(find.text('Daily averages'), findsOneWidget);
      await finish(tester);
    });

    testWidgets(
      'draws both charts when readings exist, and switches to weekly for 1y',
      (tester) async {
        final db = AppDatabase.inMemory();
        addTearDown(db.close);
        final repo = ReadingsRepository(db);
        await tester.runAsync(() async {
          final now = DateTime.now();
          await repo.addReading(
            type: 'bp',
            systolic: 120,
            diastolic: 80,
            pulse: 70,
            measuredAt: now,
          );
          await repo.addReading(
            type: 'temperature',
            temperatureF: 98.6,
            measuredAt: now,
          );
        });
        await pump(tester, db);

        expect(find.text('No readings in this range'), findsNothing);
        expect(find.byType(VitalsLineChart), findsNWidgets(2));
        expect(
          find.text('Systolic (mmHg)'),
          findsOneWidget,
        ); // legend, only on the multi-series chart

        await tester.tap(find.text('1y'));
        await tester.pump();
        expect(find.text('Weekly averages'), findsOneWidget);
        await finish(tester);
      },
    );
  });
}
