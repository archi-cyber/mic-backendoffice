import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/attendance_report_pdf_service.dart';
import '../../services/church_attendance_service.dart';
import '../../services/visitor_service.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Page showing list of church services with details
class ChurchAttendanceListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const ChurchAttendanceListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<ChurchAttendanceListPage> createState() =>
      _ChurchAttendanceListPageState();
}

class _ChurchAttendanceListPageState extends State<ChurchAttendanceListPage> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = false;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _filterServiceType;
  final int _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_filterServiceType == null) return _services;
    return _services
        .where(
          (service) => service['service_type']?.toString() == _filterServiceType,
        )
        .toList();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final services = await ChurchAttendanceService.getAllServices(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        limit: null,
      );

      if (!mounted) return;
      setState(() {
        _services = services;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error loading services: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _filterServiceType = null;
    });
    _loadServices();
  }

  bool get _hasActiveFilters {
    return _filterStartDate != null ||
        _filterEndDate != null ||
        _filterServiceType != null;
  }

  int get _thisMonthCount {
    final now = DateTime.now();
    return _filteredServices.where((service) {
      final date = _parseServiceDate(service['service_date']?.toString());
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  int get _sundayCount {
    return _filteredServices
        .where((service) => service['service_type']?.toString() == 'sunday')
        .length;
  }

  int get _wednesdayCount {
    return _filteredServices
        .where((service) => service['service_type']?.toString() == 'wednesday')
        .length;
  }

  int get _totalAttendance {
    return _filteredServices.fold<int>(
      0,
      (sum, service) => sum + (service['attendance_count'] as int? ?? 0),
    );
  }

  int get _avgAttendance {
    if (_filteredServices.isEmpty) return 0;
    return (_totalAttendance / _filteredServices.length).round();
  }

  DateTime? _parseServiceDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String dateString) {
    final date = _parseServiceDate(dateString);
    if (date == null) return dateString;
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatWeekday(String dateString) {
    final date = _parseServiceDate(dateString);
    if (date == null) return '';
    return DateFormat('EEEE').format(date);
  }

  String _getServiceTypeLabel(String serviceType) {
    return serviceType == 'sunday'
        ? context.tr('Sunday Service')
        : context.tr('Wednesday Service');
  }

  Color _serviceColor(String serviceType) {
    return serviceType == 'sunday' ? AppColors.accent : AppColors.primary;
  }

  IconData _serviceIcon(String serviceType) {
    return serviceType == 'sunday' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
  }

  Future<void> _viewServiceDetails(
    String serviceDate,
    String serviceType,
  ) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(
        RouteNames.churchAttendance,
        '$serviceDate|$serviceType',
      );
    } else {
      final result = await Navigator.of(context).pushNamed(
        RouteNames.churchAttendance,
        arguments: {'serviceDate': serviceDate, 'serviceType': serviceType},
      );
      if (result == true) _loadServices();
    }
  }

  Future<void> _markNewAttendance() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.churchAttendance, '');
    } else {
      final result = await Navigator.of(
        context,
      ).pushNamed(RouteNames.churchAttendance);
      if (result == true) _loadServices();
    }
  }

  Future<void> _confirmDeleteService(
    String serviceDate,
    String serviceType,
  ) async {
    final label =
        '${_getServiceTypeLabel(serviceType)} on ${_formatDate(serviceDate)}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete service attendance?')),
        content: Text(
          'This will permanently remove all attendance records for $label, '
          'including visitors logged for that service.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ChurchAttendanceService.deleteService(
        serviceDate: serviceDate,
        serviceType: serviceType,
      );
      await VisitorService.deleteVisitorsForService(
        visitDate: serviceDate,
        serviceType: serviceType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Service attendance deleted')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadServices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error deleting service: $e')),
          backgroundColor: AppColors.error,
        ),
      );
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
            AppColors.primary.withValues(alpha: 0.2),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Church Attendance'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr('Track Sunday and Wednesday service attendance'),
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
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.church_outlined,
              color: AppColors.primary,
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
          _ChurchStatChip(
            label: context.tr('Services'),
            value: _isLoading ? '…' : '${_filteredServices.length}',
            icon: Icons.event_note_outlined,
            color: AppColors.primary,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _ChurchStatChip(
            label: context.tr('This month'),
            value: _isLoading ? '…' : '$_thisMonthCount',
            icon: Icons.calendar_month_outlined,
            color: AppColors.accent,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _ChurchStatChip(
            label: context.tr('Sunday Service'),
            value: _isLoading ? '…' : '$_sundayCount',
            icon: Icons.wb_sunny_outlined,
            color: AppColors.warning,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _ChurchStatChip(
            label: context.tr('Wednesday Service'),
            value: _isLoading ? '…' : '$_wednesdayCount',
            icon: Icons.nightlight_outlined,
            color: AppColors.info,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _ChurchStatChip(
            label: context.tr('Members attended'),
            value: _isLoading ? '…' : '$_totalAttendance',
            icon: Icons.people_outline,
            color: AppColors.success,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _ChurchStatChip(
            label: context.tr('Avg / service'),
            value: _isLoading ? '…' : '$_avgAttendance',
            icon: Icons.trending_up,
            color: AppColors.secondaryDark,
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
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            '${context.tr('From')}: ${_formatDate(_filterStartDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterStartDate = null);
                            _loadServices();
                          },
                        ),
                      ),
                    if (_filterEndDate != null)
                      Padding(
                        padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: const Icon(Icons.event, size: 16),
                          label: Text(
                            '${context.tr('To')}: ${_formatDate(_filterEndDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterEndDate = null);
                            _loadServices();
                          },
                        ),
                      ),
                    if (_filterServiceType != null)
                      Padding(
                        padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: Icon(
                            _serviceIcon(_filterServiceType!),
                            size: 16,
                          ),
                          label: Text(_getServiceTypeLabel(_filterServiceType!)),
                          onDeleted: () {
                            setState(() => _filterServiceType = null);
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
                context.tr('All church services'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.mic.textSecondary,
                ),
              ),
            ),
          IconButton.filledTonal(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: context.tr('Filter Services'),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _generateReport,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: context.tr('Generate Report'),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _loadServices,
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
                Icons.church_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              context.tr('No services found'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.mic.appBarForeground,
              ),
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              context.tr('Mark attendance for a new church service'),
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

  Widget _buildServiceTile(Map<String, dynamic> service) {
    final serviceDate = service['service_date'] as String;
    final serviceType = service['service_type'] as String;
    final attendanceCount = service['attendance_count'] as int? ?? 0;
    final weekday = _formatWeekday(serviceDate);
    final color = _serviceColor(serviceType);

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
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewServiceDetails(serviceDate, serviceType),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppDimensions.radiusMD),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingMD),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_serviceIcon(serviceType), color: color),
                        ),
                        SizedBox(width: AppDimensions.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getServiceTypeLabel(serviceType),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
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
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event, size: 13, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(serviceDate),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: color,
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: context.mic.textSecondary,
                                      ),
                                ),
                              ],
                              SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 14,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$attendanceCount ${attendanceCount == 1 ? context.tr('member') : context.tr('Members')} ${context.tr('attended')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: context.mic.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: color),
                          onSelected: (action) {
                            if (action == 'view') {
                              _viewServiceDetails(serviceDate, serviceType);
                            } else if (action == 'delete') {
                              _confirmDeleteService(serviceDate, serviceType);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'view',
                              child: ListTile(
                                leading: Icon(
                                  Icons.visibility_outlined,
                                  color: AppColors.primary,
                                ),
                                title: Text(context.tr('View')),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesList() {
    final services = _filteredServices;
    if (widget.hideAppBarAndBottomNav && services.isNotEmpty) {
      final total = services.length;
      final maxPage = (total - 1) ~/ _rowsPerPage;
      final currentPage = _currentPage.clamp(0, maxPage);
      final startIndex = currentPage * _rowsPerPage;
      final endIndex = (startIndex + _rowsPerPage > total)
          ? total
          : startIndex + _rowsPerPage;
      final pageItems = services.sublist(startIndex, endIndex);

      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(top: AppDimensions.spacingSM),
              itemCount: pageItems.length,
              itemBuilder: (context, index) =>
                  _buildServiceTile(pageItems[index]),
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
      onRefresh: _loadServices,
      child: ListView.builder(
        padding: EdgeInsets.only(
          top: AppDimensions.spacingSM,
          bottom: AppDimensions.spacingXL,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) => _buildServiceTile(services[index]),
      ),
    );
  }

  int get _totalServicePages {
    if (_filteredServices.isEmpty) return 1;
    return (_filteredServices.length / _rowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedServices {
    final services = _filteredServices;
    if (services.isEmpty) return [];
    final maxPage = _totalServicePages - 1;
    final currentPage = _currentPage.clamp(0, maxPage);
    final start = currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, services.length);
    return services.sublist(start, end);
  }

  Widget _buildDesktopToolbar() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_hasActiveFilters)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_filterStartDate != null)
                      Padding(
                        padding:
                            EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            '${context.tr('From')}: ${_formatDate(_filterStartDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterStartDate = null);
                            _loadServices();
                          },
                        ),
                      ),
                    if (_filterEndDate != null)
                      Padding(
                        padding:
                            EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: const Icon(Icons.event, size: 16),
                          label: Text(
                            '${context.tr('To')}: ${_formatDate(_filterEndDate!.toIso8601String().split('T')[0])}',
                          ),
                          onDeleted: () {
                            setState(() => _filterEndDate = null);
                            _loadServices();
                          },
                        ),
                      ),
                    if (_filterServiceType != null)
                      Padding(
                        padding:
                            EdgeInsets.only(right: AppDimensions.spacingSM),
                        child: Chip(
                          avatar: Icon(
                            _serviceIcon(_filterServiceType!),
                            size: 16,
                          ),
                          label:
                              Text(_getServiceTypeLabel(_filterServiceType!)),
                          onDeleted: () {
                            setState(() => _filterServiceType = null);
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
            if (_hasActiveFilters) SizedBox(height: AppDimensions.spacingSM),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _hasActiveFilters
                        ? context.tr('Filtered church services')
                        : context.tr('All church services'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list),
                  tooltip: context.tr('Filter Services'),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                IconButton.filledTonal(
                  onPressed: _isLoading ? null : _generateReport,
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: context.tr('Generate Report'),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                IconButton.filledTonal(
                  onPressed: _isLoading ? null : _loadServices,
                  icon: const Icon(Icons.refresh),
                  tooltip: context.tr('Refresh'),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                FilledButton.icon(
                  onPressed: _markNewAttendance,
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Mark Attendance')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody() {
    final theme = Theme.of(context);
    final pageItems = _paginatedServices;

    return DesktopListWorkspace(
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: context.tr('Church Attendance'),
        subtitle:
            context.tr('Track Sunday and Wednesday service attendance'),
        icon: Icons.church_outlined,
        accent: AppColors.primary,
        trailing: Text(
          '${_filteredServices.length}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: context.mic.appBarForeground,
          ),
        ),
      ),
      stats: [
        DesktopStatChip(
          label: context.tr('Services'),
          value: _isLoading ? '…' : '${_filteredServices.length}',
          icon: Icons.event_note_outlined,
        ),
        DesktopStatChip(
          label: context.tr('This month'),
          value: _isLoading ? '…' : '$_thisMonthCount',
          icon: Icons.calendar_month_outlined,
          color: AppColors.accent,
        ),
        DesktopStatChip(
          label: context.tr('Sunday Service'),
          value: _isLoading ? '…' : '$_sundayCount',
          icon: Icons.wb_sunny_outlined,
          color: AppColors.warning,
        ),
        DesktopStatChip(
          label: context.tr('Wednesday Service'),
          value: _isLoading ? '…' : '$_wednesdayCount',
          icon: Icons.nightlight_outlined,
          color: AppColors.info,
        ),
        DesktopStatChip(
          label: context.tr('Avg / service'),
          value: _isLoading ? '…' : '$_avgAttendance',
          icon: Icons.trending_up,
          color: AppColors.success,
        ),
      ],
      toolbar: _buildDesktopToolbar(),
      pagination: _filteredServices.isEmpty
          ? null
          : DesktopPaginationBar(
              currentPage: _currentPage.clamp(0, _totalServicePages - 1),
              totalPages: _totalServicePages,
              onPrevious: _currentPage > 0
                  ? () => setState(() => _currentPage--)
                  : null,
              onNext: _currentPage < _totalServicePages - 1
                  ? () => setState(() => _currentPage++)
                  : null,
            ),
      child: DesktopDataTableCard(
              emptyMessage: context.tr('No services found'),
              emptyIcon: Icons.church_outlined,
              columns: [
                DataColumn(label: Text(context.tr('Date'))),
                DataColumn(label: Text(context.tr('Service'))),
                DataColumn(label: Text(context.tr('Day'))),
                DataColumn(label: Text(context.tr('Attendance'))),
                DataColumn(label: Text(context.tr('Actions'))),
              ],
              rows: pageItems.map((service) {
                final serviceDate = service['service_date'] as String;
                final serviceType = service['service_type'] as String;
                final attendanceCount =
                    service['attendance_count'] as int? ?? 0;
                final color = _serviceColor(serviceType);
                final weekday = _formatWeekday(serviceDate);

                return DataRow(
                  cells: [
                    DataCell(
                      InkWell(
                        onTap: () =>
                            _viewServiceDetails(serviceDate, serviceType),
                        child: Text(
                          _formatDate(serviceDate),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_serviceIcon(serviceType), size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              _getServiceTypeLabel(serviceType),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(weekday)),
                    DataCell(
                      Text(
                        '$attendanceCount',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20),
                            tooltip: context.tr('View'),
                            onPressed: () => _viewServiceDetails(
                              serviceDate,
                              serviceType,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: context.tr('Delete'),
                            onPressed: () => _confirmDeleteService(
                              serviceDate,
                              serviceType,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMobileBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderBanner(),
        SizedBox(height: AppDimensions.spacingMD),
        _buildStatsRow(),
        _buildToolbar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredServices.isEmpty
                  ? _buildEmptyState()
                  : _buildServicesList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopEmbedded(
      context,
      hideAppBar: widget.hideAppBarAndBottomNav,
    );

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Church Attendance')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _isLoading ? null : _generateReport,
                  tooltip: context.tr('Generate Report'),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  tooltip: context.tr('Filter Services'),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _markNewAttendance,
                  tooltip: context.tr('Mark New Attendance'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadServices,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
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
        serviceType: _filterServiceType,
        onApply: (startDate, endDate, serviceType) {
          setState(() {
            _filterStartDate = startDate;
            _filterEndDate = endDate;
            _filterServiceType = serviceType;
            _currentPage = 0;
          });
          _loadServices();
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
        serviceType: _filterServiceType,
      ),
    );

    if (result == null || !mounted) return;

    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('en'));
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath =
          await AttendanceReportPdfService.generateChurchAttendanceReport(
            startDate: result['startDate'] as DateTime?,
            endDate: result['endDate'] as DateTime?,
            serviceType: result['serviceType'] as String?,
            localizations: l10n,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Report generated successfully: $filePath'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
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

class _ChurchStatChip extends StatelessWidget {
  const _ChurchStatChip({
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
              maxLines: 2,
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

class _ReportOptionsDialog extends StatefulWidget {
  const _ReportOptionsDialog({
    required this.startDate,
    required this.endDate,
    required this.serviceType,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? serviceType;

  @override
  State<_ReportOptionsDialog> createState() => _ReportOptionsDialogState();
}

class _ReportOptionsDialogState extends State<_ReportOptionsDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _serviceType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _serviceType = widget.serviceType;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select Start Date'),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select End Date'),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Generate Church Attendance Report')),
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.tr('Service Type'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String?>(
              title: Text(context.tr('All Services')),
              value: null,
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
            ),
            RadioListTile<String>(
              title: Text(context.tr('Sunday Service')),
              value: 'sunday',
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
            ),
            RadioListTile<String>(
              title: Text(context.tr('Wednesday Service')),
              value: 'wednesday',
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
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
            Navigator.of(context).pop({
              'startDate': _startDate,
              'endDate': _endDate,
              'serviceType': _serviceType,
            });
          },
          child: Text(context.tr('Generate')),
        ),
      ],
    );
  }
}

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({
    required this.startDate,
    required this.endDate,
    required this.serviceType,
    required this.onApply,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? serviceType;
  final void Function(DateTime?, DateTime?, String?) onApply;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _serviceType;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _serviceType = widget.serviceType;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select Start Date'),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: context.tr('Select End Date'),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Filter Services')),
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.tr('Service Type'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String?>(
              title: Text(context.tr('All Services')),
              value: null,
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
            ),
            RadioListTile<String>(
              title: Text(context.tr('Sunday Service')),
              value: 'sunday',
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
            ),
            RadioListTile<String>(
              title: Text(context.tr('Wednesday Service')),
              value: 'wednesday',
              groupValue: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
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
            widget.onApply(_startDate, _endDate, _serviceType);
            Navigator.of(context).pop();
          },
          child: Text(context.tr('Apply')),
        ),
      ],
    );
  }
}
