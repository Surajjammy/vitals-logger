import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'providers.dart';

/// Debug-only view of the raw `readings` table, so the database can be checked
/// on the phone itself. Read-only: it never changes data.
class DebugDbScreen extends ConsumerWidget {
  const DebugDbScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(readingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Database (debug)')),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          int count(SyncStatus s) =>
              list.where((r) => r.syncStatus == s).length;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'Table: readings · ${list.length} rows\n'
                'pending ${count(SyncStatus.pending)} · '
                'synced ${count(SyncStatus.synced)} · '
                'failed ${count(SyncStatus.failed)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final r in list) _RowCard(r),
            ],
          );
        },
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard(this.r);
  final Reading r;

  @override
  Widget build(BuildContext context) {
    final values = r.type == 'bp'
        ? '${r.systolic}/${r.diastolic} mmHg, pulse ${r.pulse}'
        : '${r.temperatureF} °F';
    final color = switch (r.syncStatus) {
      SyncStatus.synced => Colors.green,
      SyncStatus.pending => Colors.orange,
      SyncStatus.failed => Theme.of(context).colorScheme.error,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.type}: $values',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  r.syncStatus.name.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Text, not just colour, carries the status, so it stays readable for everyone.
            Text('attempts: ${r.attempts}   last error: ${r.lastError ?? '-'}'),
            Text('measured: ${r.measuredAt.toUtc().toIso8601String()}'),
            Text('created:  ${r.createdAt.toUtc().toIso8601String()}'),
            SelectableText(
              'id: ${r.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
