import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitals_logger/add_reading_screen.dart';
import 'package:vitals_logger/data/database.dart';
import 'package:vitals_logger/data/readings_repository.dart';
import 'package:vitals_logger/device/fake_bp_cuff.dart';
import 'package:vitals_logger/providers.dart';
import 'package:vitals_logger/sync/readings_api.dart';
import 'package:vitals_logger/sync/sync_service.dart';

class _NoApi implements ReadingsApi {
  @override
  Future<void> upload(Reading reading) async => throw Exception('offline');
}

void main() {
  late AppDatabase db;
  late FakeBpCuff cuff;

  setUp(() {
    db = AppDatabase.inMemory();
    cuff = FakeBpCuff(interval: const Duration(milliseconds: 10));
  });
  tearDown(() async {
    cuff.dispose();
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingsRepositoryProvider.overrideWithValue(ReadingsRepository(db)),
          bpCuffProvider.overrideWithValue(cuff),
          // Sync is not under test here; a service whose uploads fail quietly is enough.
          syncServiceProvider.overrideWithValue(
            SyncService(
              repo: ReadingsRepository(db),
              api: _NoApi(),
              maxAttempts: 1,
            ),
          ),
        ],
        child: const MaterialApp(home: AddReadingScreen()),
      ),
    );
  }

  Future<List<Reading>> stored() => ReadingsRepository(db).watchAll().first;

  testWidgets('out-of-range: first save warns, second save stores it', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Systolic (mmHg)'),
      '300',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Diastolic (mmHg)'),
      '80',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Pulse (bpm)'), '70');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Check the reading again'), findsOneWidget);
    expect(await tester.runAsync(stored), isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pump();
    final rows = await tester.runAsync(stored);
    expect(rows!.length, 1);
    expect(rows.first.systolic, 300);
  });

  testWidgets('in-range value saves on the first press', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Temperature (°F)'),
      '98.6',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Check the reading again'), findsNothing);
    expect((await tester.runAsync(stored))!.length, 1);
  });

  testWidgets('editing a value after the warning asks for a fresh check', (
    tester,
  ) async {
    await pumpScreen(tester);
    final sys = find.widgetWithText(TextField, 'Systolic (mmHg)');
    await tester.enterText(sys, '300');
    await tester.enterText(
      find.widgetWithText(TextField, 'Diastolic (mmHg)'),
      '80',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Pulse (bpm)'), '70');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Check the reading again'), findsOneWidget);

    await tester.enterText(sys, '310'); // still out of range, but a new value
    await tester.pump();
    expect(find.textContaining('Check the reading again'), findsNothing);
  });

  testWidgets('Read from device fills the form from the final packet', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Read from device'));
    await tester.pump(); // starts the cuff timer
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // 5 short + 1 final packet

    expect(find.widgetWithText(TextField, '118'), findsOneWidget);
    expect(find.widgetWithText(TextField, '76'), findsOneWidget);
    expect(find.widgetWithText(TextField, '68'), findsOneWidget);
    expect(
      find.text('Read from device'),
      findsOneWidget,
    ); // button is enabled again
  });
}
