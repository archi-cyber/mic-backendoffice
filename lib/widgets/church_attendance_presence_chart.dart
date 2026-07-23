import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/mic_theme.dart';
import '../utils/church_attendance_chart_data.dart';

/// Dual-line chart: per-service attendance vs weekly total church attendance.
class ChurchAttendancePresenceChart extends StatelessWidget {
  const ChurchAttendancePresenceChart({
    super.key,
    required this.title,
    required this.serviceLineLabel,
    required this.totalLineLabel,
    required this.services,
    this.serviceName,
    this.isLoading = false,
    this.maxPoints = ChurchAttendanceChartData.defaultMaxPoints,
  });

  final String title;
  final String serviceLineLabel;
  final String totalLineLabel;
  final List<Map<String, dynamic>> services;
  /// Optional exact service name filter; null aggregates all services by date.
  final String? serviceName;
  final bool isLoading;
  final int maxPoints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = ChurchAttendanceChartData.build(
      services: services,
      serviceName: serviceName,
      maxPoints: maxPoints,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSM),
            if (isLoading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (series.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    context.tr('attendanceReportChartNoData'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: _maxY(series),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.35),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble()) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: context.mic.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= series.labels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                series.labels[index],
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.toInt();
                            if (index < 0 || index >= series.labels.length) {
                              return null;
                            }
                            final label = spot.barIndex == 0
                                ? serviceLineLabel
                                : totalLineLabel;
                            return LineTooltipItem(
                              '$label\n${series.labels[index]}: ${spot.y.toInt()}',
                              theme.textTheme.labelSmall!.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      _line(
                        color: AppColors.primary,
                        values: series.serviceCounts,
                      ),
                      _line(
                        color: AppColors.secondary,
                        values: series.weeklyTotalCounts,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              Wrap(
                spacing: AppDimensions.spacingMD,
                runSpacing: AppDimensions.spacingXS,
                children: [
                  _LegendDot(
                    color: AppColors.primary,
                    label: serviceLineLabel,
                  ),
                  _LegendDot(
                    color: AppColors.secondary,
                    label: totalLineLabel,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _maxY(ChurchAttendanceChartSeries series) {
    final peak = [
      ...series.serviceCounts,
      ...series.weeklyTotalCounts,
    ].fold<int>(0, (max, value) => value > max ? value : max);
    return peak <= 0 ? 10 : peak * 1.15;
  }

  static LineChartBarData _line({
    required Color color,
    required List<int> values,
  }) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), values[i].toDouble()),
      ],
      isCurved: true,
      curveSmoothness: 0.22,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
