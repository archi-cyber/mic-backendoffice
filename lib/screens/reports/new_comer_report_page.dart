import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/new_comer_report_pdf_service.dart';
import '../../services/report_service.dart';
import '../../widgets/desktop/desktop_ui.dart';
import '../../widgets/pinned_scroll_helpers.dart';

enum _NewComerReportPeriod { weekly, monthly, yearly, custom }

class NewComerReportPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const NewComerReportPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<NewComerReportPage> createState() => _NewComerReportPageState();
}

class _NewComerReportPageState extends State<NewComerReportPage>
    with SingleTickerProviderStateMixin {
  _NewComerReportPeriod _period = _NewComerReportPeriod.monthly;
  final DateTime _referenceDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool _isLoading = true;
  Map<String, dynamic>? _report;
  String? _error;
  String _searchQuery = '';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> result;
      switch (_period) {
        case _NewComerReportPeriod.weekly:
          result = await ReportService.getWeeklyNewComerReport(
            referenceDate: _referenceDate,
          );
          break;
        case _NewComerReportPeriod.monthly:
          result = await ReportService.getMonthlyNewComerReport(
            referenceDate: _referenceDate,
          );
          break;
        case _NewComerReportPeriod.yearly:
          result = await ReportService.getYearlyNewComerReport(
            year: _selectedYear,
          );
          break;
        case _NewComerReportPeriod.custom:
          result = await ReportService.getNewComerReport(
            fromDate: _customStartDate,
            toDate: _customEndDate,
          );
          break;
      }

      if (!mounted) return;
      setState(() {
        _report = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final initial = isStart
        ? (_customStartDate ?? DateTime.now())
        : (_customEndDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart
          ? context.tr('Select start date')
          : context.tr('Select end date'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStartDate = picked;
      } else {
        _customEndDate = picked;
      }
    });
  }

  String _periodLabel() {
    switch (_period) {
      case _NewComerReportPeriod.weekly:
        return context.tr('Weekly');
      case _NewComerReportPeriod.monthly:
        return context.tr('Monthly');
      case _NewComerReportPeriod.yearly:
        return '${context.tr('Yearly')} $_selectedYear';
      case _NewComerReportPeriod.custom:
        return context.tr('Custom');
    }
  }

  List<Map<String, dynamic>> _filteredRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (_searchQuery.isEmpty) return records;
    final query = _searchQuery.toLowerCase();
    return records.where((record) {
      final firstName = (record['first_name'] ?? '').toString().toLowerCase();
      final lastName = (record['last_name'] ?? '').toString().toLowerCase();
      final status = (record['current_status'] ?? '').toString().toLowerCase();
      final intention =
          (record['newcomer_intention'] ?? '').toString().toLowerCase();
      return firstName.contains(query) ||
          lastName.contains(query) ||
          '$firstName $lastName'.contains(query) ||
          status.contains(query) ||
          intention.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredAttendanceRows(
    List<Map<String, dynamic>> rows,
  ) {
    if (_searchQuery.isEmpty) return rows;
    final query = _searchQuery.toLowerCase();
    return rows.where((row) {
      final name = (row['name'] ?? '').toString().toLowerCase();
      final status = (row['status'] ?? '').toString().toLowerCase();
      return name.contains(query) || status.contains(query);
    }).toList();
  }

  bool _isDesktopLayout(BuildContext context) {
    return isDesktopEmbedded(
      context,
      hideAppBar: widget.hideAppBarAndBottomNav,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        (_report?['status_summary'] as Map<String, dynamic>?) ?? const {};
    final records = List<Map<String, dynamic>>.from(
      _report?['records'] as List? ?? [],
    );
    final attendance =
        (_report?['attendance_report'] as Map<String, dynamic>?) ?? const {};
    final isDesktop = _isDesktopLayout(context);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: DesktopPageShell(
          isLoading: _isLoading && _error == null,
          banner: DesktopHeroBanner(
            title: context.tr('New Comers Report'),
            subtitle: context.tr('Track newcomer outcomes and attendance'),
            icon: Icons.fiber_new_rounded,
            accent: AppColors.accent,
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _generatePdfReport,
              tooltip: context.tr('Generate PDF Report'),
              icon: const Icon(Icons.picture_as_pdf),
            ),
            IconButton(
              onPressed: _isLoading ? null : _loadReport,
              tooltip: context.tr('Refresh'),
              icon: const Icon(Icons.refresh),
            ),
          ],
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingLG),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final height = MediaQuery.sizeOf(context).height - 240;
                    return SizedBox(
                      height: height.clamp(480, 1200),
                      child: _buildReportLayout(
                        summary: summary,
                        records: records,
                        attendance: attendance,
                        isDesktop: true,
                      ),
                    );
                  },
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: AppBar(
        title: Text(context.tr('New Comers Report')),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _generatePdfReport,
            tooltip: context.tr('Generate PDF Report'),
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            tooltip: context.tr('Refresh'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildReportLayout(
        summary: summary,
        records: records,
        attendance: attendance,
        isDesktop: false,
      ),
    );
  }

  Widget _buildHeaderBanner() {
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
            AppColors.accent.withValues(alpha: 0.22),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('New Comers Report'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr('Track newcomer outcomes and attendance'),
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
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_outlined,
              color: AppColors.accent,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportLayout({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> records,
    required Map<String, dynamic> attendance,
    required bool isDesktop,
  }) {
    if (!isDesktop) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_error != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        );
      }
    }

    final horizontalPadding = EdgeInsets.symmetric(
      horizontal: isDesktop ? 0 : AppDimensions.paddingMD,
    );

    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildControls(records.length, attendance),
          SizedBox(height: AppDimensions.spacingMD),
          _buildSearchBar(),
          SizedBox(height: AppDimensions.spacingSM),
          _buildTabBar(),
          SizedBox(height: AppDimensions.spacingSM),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: AppDimensions.paddingLG),
                  child: _buildSideStats(summary, attendance),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: AppDimensions.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildStatsContent(records),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: AppDimensions.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildAttendanceContent(attendance),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth >= 920 ? 1100.0 : constraints.maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(child: _buildHeaderBanner()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: horizontalPadding.copyWith(
                      top: AppDimensions.spacingMD,
                    ),
                    child: _buildControls(records.length, attendance),
                  ),
                ),
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: context.mic.background,
                    surfaceTintColor: context.mic.background,
                    elevation: innerBoxIsScrolled ? 1 : 0,
                    scrolledUnderElevation: 1,
                    toolbarHeight: 72,
                    titleSpacing: AppDimensions.paddingMD,
                    title: _buildSearchBar(),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(56),
                      child: Padding(
                        padding: horizontalPadding.copyWith(
                          bottom: AppDimensions.spacingSM,
                        ),
                        child: _buildTabBar(),
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  SafeArea(
                    top: false,
                    child: Builder(
                      builder: (context) => nestedTabBodyScrollView(
                        context: context,
                        children: [_buildSideStats(summary, attendance)],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Builder(
                      builder: (context) => nestedTabBodyScrollView(
                        context: context,
                        children: _buildStatsContent(records),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Builder(
                      builder: (context) => nestedTabBodyScrollView(
                        context: context,
                        children: _buildAttendanceContent(attendance),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: context.tr('Search members...'),
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: context.mic.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          borderSide: BorderSide(color: context.mic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          borderSide: BorderSide(color: context.mic.border),
        ),
      ),
    );
  }

  Widget _buildControls(int totalRecords, Map<String, dynamic> attendance) {
    final attended = attendance['attended'] ?? 0;

    return _ReportSurface(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Period'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.mic.appBarForeground,
            ),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: AppDimensions.spacingSM,
            children: [
              _periodChip(context.tr('Weekly'), _NewComerReportPeriod.weekly),
              _periodChip(context.tr('Monthly'), _NewComerReportPeriod.monthly),
              _periodChip(context.tr('Yearly'), _NewComerReportPeriod.yearly),
              _periodChip(context.tr('Custom'), _NewComerReportPeriod.custom),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: AppDimensions.spacingSM,
            children: [
              _SummaryPill(
                icon: Icons.date_range_outlined,
                label: _periodLabel(),
                color: AppColors.accent,
              ),
              _SummaryPill(
                icon: Icons.people_outline,
                label: '$totalRecords ${context.tr('records')}',
                color: AppColors.primary,
              ),
              _SummaryPill(
                icon: Icons.how_to_reg_outlined,
                label: '$attended ${context.tr('attendances')}',
                color: AppColors.success,
              ),
            ],
          ),
          if (_period == _NewComerReportPeriod.yearly) ...[
            SizedBox(height: AppDimensions.spacingLG),
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: InputDecoration(
                labelText: context.tr('Year'),
                filled: true,
                fillColor: context.mic.surface,
              ),
              items: List.generate(10, (i) => DateTime.now().year - i)
                  .map(
                    (year) => DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedYear = value);
                _loadReport();
              },
            ),
          ],
          if (_period == _NewComerReportPeriod.custom) ...[
            SizedBox(height: AppDimensions.spacingLG),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickCustomDate(isStart: true),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _customStartDate == null
                        ? context.tr('Start date')
                        : DateFormat('yyyy-MM-dd').format(_customStartDate!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickCustomDate(isStart: false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _customEndDate == null
                        ? context.tr('End date')
                        : DateFormat('yyyy-MM-dd').format(_customEndDate!),
                  ),
                ),
                FilledButton(
                  onPressed: _loadReport,
                  child: Text(context.tr('Apply')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return _ReportSurface(
      padding: EdgeInsets.zero,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.accent,
        unselectedLabelColor: context.mic.textSecondary,
        indicatorColor: AppColors.accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: context.tr('Summary')),
          Tab(text: context.tr('Newcomer Stats')),
          Tab(text: context.tr('Attendance Report')),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _NewComerReportPeriod value) {
    final selected = _period == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _period = value);
        _loadReport();
      },
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
      checkmarkColor: AppColors.accent,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? context.mic.appBarForeground : context.mic.textSecondary,
      ),
    );
  }

  Widget _buildSideStats(
    Map<String, dynamic> summary,
    Map<String, dynamic> attendance,
  ) {
    return _ReportSurface(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: context.tr('Summary'),
            subtitle: _periodLabel(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingMD),
            child: Divider(color: context.mic.border, height: 1),
          ),
          _SubsectionLabel(
            icon: Icons.pie_chart_outline,
            label: context.tr('Status'),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('New Comers'),
            value: '${summary['new_comer'] ?? 0}',
            color: AppColors.accent,
            icon: Icons.fiber_new_rounded,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Members'),
            value: '${summary['member'] ?? 0}',
            color: AppColors.primary,
            icon: Icons.people_outline,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Visitors'),
            value: '${summary['visitor'] ?? 0}',
            color: AppColors.secondary,
            icon: Icons.person_outline,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingMD),
            child: Divider(color: context.mic.border, height: 1),
          ),
          _SubsectionLabel(
            icon: Icons.how_to_reg_outlined,
            label: context.tr('Attendance'),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _MetricGrid(
            columns: 2,
            metrics: [
              _MetricData(
                label: context.tr('Attended'),
                value: '${attendance['attended'] ?? 0}',
                color: AppColors.success,
                icon: Icons.how_to_reg,
              ),
              _MetricData(
                label: context.tr('Services'),
                value: '${attendance['unique_services'] ?? 0}',
                color: AppColors.info,
                icon: Icons.church_outlined,
              ),
              _MetricData(
                label: context.tr('Onsite'),
                value: '${attendance['onsite'] ?? 0}',
                color: AppColors.primary,
                icon: Icons.location_on_outlined,
              ),
              _MetricData(
                label: context.tr('Online'),
                value: '${attendance['online'] ?? 0}',
                color: AppColors.accent,
                icon: Icons.wifi_tethering_outlined,
              ),
              _MetricData(
                label: context.tr('Absent'),
                value: '${attendance['absent'] ?? 0}',
                color: AppColors.error,
                icon: Icons.event_busy_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStatsContent(List<Map<String, dynamic>> records) {
    final filtered = _filteredRecords(records);

    return [
      _SectionTitle(
        title: context.tr('Records'),
        subtitle: '${filtered.length} ${context.tr('records')}',
      ),
      SizedBox(height: AppDimensions.spacingMD),
      if (filtered.isEmpty)
        _EmptyReportCard(
          message: context.tr('No newcomer records found for this period.'),
        )
      else
        ...filtered.map(_buildNewComerRecordTile),
    ];
  }

  List<Widget> _buildAttendanceContent(Map<String, dynamic> attendance) {
    final memberRows = _filteredAttendanceRows(
      List<Map<String, dynamic>>.from(
        attendance['member_rows'] as List? ?? [],
      ),
    );

    return [
      _SectionTitle(
        title: context.tr('Newcomer Attendance'),
        subtitle: '${memberRows.length} ${context.tr('records')}',
      ),
      SizedBox(height: AppDimensions.spacingMD),
      if (attendance['error'] != null)
        _EmptyReportCard(message: attendance['error'].toString())
      else if (memberRows.isEmpty)
        _EmptyReportCard(
          message: context.tr(
            'No newcomer attendance found for this period.',
          ),
        )
      else
        ...memberRows.map(_buildAttendanceTile),
    ];
  }

  Widget _buildNewComerRecordTile(Map<String, dynamic> record) {
    final fullName =
        '${record['first_name'] ?? ''} ${record['last_name'] ?? ''}'.trim();
    final status = (record['current_status'] ?? 'visitor')
        .toString()
        .replaceAll('_', ' ');
    final intention = (record['newcomer_intention'] ?? '-')
        .toString()
        .replaceAll('_', ' ');

    return _ReportRecordCard(
      leadingIcon: Icons.person_outline,
      leadingColor: AppColors.primary,
      title: fullName.isEmpty ? context.tr('Unknown') : fullName,
      details: [
        _DetailData(
          Icons.event_available_outlined,
          '${context.tr('Joined')}: ${record['newcomer_join_date'] ?? '-'}',
          AppColors.accent,
        ),
        _DetailData(
          Icons.flag_outlined,
          '${context.tr('Status')}: $status',
          AppColors.info,
        ),
        _DetailData(
          Icons.psychology_alt_outlined,
          '${context.tr('Intention')}: $intention',
          AppColors.secondaryDark,
        ),
      ],
    );
  }

  Widget _buildAttendanceTile(Map<String, dynamic> row) {
    final name = row['name']?.toString();
    final attended = row['attended'] ?? 0;
    final total = row['total'] ?? 0;

    return _ReportRecordCard(
      leadingIcon: Icons.how_to_reg_outlined,
      leadingColor: AppColors.success,
      title: name == null || name.isEmpty ? context.tr('Unknown') : name,
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMD,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Text(
          '$attended/$total',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      details: [
        _DetailData(
          Icons.church_outlined,
          '${context.tr('Onsite')}: ${row['onsite'] ?? 0}',
          AppColors.primary,
        ),
        _DetailData(
          Icons.wifi_tethering_outlined,
          '${context.tr('Online')}: ${row['online'] ?? 0}',
          AppColors.accent,
        ),
        _DetailData(
          Icons.event_busy_outlined,
          '${context.tr('Absent')}: ${row['absent'] ?? 0}',
          AppColors.error,
        ),
        _DetailData(
          Icons.history_outlined,
          '${context.tr('Last attended')}: ${row['last_attended'] ?? '-'}',
          context.mic.textSecondary,
        ),
      ],
    );
  }

  Future<void> _generatePdfReport() async {
    try {
      DateTime? startDate;
      DateTime? endDate;

      switch (_period) {
        case _NewComerReportPeriod.weekly:
          final start = DateTime(
            _referenceDate.year,
            _referenceDate.month,
            _referenceDate.day,
          ).subtract(Duration(days: _referenceDate.weekday - DateTime.monday));
          startDate = start;
          endDate = start.add(const Duration(days: 6));
          break;
        case _NewComerReportPeriod.monthly:
          startDate = DateTime(_referenceDate.year, _referenceDate.month, 1);
          endDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 0);
          break;
        case _NewComerReportPeriod.yearly:
          startDate = DateTime(_selectedYear, 1, 1);
          endDate = DateTime(_selectedYear, 12, 31);
          break;
        case _NewComerReportPeriod.custom:
          startDate = _customStartDate;
          endDate = _customEndDate;
          break;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final filePath = await NewComerReportPdfService.generateReport(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('PDF report generated: {path}', {
              'path': filePath ?? context.tr('saved'),
            }),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Failed to generate PDF report: {error}', {'error': e}),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.mic.appBarForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, this.columns});

  final List<_MetricData> metrics;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = columns ?? (constraints.maxWidth >= 280 ? 2 : 1);
        final itemWidth =
            (constraints.maxWidth -
                (AppDimensions.spacingSM * (columnCount - 1))) /
            columnCount;

        return Wrap(
          spacing: AppDimensions.spacingSM,
          runSpacing: AppDimensions.spacingSM,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: _StatCard(
                    label: metric.label,
                    value: metric.value,
                    color: metric.color,
                    icon: metric.icon,
                    compact: true,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        compact ? AppDimensions.paddingMD : AppDimensions.paddingLG,
      ),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.12),
            context.mic.surface,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: compact ? 18 : 22, color: color),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.mic.appBarForeground,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: AppDimensions.spacingXS),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.mic.textSecondary),
        SizedBox(width: AppDimensions.spacingXS),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.mic.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.mic.appBarForeground,
          ),
        ),
        SizedBox(height: AppDimensions.spacingXS),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.mic.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DetailData {
  const _DetailData(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

class _ReportRecordCard extends StatelessWidget {
  const _ReportRecordCard({
    required this.leadingIcon,
    required this.leadingColor,
    required this.title,
    required this.details,
    this.trailing,
  });

  final IconData leadingIcon;
  final Color leadingColor;
  final String title;
  final List<_DetailData> details;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: _ReportSurface(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: leadingColor.withValues(alpha: 0.12),
                  child: Icon(leadingIcon, color: leadingColor, size: 22),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.mic.appBarForeground,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: AppDimensions.spacingSM),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(detail.icon, size: 15, color: detail.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detail.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mic.textSecondary,
                        ),
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

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ReportSurface(
      padding: EdgeInsets.all(AppDimensions.paddingXL),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.mic.surfaceTint.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_outlined,
              color: AppColors.accent,
              size: 40,
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
