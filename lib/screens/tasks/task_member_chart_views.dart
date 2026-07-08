import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';
import 'task_member_analytics.dart';

class TaskMemberLatenessChartView extends StatefulWidget {
  const TaskMemberLatenessChartView({
    super.key,
    required this.metrics,
    this.departmentName,
    this.compact = false,
  });

  final List<TaskMemberMetric> metrics;
  final String? departmentName;
  final bool compact;

  @override
  State<TaskMemberLatenessChartView> createState() =>
      _TaskMemberLatenessChartViewState();
}

class _TaskMemberLatenessChartViewState extends State<TaskMemberLatenessChartView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(TaskMemberLatenessChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics != widget.metrics) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.metrics.isEmpty) {
      return _AnalyticsEmptyState(
        icon: Icons.schedule_outlined,
        message: context.tr('No lateness data for assigned tasks yet'),
      );
    }

    final top = widget.metrics.take(10).toList();
    final maxValue = top.fold<double>(
      0,
      (max, metric) => metric.value > max ? metric.value : max,
    );
    final avgAll = widget.metrics.fold<double>(0, (sum, m) => sum + m.value) /
        widget.metrics.length;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsHeroCard(
              icon: Icons.schedule_outlined,
              title: context.tr('Average lateness per member'),
              subtitle: widget.departmentName == null
                  ? context.tr(
                      'Average days late on scheduled tasks with assignees',
                    )
                  : context.tr(
                      'Department: {name}',
                      {'name': widget.departmentName!},
                    ),
              accent: AppColors.warning,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              children: [
                _MetricChip(
                  label: context.tr('Members tracked'),
                  value: '${widget.metrics.length}',
                  icon: Icons.people_outline,
                ),
                _MetricChip(
                  label: context.tr('Team average'),
                  value: '${avgAll.toStringAsFixed(1)}d',
                  icon: Icons.av_timer_outlined,
                  highlight: avgAll > 0,
                ),
                _MetricChip(
                  label: context.tr('Highest avg.'),
                  value: '${top.first.value.toStringAsFixed(1)}d',
                  icon: Icons.trending_up,
                  highlight: top.first.value > 0,
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            _ChartSurface(
              title: context.tr('Average days late'),
              child: SizedBox(
                height: widget.compact ? 260 : 320,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (maxValue <= 0 ? 1 : maxValue * 1.2) * _animation.value,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.25),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
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
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= top.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _shortName(top[index].name),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < top.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: top[i].value * _animation.value,
                              width: widget.compact ? 16 : 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  top[i].color.withValues(alpha: 0.55),
                                  top[i].color,
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            _ChartSurface(
              title: context.tr('Lateness trend by member'),
              child: SizedBox(
                height: widget.compact ? 220 : 260,
                child: LineChart(
                  duration: Duration.zero,
                  LineChartData(
                    minY: 0,
                    maxY: (maxValue <= 0 ? 1 : maxValue * 1.15) * _animation.value,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
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
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= top.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < top.length; i++)
                            FlSpot(i.toDouble(), top[i].value * _animation.value),
                        ],
                        isCurved: true,
                        curveSmoothness: 0.28,
                        color: AppColors.warning,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: top[index].color,
                              strokeWidth: 2,
                              strokeColor: theme.colorScheme.surface,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.warning.withValues(alpha: 0.22),
                              AppColors.warning.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            _LegendList(metrics: top),
          ],
        );
      },
    );
  }
}

class TaskMemberWorkloadChartView extends StatefulWidget {
  const TaskMemberWorkloadChartView({
    super.key,
    required this.metrics,
    this.departmentName,
    this.compact = false,
  });

  final List<TaskMemberMetric> metrics;
  final String? departmentName;
  final bool compact;

  @override
  State<TaskMemberWorkloadChartView> createState() =>
      _TaskMemberWorkloadChartViewState();
}

class _TaskMemberWorkloadChartViewState extends State<TaskMemberWorkloadChartView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(TaskMemberWorkloadChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics != widget.metrics) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.metrics.isEmpty) {
      return _AnalyticsEmptyState(
        icon: Icons.work_outline,
        message: context.tr('No active assignments to chart yet'),
      );
    }

    final top = widget.metrics.take(8).toList();
    final totalLoad = widget.metrics.fold<double>(0, (sum, m) => sum + m.value);
    final busiest = top.first;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AnalyticsHeroCard(
              icon: Icons.work_outline,
              title: context.tr('Member workload'),
              subtitle: widget.departmentName == null
                  ? context.tr(
                      'Open task load weighted by priority (urgent counts more)',
                    )
                  : context.tr(
                      'Department: {name}',
                      {'name': widget.departmentName!},
                    ),
              accent: AppColors.primary,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              children: [
                _MetricChip(
                  label: context.tr('Active members'),
                  value: '${widget.metrics.length}',
                  icon: Icons.people_outline,
                ),
                _MetricChip(
                  label: context.tr('Total load'),
                  value: totalLoad.toStringAsFixed(0),
                  icon: Icons.stacked_bar_chart,
                ),
                _MetricChip(
                  label: context.tr('Busiest'),
                  value: _shortName(busiest.name),
                  icon: Icons.bolt_outlined,
                  highlight: true,
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            if (!widget.compact)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ChartSurface(
                      title: context.tr('Workload share'),
                      child: SizedBox(
                        height: 280,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 52,
                                  startDegreeOffset: -90,
                                  sections: [
                                    for (final metric in top)
                                      PieChartSectionData(
                                        value:
                                            metric.value * _animation.value,
                                        color: metric.color,
                                        radius: 72,
                                        title:
                                            '${((metric.value / totalLoad) * 100).round()}%',
                                        titleStyle: theme
                                            .textTheme.labelSmall
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _LegendList(metrics: top, showTasks: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              _ChartSurface(
                title: context.tr('Workload share'),
                child: SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: [
                        for (final metric in top)
                          PieChartSectionData(
                            value: metric.value * _animation.value,
                            color: metric.color,
                            radius: 58,
                            title:
                                '${((metric.value / totalLoad) * 100).round()}%',
                            titleStyle: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(height: AppDimensions.spacingMD),
            _ChartSurface(
              title: context.tr('Open tasks by member'),
              child: SizedBox(
                height: widget.compact ? 260 : 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (busiest.value <= 0 ? 1 : busiest.value * 1.2) *
                        _animation.value,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.dividerColor.withValues(alpha: 0.25),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
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
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= top.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _shortName(top[index].name),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < top.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: top[i].value * _animation.value,
                              width: widget.compact ? 16 : 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  top[i].color.withValues(alpha: 0.5),
                                  top[i].color,
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  const _AnalyticsHeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartSurface extends StatelessWidget {
  const _ChartSurface({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? AppColors.warning : AppColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: AppDimensions.spacingSM),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.mic.textSecondary,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: highlight ? color : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendList extends StatelessWidget {
  const _LegendList({required this.metrics, this.showTasks = false});

  final List<TaskMemberMetric> metrics;
  final bool showTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metrics.map((metric) {
        return Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.spacingSM),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: metric.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: Text(
                  metric.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                showTasks
                    ? '${metric.taskCount} · ${metric.value.toStringAsFixed(0)}'
                    : '${metric.value.toStringAsFixed(1)}d',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.mic.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: context.mic.textSecondary),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts.first.length > 10
        ? '${parts.first.substring(0, 9)}…'
        : parts.first;
  }
  return '${parts.first} ${parts.last[0]}.';
}
