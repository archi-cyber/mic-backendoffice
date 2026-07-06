import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/class_service.dart';
import '../../services/report_service.dart';
import '../../utils/export_utils.dart';
import '../../widgets/attendance_chart.dart';

/// Detailed training report for a single class.
class ClassReportPage extends StatefulWidget {
  final String classId;
  final VoidCallback? onClose;

  const ClassReportPage({
    super.key,
    required this.classId,
    this.onClose,
  });

  @override
  State<ClassReportPage> createState() => _ClassReportPageState();
}

class _ClassReportPageState extends State<ClassReportPage> {
  Map<String, dynamic>? _class;
  Map<String, dynamic>? _report;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now();
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final classData = await ClassService.getClassById(widget.classId);
      final report = await ReportService.getClassReport(
        classId: widget.classId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() {
        _class = classData;
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error loading report: $e'))),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final isDesktop = widget.onClose != null;
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      helpText: context.tr('Select Date Range'),
      builder: isDesktop
          ? (context, child) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
                child: child,
              ),
            )
          : null,
    );
    if (dates == null) return;
    setState(() {
      _fromDate = dates.start;
      _toDate = dates.end;
    });
    _loadReport();
  }

  Future<void> _exportToCSV() async {
    if (_report == null || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await ExportUtils.exportClassReportToCSV(_report!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Report exported successfully')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Export failed: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sessions = _report?['sessions'] as Map<String, dynamic>?;
    final attendance = _report?['attendance'] as Map<String, dynamic>?;
    final attendanceRecords = List<Map<String, dynamic>>.from(
      attendance?['records'] as List? ?? [],
    );

    final attendanceData = <String, int>{};
    for (final record in attendanceRecords) {
      if (record['created_at'] != null) {
        final date = DateTime.parse(
          record['created_at'].toString(),
        ).toString().split(' ').first;
        attendanceData[date] = (attendanceData[date] ?? 0) + 1;
      }
    }

    var present = 0;
    var absent = 0;
    var late = 0;
    for (final record in attendanceRecords) {
      final status = record['status']?.toString().toLowerCase() ?? '';
      if (status == 'present') present++;
      if (status == 'absent') absent++;
      if (status == 'late') late++;
    }

    final trainingName = _class?['name']?.toString() ?? context.tr('Training');
    final dateRange =
        '${DateFormat('MMM d, yyyy').format(_fromDate)} – ${DateFormat('MMM d, yyyy').format(_toDate)}';

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
              )
            : null,
        title: Text(trainingName),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: _selectDateRange,
            tooltip: context.tr('Select Date Range'),
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            onPressed: _isExporting ? null : _exportToCSV,
            tooltip: context.tr('Export to CSV'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth >= 920 ? 1100.0 : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: AppDimensions.paddingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderBanner(trainingName, dateRange),
                    Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatsRow(
                            sessions: sessions?['total'] ?? 0,
                            attendance: attendance?['total'] ?? 0,
                            uniqueMembers: attendance?['unique_members'] ?? 0,
                            present: present,
                            absent: absent,
                            late: late,
                          ),
                          SizedBox(height: AppDimensions.spacingMD),
                          if (attendanceData.isNotEmpty) ...[
                            _ReportSurface(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: AttendanceChart(
                                attendanceData: attendanceData,
                                title: context.tr('Attendance Trend'),
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            _ReportSurface(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: AttendancePieChart(
                                present: present,
                                absent: absent,
                                late: late,
                              ),
                            ),
                          ] else
                            _ReportSurface(
                              padding: EdgeInsets.all(AppDimensions.paddingXL),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy_outlined,
                                    size: 48,
                                    color: context.mic.textSecondary,
                                  ),
                                  SizedBox(height: AppDimensions.spacingMD),
                                  Text(
                                    context.tr('No attendance data available'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: context.mic.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderBanner(String trainingName, String dateRange) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryDark.withValues(alpha: 0.18),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(
          color: AppColors.secondaryDark.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Training Report'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  trainingName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.mic.appBarForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  dateRange,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.secondaryDark.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              color: AppColors.secondaryDark,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int sessions,
    required int attendance,
    required int uniqueMembers,
    required int present,
    required int absent,
    required int late,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final cards = [
          _StatCard(
            label: context.tr('Sessions'),
            value: '$sessions',
            icon: Icons.event_outlined,
            color: AppColors.primary,
          ),
          _StatCard(
            label: context.tr('Total Attendance'),
            value: '$attendance',
            icon: Icons.how_to_reg_outlined,
            color: AppColors.accent,
          ),
          _StatCard(
            label: context.tr('Unique Members'),
            value: '$uniqueMembers',
            icon: Icons.people_outline,
            color: AppColors.success,
          ),
          _StatCard(
            label: context.tr('Present'),
            value: '$present',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          _StatCard(
            label: context.tr('Late'),
            value: '$late',
            icon: Icons.schedule_outlined,
            color: AppColors.warning,
          ),
          _StatCard(
            label: context.tr('Absent'),
            value: '$absent',
            icon: Icons.cancel_outlined,
            color: AppColors.error,
          ),
        ];

        if (isWide) {
          return Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: AppDimensions.spacingSM,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: (constraints.maxWidth - AppDimensions.spacingSM * 2) /
                        3,
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1)
                SizedBox(height: AppDimensions.spacingSM),
            ],
          ],
        );
      },
    );
  }
}

class _ReportSurface extends StatelessWidget {
  const _ReportSurface({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.mic.appBarForeground,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
