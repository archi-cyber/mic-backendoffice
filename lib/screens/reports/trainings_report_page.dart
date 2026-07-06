import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/trainings_report_service.dart';
import '../../widgets/desktop/desktop_ui.dart';
import '../../widgets/pinned_scroll_helpers.dart';
import '../desktop/desktop_shell_scope.dart';
import 'class_report_page.dart';

enum _TrainingsReportPeriod { weekly, monthly, yearly, custom }

class TrainingsReportPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const TrainingsReportPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<TrainingsReportPage> createState() => _TrainingsReportPageState();
}

class _TrainingsReportPageState extends State<TrainingsReportPage>
    with SingleTickerProviderStateMixin {
  _TrainingsReportPeriod _period = _TrainingsReportPeriod.monthly;
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
    _tabController = TabController(length: 2, vsync: this);
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
      final Map<String, dynamic> result;
      switch (_period) {
        case _TrainingsReportPeriod.weekly:
          result = await TrainingsReportService.getWeeklyReport(
            referenceDate: _referenceDate,
          );
          break;
        case _TrainingsReportPeriod.monthly:
          result = await TrainingsReportService.getMonthlyReport(
            referenceDate: _referenceDate,
          );
          break;
        case _TrainingsReportPeriod.yearly:
          result = await TrainingsReportService.getYearlyReport(
            year: _selectedYear,
          );
          break;
        case _TrainingsReportPeriod.custom:
          result = await TrainingsReportService.getReport(
            startDate: _customStartDate,
            endDate: _customEndDate,
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
      case _TrainingsReportPeriod.weekly:
        return context.tr('Weekly');
      case _TrainingsReportPeriod.monthly:
        return context.tr('Monthly');
      case _TrainingsReportPeriod.yearly:
        return '${context.tr('Yearly')} $_selectedYear';
      case _TrainingsReportPeriod.custom:
        return context.tr('Custom');
    }
  }

  List<Map<String, dynamic>> _filteredRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (_searchQuery.isEmpty) return records;
    final query = _searchQuery.toLowerCase();
    return records.where((record) {
      final name = (record['name'] ?? '').toString().toLowerCase();
      final description = (record['description'] ?? '').toString().toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  void _openTrainingReport(String classId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.classReport, classId);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassReportPage(classId: classId),
      ),
    );
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
        (_report?['summary'] as Map<String, dynamic>?) ?? const {};
    final records = List<Map<String, dynamic>>.from(
      _report?['records'] as List? ?? [],
    );
    final isDesktop = _isDesktopLayout(context);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: DesktopPageShell(
          isLoading: _isLoading && _error == null,
          banner: DesktopHeroBanner(
            title: context.tr('Training Report'),
            subtitle: context.tr(
              'Review training summaries before opening a detailed report',
            ),
            icon: Icons.school_outlined,
            accent: AppColors.secondaryDark,
          ),
          actions: [
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
        title: Text(context.tr('Training Report')),
        actions: [
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
        isDesktop: false,
      ),
    );
  }

  Widget _buildReportLayout({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> records,
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
          _buildControls(summary, records.length),
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
                  child: _buildSummaryPanel(summary),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: AppDimensions.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildTrainingsContent(
                      _filteredRecords(records),
                    ),
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
                    child: _buildControls(summary, records.length),
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
                        children: [_buildSummaryPanel(summary)],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Builder(
                      builder: (context) => nestedTabBodyScrollView(
                        context: context,
                        children: _buildTrainingsContent(
                          _filteredRecords(records),
                        ),
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
        gradient: context.mic.headerGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(
          color: context.mic.border,
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
                  context.tr(
                    'Review training summaries before opening a detailed report',
                  ),
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

  Widget _buildControls(Map<String, dynamic> summary, int totalRecords) {
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
              _periodChip(context.tr('Weekly'), _TrainingsReportPeriod.weekly),
              _periodChip(
                context.tr('Monthly'),
                _TrainingsReportPeriod.monthly,
              ),
              _periodChip(context.tr('Yearly'), _TrainingsReportPeriod.yearly),
              _periodChip(context.tr('Custom'), _TrainingsReportPeriod.custom),
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
                icon: Icons.school_outlined,
                label:
                    '${summary['total_trainings'] ?? 0} ${context.tr('classes')}',
                color: AppColors.secondaryDark,
              ),
              _SummaryPill(
                icon: Icons.event_outlined,
                label:
                    '${summary['total_sessions'] ?? 0} ${context.tr('Sessions')}',
                color: AppColors.primary,
              ),
              _SummaryPill(
                icon: Icons.how_to_reg_outlined,
                label:
                    '${summary['total_attendance'] ?? 0} ${context.tr('attendances')}',
                color: AppColors.success,
              ),
            ],
          ),
          if (_period == _TrainingsReportPeriod.yearly) ...[
            SizedBox(height: AppDimensions.spacingLG),
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: InputDecoration(
                labelText: context.tr('Year'),
                filled: true,
                fillColor: context.mic.surface,
              ),
              items: List.generate(10, (index) => DateTime.now().year - index)
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
          if (_period == _TrainingsReportPeriod.custom) ...[
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

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: context.tr('Search trainings...'),
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

  Widget _buildTabBar() {
    return _ReportSurface(
      padding: EdgeInsets.zero,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.secondaryDark,
        unselectedLabelColor: context.mic.textSecondary,
        indicatorColor: AppColors.secondaryDark,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: context.tr('Summary')),
          Tab(text: context.tr('Trainings')),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _TrainingsReportPeriod value) {
    final selected = _period == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _period = value);
        _loadReport();
      },
      selectedColor: AppColors.secondaryDark.withValues(alpha: 0.16),
      checkmarkColor: AppColors.secondaryDark,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? context.mic.appBarForeground : context.mic.textSecondary,
      ),
    );
  }

  Widget _buildSummaryPanel(Map<String, dynamic> summary) {
    return _ReportSurface(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Summary'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.mic.appBarForeground,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXS),
          Text(
            _periodLabel(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingMD),
            child: Divider(color: context.mic.border, height: 1),
          ),
          _StatCard(
            label: context.tr('classes'),
            value: '${summary['total_trainings'] ?? 0}',
            color: AppColors.secondaryDark,
            icon: Icons.school_outlined,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Active'),
            value: '${summary['active_trainings'] ?? 0}',
            color: AppColors.success,
            icon: Icons.check_circle_outline,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Sessions'),
            value: '${summary['total_sessions'] ?? 0}',
            color: AppColors.primary,
            icon: Icons.event_outlined,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Total Attendance'),
            value: '${summary['total_attendance'] ?? 0}',
            color: AppColors.accent,
            icon: Icons.how_to_reg_outlined,
          ),
          SizedBox(height: AppDimensions.spacingSM),
          _StatCard(
            label: context.tr('Enrollments'),
            value: '${summary['total_enrollments'] ?? 0}',
            color: AppColors.info,
            icon: Icons.people_outline,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTrainingsContent(List<Map<String, dynamic>> records) {
    return [
      Text(
        context.tr('Trainings'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.mic.appBarForeground,
        ),
      ),
      SizedBox(height: AppDimensions.spacingXS),
      Text(
        '${records.length} ${context.tr('records')}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.mic.textSecondary,
        ),
      ),
      SizedBox(height: AppDimensions.spacingMD),
      if (records.isEmpty)
        _EmptyReportCard(
          message: context.tr('No trainings found for this period.'),
        )
      else
        ...records.map(_buildTrainingCard),
    ];
  }

  Widget _buildTrainingCard(Map<String, dynamic> record) {
    final classId = record['class_id']?.toString() ?? '';
    final name = record['name']?.toString() ?? context.tr('Unnamed Training');
    final description = record['description']?.toString();
    final isActive = record['is_active'] == true;
    final sessions = record['session_count'] ?? 0;
    final members = record['member_count'] ?? 0;
    final attendance = record['attendance_count'] ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingSM),
      child: Material(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        child: InkWell(
          onTap: classId.isEmpty ? null : () => _openTrainingReport(classId),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              border: Border.all(color: context.mic.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondaryDark.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.mic.appBarForeground,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _MiniChip(
                              icon: Icons.people_outline,
                              label: '$members ${context.tr('Members')}',
                            ),
                            _MiniChip(
                              icon: Icons.event_outlined,
                              label: '$sessions ${context.tr('Sessions')}',
                            ),
                            _MiniChip(
                              icon: Icons.how_to_reg_outlined,
                              label: '$attendance ${context.tr('Present')}',
                            ),
                            _MiniChip(
                              icon: isActive
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                              label: isActive
                                  ? context.tr('Active')
                                  : context.tr('Inactive'),
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.mic.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.paddingSM,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: AppDimensions.spacingXS),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.mic.appBarForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

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

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.mic.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: chipColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: chipColor,
            ),
          ),
        ),
      ],
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
          Icon(
            Icons.school_outlined,
            size: 48,
            color: context.mic.textSecondary,
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
