import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../providers.dart';
import 'chart_data.dart';

class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(chartRangeProvider);
    final readings = ref.watch(chartReadingsProvider);
    final weekly = useWeeklyBuckets(range.start, range.end);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Validated categorical slots 1-3 (blue, orange, aqua), light and dark steps.
    final blue = dark ? const Color(0xFF3987E5) : const Color(0xFF2A78D6);
    final orange = dark ? const Color(0xFFD95926) : const Color(0xFFEB6834);
    final aqua = dark ? const Color(0xFF199E70) : const Color(0xFF1BAF7A);

    return Scaffold(
      appBar: AppBar(title: const Text('Charts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RangeFilter(
            range: range,
            onChanged: ref.read(chartRangeProvider.notifier).set,
          ),
          const SizedBox(height: 4),
          Text(
            weekly ? 'Weekly averages' : 'Daily averages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          readings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VitalsLineChart(
                  title: 'Blood pressure and pulse',
                  points: bpPoints(rows, weekly: weekly),
                  series: [
                    SeriesStyle('Systolic (mmHg)', blue),
                    SeriesStyle('Diastolic (mmHg)', orange),
                    SeriesStyle('Pulse (bpm)', aqua),
                  ],
                  startDay: dayNumber(range.start),
                  endDay: dayNumber(range.end),
                ),
                const SizedBox(height: 32),
                // Own chart and own y-axis: °F and mmHg must never share a scale.
                VitalsLineChart(
                  title: 'Temperature (°F)',
                  points: temperaturePoints(rows, weekly: weekly),
                  series: [SeriesStyle('Temperature (°F)', blue)],
                  startDay: dayNumber(range.start),
                  endDay: dayNumber(range.end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SeriesStyle {
  const SeriesStyle(this.label, this.color);
  final String label;
  final Color color;
}

class _RangeFilter extends StatelessWidget {
  const _RangeFilter({required this.range, required this.onChanged});

  final DateTimeRange range;
  final void Function(DateTimeRange) onChanged;

  DateTimeRange _lastDays(int days) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return DateTimeRange(
      start: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: days - 1)),
      end: end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y');
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, days) in [
          ('7d', 7),
          ('30d', 30),
          ('90d', 90),
          ('1y', 365),
        ])
          ActionChip(
            label: Text(label),
            onPressed: () => onChanged(_lastDays(days)),
          ),
        ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text('${fmt.format(range.start)} - ${fmt.format(range.end)}'),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: range,
            );
            if (picked != null) {
              onChanged(
                DateTimeRange(
                  start: picked.start,
                  end: DateTime(
                    picked.end.year,
                    picked.end.month,
                    picked.end.day,
                    23,
                    59,
                    59,
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class VitalsLineChart extends StatelessWidget {
  const VitalsLineChart({
    super.key,
    required this.title,
    required this.points,
    required this.series,
    required this.startDay,
    required this.endDay,
  });

  final String title;
  final List<ChartPoint> points;
  final List<SeriesStyle> series;
  final int startDay;
  final int endDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final labelStyle = theme.textTheme.bodySmall!;
    final dateFmt = DateFormat('d MMM');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (points.isEmpty)
          const SizedBox(
            height: 120,
            child: Center(child: Text('No readings in this range')),
          )
        else ...[
          if (series.length > 1)
            Wrap(
              spacing: 16,
              children: [
                for (final s in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 3, color: s.color),
                      const SizedBox(width: 6),
                      Text(s.label, style: labelStyle),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            '○ hollow point = includes readings not synced yet',
            style: labelStyle,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: startDay.toDouble(),
                maxX: endDay.toDouble(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(v.toStringAsFixed(0), style: labelStyle),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: ((endDay - startDay) / 4).clamp(
                        1,
                        double.infinity,
                      ),
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          dateFmt.format(dateOfDayNumber(v.round())),
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) => [
                      for (final t in touched)
                        LineTooltipItem(
                          '${series[t.barIndex].label}: ${t.y.toStringAsFixed(1)}\n'
                          '${dateFmt.format(dateOfDayNumber(t.x.round()))}'
                          '${points[t.spotIndex].hasUnsynced ? ' (not synced)' : ''}',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  for (var i = 0; i < series.length; i++)
                    LineChartBarData(
                      spots: [
                        for (final p in points)
                          FlSpot(p.day.toDouble(), p.values[i]),
                      ],
                      color: series[i].color,
                      barWidth: 2,
                      isCurved: false,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            points[index].hasUnsynced
                            // Hollow, larger ring: differs by shape, not only by colour.
                            ? FlDotCirclePainter(
                                radius: 5,
                                color: surface,
                                strokeColor: series[i].color,
                                strokeWidth: 2,
                              )
                            : FlDotCirclePainter(
                                radius: 3,
                                color: series[i].color,
                                strokeWidth: 0,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
