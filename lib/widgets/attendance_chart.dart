import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';

/// Attendance chart widget using fl_chart
class AttendanceChart extends StatelessWidget {
  final Map<String, int> attendanceData; // Date -> count
  final String title;

  const AttendanceChart({
    super.key,
    required this.attendanceData,
    this.title = 'Attendance Trend',
  });

  @override
  Widget build(BuildContext context) {
    if (attendanceData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Center(
            child: Text(
              'No attendance data available',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final sortedDates = attendanceData.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        attendanceData[entry.value]!.toDouble(),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimensions.spacingMD),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < sortedDates.length) {
                            final date = sortedDates[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                date.split('-').last, // Show day only
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pie chart for attendance status distribution
class AttendancePieChart extends StatelessWidget {
  final int present;
  final int absent;
  final int late;

  const AttendancePieChart({
    super.key,
    required this.present,
    required this.absent,
    required this.late,
  });

  @override
  Widget build(BuildContext context) {
    final total = present + absent + late;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Center(
            child: Text(
              'No attendance data',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Text(
              'Attendance Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: present.toDouble(),
                      title: 'Present\n$present',
                      color: AppColors.success,
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: absent.toDouble(),
                      title: 'Absent\n$absent',
                      color: AppColors.error,
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: late.toDouble(),
                      title: 'Late\n$late',
                      color: AppColors.warning,
                      radius: 80,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
