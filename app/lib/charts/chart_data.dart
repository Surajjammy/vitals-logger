import '../data/database.dart';

/// Ranges longer than this are averaged per week instead of per day,
/// so the chart never has more than ~60 points however long the range is.
const maxDailyRangeDays = 60;

/// Days since 1970-01-01 for the reading's local calendar date.
/// Built from a UTC date so daylight-saving shifts cannot change the count.
int dayNumber(DateTime time) {
  final local = time.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).difference(DateTime.utc(1970)).inDays;
}

DateTime dateOfDayNumber(int day) =>
    DateTime.utc(1970).add(Duration(days: day));

/// First day (Monday) of the week containing [day]. 1970-01-01 was a Thursday.
int weekStart(int day) => day - ((day + 3) % 7);

bool useWeeklyBuckets(DateTime from, DateTime to) =>
    to.difference(from).inDays > maxDailyRangeDays;

/// One point on a chart: the average of all readings in one day or week.
class ChartPoint {
  const ChartPoint({
    required this.day,
    required this.values,
    required this.hasUnsynced,
  });

  /// Bucket start as a day number; used as the chart's x value.
  final int day;

  /// One average per series, in the order of the series asked for.
  final List<double> values;

  /// True if any reading in this bucket has not reached the server yet.
  final bool hasUnsynced;
}

/// Averages readings of [type] per bucket. [pick] extracts the numbers to
/// average from a reading, e.g. (systolic, diastolic, pulse).
List<ChartPoint> aggregate(
  List<Reading> readings, {
  required String type,
  required bool weekly,
  required List<double> Function(Reading r) pick,
}) {
  final buckets = <int, List<Reading>>{};
  for (final r in readings.where((r) => r.type == type)) {
    final day = dayNumber(r.measuredAt);
    buckets.putIfAbsent(weekly ? weekStart(day) : day, () => []).add(r);
  }

  final days = buckets.keys.toList()..sort();
  return [
    for (final day in days)
      () {
        final rows = buckets[day]!;
        final picked = rows.map(pick).toList();
        return ChartPoint(
          day: day,
          values: [
            for (var i = 0; i < picked.first.length; i++)
              picked.map((p) => p[i]).reduce((a, b) => a + b) / picked.length,
          ],
          hasUnsynced: rows.any((r) => r.syncStatus != SyncStatus.synced),
        );
      }(),
  ];
}

List<ChartPoint> bpPoints(List<Reading> readings, {required bool weekly}) =>
    aggregate(
      readings,
      type: 'bp',
      weekly: weekly,
      pick: (r) => [
        r.systolic!.toDouble(),
        r.diastolic!.toDouble(),
        r.pulse!.toDouble(),
      ],
    );

List<ChartPoint> temperaturePoints(
  List<Reading> readings, {
  required bool weekly,
}) => aggregate(
  readings,
  type: 'temperature',
  weekly: weekly,
  pick: (r) => [r.temperatureF!],
);
