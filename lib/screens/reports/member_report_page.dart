import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/member_service.dart';
import '../../services/report_service.dart';
import '../../services/finance_service.dart';
import '../../widgets/attendance_chart.dart';
import '../../widgets/desktop/desktop_ui.dart';
import '../../utils/export_utils.dart';
import '../../core/localization/app_localizations.dart';

/// Member report page with charts and export
class MemberReportPage extends StatefulWidget {
  final String memberId;

  /// When set (e.g. desktop stack), back uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  MemberReportPage({super.key, required this.memberId, this.onClose});

  @override
  State<MemberReportPage> createState() => _MemberReportPageState();
}

class _MemberReportPageState extends State<MemberReportPage> {
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _report;
  DateTime _fromDate = DateTime.now().subtract(Duration(days: 90));
  DateTime _toDate = DateTime.now();
  bool _isLoading = true;
  bool _isFinanceLeader = false;

  @override
  void initState() {
    super.initState();
    _checkFinanceLeaderStatus();
    _loadReport();
  }

  Future<void> _checkFinanceLeaderStatus() async {
    try {
      final isFinanceLeader = await FinanceService.isFinanceLeader();
      if (mounted) {
        setState(() {
          _isFinanceLeader = isFinanceLeader;
        });
      }
    } catch (e) {
      // If error, default to false
      if (mounted) {
        setState(() {
          _isFinanceLeader = false;
        });
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading report: $e'))),
        );
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
          SnackBar(
            content: Text(context.tr('Report exported successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Export failed: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool _isDesktopLayout(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < kDesktopEmbeddedBreakpoint) {
      return false;
    }
    return widget.onClose != null;
  }

  Widget _buildReportContent({
    required Map<String, dynamic>? attendance,
    required Map<String, dynamic>? giving,
    required List attendanceRecords,
    required Map<String, int> attendanceData,
    required int present,
    required int absent,
    required int late,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: context.tr('Attendance'),
                value: '${attendance?['total'] ?? 0}',
                icon: Icons.event,
                color: AppColors.primary,
              ),
            ),
            if (_isFinanceLeader) ...[
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: _StatCard(
                  title: context.tr('Total Giving'),
                  value:
                      '\$${giving?['total']?.toStringAsFixed(2) ?? '0.00'}',
                  icon: Icons.attach_money,
                  color: AppColors.accent,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        AttendanceChart(
          attendanceData: attendanceData,
          title: context.tr('Attendance Trend'),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        AttendancePieChart(present: present, absent: absent, late: late),
        SizedBox(height: AppDimensions.spacingMD),
        _buildAttendanceDetailsSection(attendanceRecords),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktopLayout(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: isDesktop
            ? const DesktopPageShell(isLoading: true, child: SizedBox.shrink())
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final attendance = _report?['attendance'] as Map<String, dynamic>?;
    final giving = _report?['giving'] as Map<String, dynamic>?;
    final attendanceRecords = attendance?['records'] as List? ?? [];
    final memberName =
        '${_member?['first_name']} ${_member?['last_name']}'.trim();
    final dateRange =
        '${DateFormat('MMM d, yyyy').format(_fromDate)} – ${DateFormat('MMM d, yyyy').format(_toDate)}';

    final attendanceData = <String, int>{};
    for (final record in attendanceRecords) {
      final displayDate = record['display_date']?.toString();
      if (displayDate != null) {
        attendanceData[displayDate] = (attendanceData[displayDate] ?? 0) + 1;
      }
    }

    int present = 0, absent = 0, late = 0;
    for (final record in attendanceRecords) {
      final attendanceCategory = record['attendance_category']?.toString();
      if (attendanceCategory == 'sunday_school') {
        present++;
      } else {
        final attendanceType = record['attendance_type']?.toString() ?? '';
        if (attendanceType == 'onsite' || attendanceType == 'online') {
          present++;
        } else if (attendanceType == 'absent') {
          absent++;
        }
      }
    }

    final reportContent = _buildReportContent(
      attendance: attendance,
      giving: giving,
      attendanceRecords: attendanceRecords,
      attendanceData: attendanceData,
      present: present,
      absent: absent,
      late: late,
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: DesktopPageShell(
          banner: DesktopHeroBanner(
            title: memberName.isEmpty
                ? context.tr('Member Report')
                : '$memberName - ${context.tr('Report')}',
            subtitle: dateRange,
            icon: Icons.person_outline,
            accent: AppColors.primary,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range_outlined),
              onPressed: _selectDateRange,
              tooltip: context.tr('Select Date Range'),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _exportToCSV,
              tooltip: context.tr('Export to CSV'),
            ),
          ],
          child: reportContent,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          memberName.isEmpty
              ? context.tr('Member Report')
              : '$memberName - ${context.tr('Report')}',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: context.tr('Select Date Range'),
          ),
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: context.tr('Export to CSV'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: reportContent,
      ),
    );
  }

  Widget _buildAttendanceDetailsSection(List attendanceRecords) {
    if (attendanceRecords.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            children: [
              Icon(
                Icons.event_busy,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              SizedBox(height: AppDimensions.spacingSM),
              Text(
                context.tr('No attendance records found'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              children: [
                Icon(Icons.list, color: AppColors.primary),
                SizedBox(width: AppDimensions.spacingSM),
                Text(
                  context.tr('Attendance Details'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: attendanceRecords.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final record = attendanceRecords[index] as Map<String, dynamic>;
              final attendanceCategory =
                  record['attendance_category']?.toString() ?? 'church';
              final displayDate = record['display_date']?.toString() ?? '';
              final displayType = record['display_type']?.toString() ?? '';
              final attendanceTypeDisplay =
                  record['attendance_type_display']?.toString() ?? '';
              final createdAt = record['created_at']?.toString();

              // Determine icon and color based on attendance type
              IconData icon;
              Color color;
              if (attendanceCategory == 'sunday_school') {
                icon = Icons.school;
                color = AppColors.primary;
              } else {
                final attendanceType = record['attendance_type']?.toString();
                if (attendanceType == 'onsite') {
                  icon = Icons.church;
                  color = AppColors.success;
                } else if (attendanceType == 'online') {
                  icon = Icons.video_call;
                  color = AppColors.primary;
                } else {
                  icon = Icons.cancel_outlined;
                  color = AppColors.error;
                }
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  displayType,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: context.mic.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _formatDate(displayDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(icon, size: 14, color: color),
                        SizedBox(width: 4),
                        Text(
                          attendanceTypeDisplay,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (createdAt != null) ...[
                      SizedBox(height: 4),
                      Text(
                        context.tr('Recorded: {datetime}', {
                          'datetime': _formatDateTime(createdAt),
                        }),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: context.mic.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: AppDimensions.spacingSM),
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
