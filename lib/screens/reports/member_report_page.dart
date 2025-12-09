import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/member_service.dart';
import '../../services/report_service.dart';
import '../../widgets/attendance_chart.dart';
import '../../utils/export_utils.dart';

/// Member report page with charts and export
class MemberReportPage extends StatefulWidget {
  final String memberId;

  const MemberReportPage({super.key, required this.memberId});

  @override
  State<MemberReportPage> createState() => _MemberReportPageState();
}

class _MemberReportPageState extends State<MemberReportPage> {
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _report;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final member = await MemberService.getMemberById(widget.memberId);
      final report = await ReportService.getMemberReport(
        memberId: widget.memberId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      setState(() {
        _member = member;
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading report: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (dates != null) {
      setState(() {
        _fromDate = dates.start;
        _toDate = dates.end;
      });
      _loadReport();
    }
  }

  Future<void> _exportToCSV() async {
    if (_report == null) return;

    try {
      await ExportUtils.exportMemberReportToCSV(_report!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final attendance = _report?['attendance'] as Map<String, dynamic>?;
    final giving = _report?['giving'] as Map<String, dynamic>?;
    final attendanceRecords = attendance?['records'] as List? ?? [];
    final givingRecords = giving?['records'] as List? ?? [];

    // Prepare chart data
    final attendanceData = <String, int>{};
    for (final record in attendanceRecords) {
      if (record['created_at'] != null) {
        final date = DateTime.parse(
          record['created_at'],
        ).toString().split(' ')[0];
        attendanceData[date] = (attendanceData[date] ?? 0) + 1;
      }
    }

    // Count attendance status
    int present = 0, absent = 0, late = 0;
    for (final record in attendanceRecords) {
      final status = record['status']?.toString().toLowerCase() ?? '';
      if (status == 'present') present++;
      if (status == 'absent') absent++;
      if (status == 'late') late++;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_member?['first_name']} ${_member?['last_name']} - Report',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Attendance',
                    value: '${attendance?['total'] ?? 0}',
                    icon: Icons.event,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: _StatCard(
                    title: 'Total Giving',
                    value:
                        '\$${giving?['total']?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.attach_money,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            // Charts
            AttendanceChart(
              attendanceData: attendanceData,
              title: 'Attendance Trend',
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            AttendancePieChart(present: present, absent: absent, late: late),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppDimensions.spacingSM),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
