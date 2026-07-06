import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/sunday_school_attendance_service.dart';
import '../../services/attendance_report_pdf_service.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../core/localization/app_localizations.dart';

/// Page showing list of Sunday school sessions with details
class SundaySchoolAttendanceListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const SundaySchoolAttendanceListPage({
    super.key,
    this.hideAppBarAndBottomNav = false,
  });

  @override
  State<SundaySchoolAttendanceListPage> createState() =>
      _SundaySchoolAttendanceListPageState();
}

class _SundaySchoolAttendanceListPageState
    extends State<SundaySchoolAttendanceListPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  final int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await SundaySchoolAttendanceService.getAllSessions(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        limit: 200,
      );

      setState(() {
        _sessions = sessions;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading sessions: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _loadSessions();
  }

  bool get _hasActiveFilters {
    return _filterStartDate != null || _filterEndDate != null;
  }

  int get _thisMonthCount {
    final now = DateTime.now();
    return _sessions.where((session) {
      final date = _parseSessionDate(session['attendance_date']?.toString());
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  int get _totalAttendance {
    return _sessions.fold<int>(
      0,
      (sum, session) => sum + (session['attendance_count'] as int? ?? 0),
    );
  }

  int get _avgAttendance {
    if (_sessions.isEmpty) return 0;
    return (_totalAttendance / _sessions.length).round();
  }

  DateTime? _parseSessionDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String dateString) {
    final date = _parseSessionDate(dateString);
    if (date == null) return dateString;
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatWeekday(String dateString) {
    final date = _parseSessionDate(dateString);
    if (date == null) return '';
    return DateFormat('EEEE').format(date);
  }

  Future<void> _viewSessionDetails(String sessionDate) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.sundaySchoolAttendance, sessionDate);
    } else {
      final result = await Navigator.of(context).pushNamed(
        RouteNames.sundaySchoolAttendance,
        arguments: {'sessionDate': sessionDate},
      );
      if (result == true) _loadSessions();
    }
  }

  Future<void> _markNewAttendance() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.sundaySchoolAttendance, '');
    } else {
      final result = await Navigator.of(
        context,
      ).pushNamed(RouteNames.sundaySchoolAttendance);
      if (result == true) _loadSessions();
    }
  }

  Future<void> _deleteSession(String sessionDate) async {
    final sessionDateObj = DateTime.parse(sessionDate);
    final formattedDate = _formatDate(sessionDate);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Session')),
        content: Text(
          'Are you sure you want to delete the Sunday school session on $formattedDate? This will remove all attendance records for this session and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SundaySchoolAttendanceService.deleteSession(sessionDateObj);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Session deleted successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadSessions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting session: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildHeaderBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        widget.hideAppBarAndBottomNav ? 0 : AppDimensions.spacingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.22),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Sunday School Attendance'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr('Track children\'s attendance for each session'),
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
              color: AppColors.secondary.withValues(alpha: 0.15),
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

  Widget _buildStatsRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        children: [
          _SundaySchoolStatChip(
            label: context.tr('Sessions'),
            value: _isLoading ? '…' : '${_sessions.length}',
            icon: Icons.event_note_outlined,
            color: AppColors.secondary,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _SundaySchoolStatChip(
            label: context.tr('This month'),
            value: _isLoading ? '…' : '$_thisMonthCount',
            icon: Icons.calendar_month_outlined,
            color: AppColors.accent,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _SundaySchoolStatChip(
            label: context.tr('Children attended'),
            value: _isLoading ? '…' : '$_totalAttendance',
            icon: Icons.child_care_outlined,
            color: AppColors.primary,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _SundaySchoolStatChip(
            label: context.tr('Avg / session'),
            value: _isLoading ? '…' : '$_avgAttendance',
            icon: Icons.trending_up,
            color: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingMD,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      child: Row(
        children: [
          if (_hasActiveFilters)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterStartDate != null)
                      Padding(
                        padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: Icon(Icons.date_range, size: 16),
                          label: Text(
                            '${context.tr('From')}: ${_formatDate(_filterStartDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterStartDate = null);
                            _loadSessions();
                          },
                        ),
                      ),
                    if (_filterEndDate != null)
                      Padding(
                        padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: Icon(Icons.event, size: 16),
                          label: Text(
                            '${context.tr('To')}: ${_formatDate(_filterEndDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterEndDate = null);
                            _loadSessions();
                          },
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear, size: 18),
                      label: Text(context.tr('Clear All')),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                context.tr('All Sunday school sessions'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.mic.textSecondary,
                ),
              ),
            ),
          IconButton.filledTonal(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: context.tr('Filter Sessions'),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _generateReport,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: context.tr('Generate Report'),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _loadSessions,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('Refresh'),
          ),
          if (widget.hideAppBarAndBottomNav) ...[
            SizedBox(width: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: _markNewAttendance,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Mark Attendance')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.mic.surfaceTint.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 56,
                color: AppColors.secondaryDark,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              context.tr('No sessions found'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.mic.appBarForeground,
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              context.tr('Mark attendance for a new Sunday school session'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.mic.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            FilledButton.icon(
              onPressed: _markNewAttendance,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Mark Attendance')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final sessionDate = session['attendance_date'] as String;
    final attendanceCount = session['attendance_count'] as int? ?? 0;
    final weekday = _formatWeekday(sessionDate);

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewSessionDetails(sessionDate),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.child_care,
                    color: AppColors.secondaryDark,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Sunday School'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.mic.appBarForeground,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 13, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(sessionDate),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (weekday.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          weekday,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.mic.textSecondary),
                        ),
                      ],
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$attendanceCount ${attendanceCount == 1 ? context.tr('child') : context.tr('children')} ${context.tr('attended')}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.mic.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.secondaryDark),
                  onSelected: (action) {
                    if (action == 'view') {
                      _viewSessionDetails(sessionDate);
                    } else if (action == 'delete') {
                      _deleteSession(sessionDate);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined,
                            color: AppColors.primary),
                        title: Text(context.tr('View')),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: AppColors.error),
                        title: Text(context.tr('Delete')),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    final sessions = _sessions;
    if (widget.hideAppBarAndBottomNav && sessions.isNotEmpty) {
      final total = sessions.length;
      final maxPage = (total - 1) ~/ _rowsPerPage;
      final currentPage = _currentPage.clamp(0, maxPage);
      final startIndex = currentPage * _rowsPerPage;
      final endIndex = (startIndex + _rowsPerPage > total)
          ? total
          : startIndex + _rowsPerPage;
      final pageItems = sessions.sublist(startIndex, endIndex);

      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(top: AppDimensions.spacingSM),
              itemCount: pageItems.length,
              itemBuilder: (context, index) =>
                  _buildSessionTile(pageItems[index]),
            ),
          ),
          Container(
            margin: EdgeInsets.all(AppDimensions.paddingMD),
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.spacingSM,
            ),
            decoration: BoxDecoration(
              color: context.mic.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: context.mic.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  context.tr('Page ${currentPage + 1} of ${maxPage + 1}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentPage > 0
                      ? () => setState(() => _currentPage = currentPage - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentPage < maxPage
                      ? () => setState(() => _currentPage = currentPage + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: AppDimensions.spacingSM,
          bottom: AppDimensions.spacingXL,
        ),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _buildSessionTile(sessions[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Sunday School Attendance')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _isLoading ? null : _generateReport,
                  tooltip: context.tr('Generate Report'),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: context.tr('Filter Sessions'),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _markNewAttendance,
                  tooltip: context.tr('Mark New Attendance'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSessions,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBanner(),
          SizedBox(height: AppDimensions.spacingMD),
          _buildStatsRow(),
          _buildToolbar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? _buildEmptyState()
                : _buildSessionsList(),
          ),
        ],
      ),
      floatingActionButton: widget.hideAppBarAndBottomNav
          ? null
          : FloatingActionButton.extended(
              onPressed: _markNewAttendance,
              icon: const Icon(Icons.add),
              label: Text(context.tr('Mark Attendance')),
            ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        onApply: (startDate, endDate) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
          });
          _loadSessions();
        },
      ),
    );
  }

  Future<void> _generateReport() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReportOptionsDialog(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      ),
    );

    if (result != null) {
      try {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(child: CircularProgressIndicator()),
          );
        }

        final filePath =
            await AttendanceReportPdfService.generateSundaySchoolReport(
              startDate: result['startDate'] as DateTime?,
              endDate: result['endDate'] as DateTime?,
            );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Report generated successfully: $filePath'),
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error generating report: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

class _SundaySchoolStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SundaySchoolStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM + 4,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime?, DateTime?) onApply;

  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select Start Date'),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select End Date'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Filter Sessions')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(context.tr('Start Date')),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : context.tr('No date selected'),
              ),
              trailing: IconButton(
                icon: _startDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _startDate != null
                    ? () => setState(() => _startDate = null)
                    : _selectStartDate,
              ),
              onTap: _selectStartDate,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(context.tr('End Date')),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM d, yyyy').format(_endDate!)
                    : context.tr('No date selected'),
              ),
              trailing: IconButton(
                icon: _endDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _endDate != null
                    ? () => setState(() => _endDate = null)
                    : _selectEndDate,
              ),
              onTap: _selectEndDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_startDate, _endDate);
            Navigator.of(context).pop();
          },
          child: Text(context.tr('Apply')),
        ),
      ],
    );
  }
}

class _ReportOptionsDialog extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;

  const _ReportOptionsDialog({required this.startDate, required this.endDate});

  @override
  State<_ReportOptionsDialog> createState() => _ReportOptionsDialogState();
}

class _ReportOptionsDialogState extends State<_ReportOptionsDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select Start Date'),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select End Date'),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Generate Sunday School Report')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(context.tr('Start Date')),
              subtitle: Text(
                _startDate != null
                    ? DateFormat('MMM d, yyyy').format(_startDate!)
                    : context.tr('No date selected'),
              ),
              trailing: IconButton(
                icon: _startDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _startDate != null
                    ? () => setState(() => _startDate = null)
                    : _selectStartDate,
              ),
              onTap: _selectStartDate,
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(context.tr('End Date')),
              subtitle: Text(
                _endDate != null
                    ? DateFormat('MMM d, yyyy').format(_endDate!)
                    : context.tr('No date selected'),
              ),
              trailing: IconButton(
                icon: _endDate != null
                    ? const Icon(Icons.clear)
                    : const Icon(Icons.arrow_forward),
                onPressed: _endDate != null
                    ? () => setState(() => _endDate = null)
                    : _selectEndDate,
              ),
              onTap: _selectEndDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop({'startDate': _startDate, 'endDate': _endDate});
          },
          child: Text(context.tr('Generate')),
        ),
      ],
    );
  }
}
