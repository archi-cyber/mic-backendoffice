import 'package:intl/intl.dart';

/// Prepared data for a dual-line church attendance chart.
class ChurchAttendanceChartSeries {
  const ChurchAttendanceChartSeries({
    required this.labels,
    required this.serviceCounts,
    required this.weeklyTotalCounts,
  });

  final List<String> labels;
  final List<int> serviceCounts;
  final List<int> weeklyTotalCounts;

  bool get isEmpty => labels.isEmpty;
}

/// Builds chart series from [ChurchAttendanceService.getAllServices] rows.
class ChurchAttendanceChartData {
  static const int defaultMaxPoints = 12;

  /// When [serviceName] is set, only that named service is plotted.
  /// Otherwise attendance is aggregated by calendar date (all services that day).
  static ChurchAttendanceChartSeries build({
    required List<Map<String, dynamic>> services,
    String? serviceName,
    int maxPoints = defaultMaxPoints,
  }) {
    final List<_ServicePoint> serviceRows;
    if (serviceName != null && serviceName.trim().isNotEmpty) {
      final nameLower = serviceName.trim().toLowerCase();
      serviceRows = services
          .where(
            (row) =>
                (row['name']?.toString().trim().toLowerCase() ?? '') ==
                nameLower,
          )
          .map(_normalizeRow)
          .whereType<_ServicePoint>()
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } else {
      serviceRows = _aggregateByDate(services);
    }

    if (serviceRows.isEmpty) {
      return const ChurchAttendanceChartSeries(
        labels: [],
        serviceCounts: [],
        weeklyTotalCounts: [],
      );
    }

    final trimmed = serviceRows.length > maxPoints
        ? serviceRows.sublist(serviceRows.length - maxPoints)
        : serviceRows;

    final labels = <String>[];
    final serviceCounts = <int>[];
    final weeklyTotals = <int>[];

    for (final point in trimmed) {
      labels.add(DateFormat('d/M').format(point.date));
      serviceCounts.add(point.count);
      weeklyTotals.add(_weeklyAttendanceTotal(services, point.date));
    }

    return ChurchAttendanceChartSeries(
      labels: labels,
      serviceCounts: serviceCounts,
      weeklyTotalCounts: weeklyTotals,
    );
  }

  static List<_ServicePoint> _aggregateByDate(
    List<Map<String, dynamic>> services,
  ) {
    final byDate = <DateTime, int>{};
    for (final row in services) {
      final point = _normalizeRow(row);
      if (point == null) continue;
      byDate[point.date] = (byDate[point.date] ?? 0) + point.count;
    }
    final points = byDate.entries
        .map((e) => _ServicePoint(date: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  static _ServicePoint? _normalizeRow(Map<String, dynamic> row) {
    final dateRaw = row['service_date']?.toString();
    if (dateRaw == null || dateRaw.isEmpty) return null;
    try {
      final date = DateTime.parse(dateRaw.split('T').first);
      return _ServicePoint(
        date: DateTime(date.year, date.month, date.day),
        count: row['attendance_count'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sunday-start week: sum present counts for all services in that week.
  static int _weeklyAttendanceTotal(
    List<Map<String, dynamic>> services,
    DateTime serviceDate,
  ) {
    final weekStart = _weekStartSunday(serviceDate);
    final weekEnd = weekStart.add(const Duration(days: 6));
    var total = 0;

    for (final row in services) {
      final point = _normalizeRow(row);
      if (point == null) continue;
      if (point.date.isBefore(weekStart) || point.date.isAfter(weekEnd)) {
        continue;
      }
      total += point.count;
    }

    return total;
  }

  static DateTime _weekStartSunday(DateTime date) {
    final daysFromSunday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - daysFromSunday);
  }
}

class _ServicePoint {
  const _ServicePoint({required this.date, required this.count});

  final DateTime date;
  final int count;
}
