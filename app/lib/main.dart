import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'data/database.dart';
import 'add_reading_screen.dart';
import 'charts/charts_screen.dart';
import 'debug_db_screen.dart';
import 'providers.dart';

void main() {
  runApp(const ProviderScope(child: VitalsApp()));
}

class VitalsApp extends StatelessWidget {
  const VitalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitals Logger',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(readingsProvider);
    final unsynced = ref.watch(unsyncedCountProvider).value ?? 0;
    final lastSync = ref.watch(lastSyncProvider);
    ref.watch(
      syncServiceProvider,
    ); // creating the service also starts the first sync

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals Logger'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.storage),
              tooltip: 'Database (debug)',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugDbScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'Charts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChartsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Not synced yet: $unsynced · Last sync: '
              '${lastSync == null ? 'never' : TimeOfDay.fromDateTime(lastSync).format(context)}',
            ),
          ),
          Expanded(
            child: readings.when(
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('No readings yet'))
                  : ListView(children: [for (final r in rows) ReadingTile(r)]),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddReadingScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ReadingTile extends StatelessWidget {
  const ReadingTile(this.reading, {super.key});
  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final title = r.type == 'bp'
        ? '${r.systolic}/${r.diastolic} mmHg, pulse ${r.pulse}'
        : '${r.temperatureF} °F';
    return ListTile(
      title: Text(title),
      subtitle: Text(r.measuredAt.toLocal().toString()),
      trailing: Text(r.syncStatus.name),
    );
  }
}
