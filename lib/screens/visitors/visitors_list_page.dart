import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/visitor_service.dart';
import '../../services/visitor_report_pdf_service.dart';
import 'visitor_form_ui.dart';
import '../desktop/desktop_shell_scope.dart';

/// Visitors list page
class VisitorsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  VisitorsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<VisitorsListPage> createState() => _VisitorsListPageState();
}

class _VisitorsListPageState extends State<VisitorsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _visitors = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canCreate = false;
  bool _canCreateMember = false;
  final int _visitorsRowsPerPage = 10;
  int _visitorsPage = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadVisitors();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('visitors');
    final canDelete = await PermissionHelper.canDelete('visitors');
    final canCreate = await PermissionHelper.canCreate('visitors');
    final canCreateMember = await PermissionHelper.canCreate('members');
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
      _canCreate = canCreate;
      _canCreateMember = canCreateMember;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      final visitors = await VisitorService.getVisitors(limit: 200);
      setState(() {
        _visitors = visitors;
        _isLoading = false;
        _visitorsPage = 0;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorLoadingVisitor ??
                  'Error loading visitors: $e',
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredVisitors {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _visitors;
    }
    return _visitors.where((visitor) {
      final name = '${visitor['first_name']} ${visitor['last_name']}'
          .toLowerCase();
      final email = (visitor['email'] ?? '').toLowerCase();
      final phone = (visitor['phone'] ?? '').toLowerCase();
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  int get _thisMonthCount {
    final now = DateTime.now();
    return _visitors.where((visitor) {
      final date = VisitorFormUi.parseVisitDate(visitor['visit_date']);
      return date != null && date.year == now.year && date.month == now.month;
    }).length;
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _visitorName(Map<String, dynamic> visitor) {
    final name =
        '${visitor['first_name'] ?? ''} ${visitor['last_name'] ?? ''}'.trim();
    return name.isEmpty ? context.tr('Unnamed Visitor') : name;
  }

  String _visitorInitials(Map<String, dynamic> visitor) {
    final name = _visitorName(visitor);
    return name.isNotEmpty ? name[0].toUpperCase() : 'V';
  }

  Future<void> _navigateToEdit(String visitorId) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.editVisitor, visitorId);
      return;
    }
    final result = await Navigator.of(
      context,
      rootNavigator: widget.hideAppBarAndBottomNav,
    ).pushNamed(RouteNames.editVisitor.replaceAll(':id', visitorId));
    if (result == true) _loadVisitors();
  }

  Future<void> _navigateToAdd() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.addVisitor, '');
      return;
    }
    final result = await Navigator.of(
      context,
      rootNavigator: widget.hideAppBarAndBottomNav,
    ).pushNamed(RouteNames.addVisitor);
    if (result == true) _loadVisitors();
  }

  Widget _buildHeaderBanner(AppLocalizations? localizations) {
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations?.visitors ?? context.tr('Visitors'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr('Track and follow up with church visitors'),
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
              Icons.groups_outlined,
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
          _VisitorStatChip(
            label: context.tr('Total'),
            value: _isLoading ? '…' : '${_visitors.length}',
            icon: Icons.people_outline,
            color: AppColors.primary,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _VisitorStatChip(
            label: context.tr('This month'),
            value: _isLoading ? '…' : '$_thisMonthCount',
            icon: Icons.calendar_month_outlined,
            color: AppColors.accent,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _VisitorStatChip(
            label: context.tr('Showing'),
            value: _isLoading ? '…' : '${_filteredVisitors.length}',
            icon: Icons.filter_list_outlined,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchToolbar(AppLocalizations? localizations) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingMD,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    localizations?.searchVisitors ??
                    context.tr('Search visitors...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.mic.surface,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _visitorsPage = 0;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMD),
                  borderSide: BorderSide(color: context.mic.border),
                ),
              ),
              onChanged: (_) {
                setState(() => _visitorsPage = 0);
              },
            ),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _loadVisitors,
            icon: const Icon(Icons.refresh),
            tooltip: localizations?.refresh ?? context.tr('Refresh'),
          ),
          if (widget.hideAppBarAndBottomNav && _canCreate) ...[
            SizedBox(width: AppDimensions.spacingSM),
            FilledButton.icon(
              onPressed: _navigateToAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(localizations?.addVisitor ?? context.tr('Add Visitor')),
            ),
          ],
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _isLoading ? null : _generatePdfReport,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: context.tr('Generate PDF Report'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations? localizations) {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.mic.surfaceTint.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.person_add_alt_1_outlined,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              isSearching
                  ? (localizations?.noVisitorsFound ??
                      context.tr('No visitors found matching your search'))
                  : (localizations?.noVisitors ?? context.tr('No visitors yet')),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.mic.appBarForeground,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearching && _canCreate) ...[
              SizedBox(height: AppDimensions.spacingMD),
              FilledButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.add),
                label: Text(localizations?.addVisitor ?? context.tr('Add Visitor')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorListTile(Map<String, dynamic> visitor) {
    final fullName = _visitorName(visitor);
    final email = visitor['email']?.toString() ?? '';
    final phone = visitor['phone']?.toString() ?? '';
    final notes = visitor['notes']?.toString() ?? '';
    final visitDate = VisitorFormUi.parseVisitDate(visitor['visit_date']);
    final visitorId = visitor['id'].toString();
    final serviceType = visitor['service_type']?.toString();

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
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _canEdit ? () => _navigateToEdit(visitorId) : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        _visitorInitials(visitor),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.mic.appBarForeground,
                            ),
                          ),
                          if (visitDate != null) ...[
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
                                  Icon(
                                    Icons.event,
                                    size: 13,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(visitDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (serviceType == 'sunday' ||
                              serviceType == 'wednesday') ...[
                            SizedBox(height: 4),
                            Text(
                              serviceType == 'sunday'
                                  ? context.tr('Sunday service')
                                  : context.tr('Wednesday service'),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.mic.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_canEdit || _canCreateMember || _canDelete)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppColors.primary,
                        ),
                        onSelected: (action) async {
                          if (action == 'edit') {
                            await _navigateToEdit(visitorId);
                          } else if (action == 'convert') {
                            await _convertVisitor(visitorId, fullName, visitor);
                          } else if (action == 'delete') {
                            await _deleteVisitor(visitorId, fullName);
                          }
                        },
                        itemBuilder: (context) => [
                          if (_canEdit)
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined,
                                    color: AppColors.primary),
                                title: Text(context.tr('Edit')),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          if (_canCreateMember)
                            PopupMenuItem(
                              value: 'convert',
                              child: ListTile(
                                leading: Icon(Icons.person_add,
                                    color: AppColors.success),
                                title: Text(context.tr('Convert to Member')),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          if (_canDelete)
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
                if (email.isNotEmpty || phone.isNotEmpty || notes.isNotEmpty) ...[
                  SizedBox(height: AppDimensions.spacingSM),
                  Wrap(
                    spacing: AppDimensions.spacingMD,
                    runSpacing: AppDimensions.spacingXS,
                    children: [
                      if (email.isNotEmpty)
                        _VisitorInfoChip(
                          icon: Icons.email_outlined,
                          text: email,
                          color: AppColors.info,
                        ),
                      if (phone.isNotEmpty)
                        _VisitorInfoChip(
                          icon: Icons.phone_outlined,
                          text: phone,
                          color: AppColors.secondaryDark,
                        ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorsTable() {
    final visitors = _filteredVisitors;
    final total = visitors.length;
    if (total == 0) return const SizedBox.shrink();

    final maxPage = (total - 1) ~/ _visitorsRowsPerPage;
    final currentPage = _visitorsPage.clamp(0, maxPage);
    final startIndex = currentPage * _visitorsRowsPerPage;
    final endIndex = (startIndex + _visitorsRowsPerPage > total)
        ? total
        : startIndex + _visitorsRowsPerPage;
    final pageItems = visitors.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(top: AppDimensions.spacingSM),
            itemCount: pageItems.length,
            itemBuilder: (context, index) =>
                _buildVisitorListTile(pageItems[index]),
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
                    ? () => setState(() => _visitorsPage = currentPage - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < maxPage
                    ? () => setState(() => _visitorsPage = currentPage + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteVisitor(String visitorId, String visitorName) async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.delete ?? 'Delete'),
        content: Text(
          localizations?.deleteVisitorConfirmWithName(visitorName) ??
              'Are you sure you want to delete "$visitorName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await VisitorService.deleteVisitor(visitorId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.visitorDeleted ?? 'Visitor deleted successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _loadVisitors();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.errorDeletingVisitor ??
                    'Error deleting visitor: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _convertVisitor(
    String visitorId,
    String visitorName,
    Map<String, dynamic> visitor,
  ) async {
    final localizations = AppLocalizations.of(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ConvertVisitorToMemberDialog(
        visitorName: visitorName,
        visitDate: visitor['visit_date'] != null
            ? DateTime.tryParse(visitor['visit_date'].toString())
            : null,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await VisitorService.convertToMember(
        visitorId: visitorId,
        birthday: result['birthday'] as DateTime,
        role: result['role'] as String,
        isNewComer: result['isNewComer'] as bool,
        newcomerIntention: result['newcomerIntention'] as String?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.visitorConvertedToMember ??
                  'Visitor converted to member successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadVisitors();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.errorConvertingVisitor ?? 'Error converting visitor to member'}: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    if (!mounted) return;

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      helpText: context.tr('Select date range for report'),
    );

    if (dateRange == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: AppDimensions.spacingMD),
                Text(context.tr('Generating PDF report...')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final filePath = await VisitorReportPdfService.generateReport(
        startDate: dateRange.start,
        endDate: dateRange.end,
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
            context.tr('Failed to generate PDF report: {error}', {
              'error': e.toString().replaceFirst('Exception: ', ''),
            }),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.visitors ?? context.tr('Visitors')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _isLoading ? null : _generatePdfReport,
                  tooltip: context.tr('Generate PDF Report'),
                ),
                if (_canCreate)
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: _navigateToAdd,
                    tooltip: localizations?.addVisitor ?? context.tr('Add Visitor'),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadVisitors,
                  tooltip: localizations?.refresh ?? context.tr('Refresh'),
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBanner(localizations),
          SizedBox(height: AppDimensions.spacingMD),
          _buildStatsRow(),
          _buildSearchToolbar(localizations),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisitors.isEmpty
                ? _buildEmptyState(localizations)
                : widget.hideAppBarAndBottomNav
                ? _buildVisitorsTable()
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        top: AppDimensions.spacingSM,
                        bottom: AppDimensions.spacingXL,
                      ),
                      itemCount: _filteredVisitors.length,
                      itemBuilder: (context, index) =>
                          _buildVisitorListTile(_filteredVisitors[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.hideAppBarAndBottomNav || !_canCreate
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(localizations?.addVisitor ?? context.tr('Add Visitor')),
            ),
    );
  }
}

class _VisitorStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _VisitorStatChip({
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

class _VisitorInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _VisitorInfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConvertVisitorToMemberDialog extends StatefulWidget {
  final String visitorName;
  final DateTime? visitDate;

  const _ConvertVisitorToMemberDialog({
    required this.visitorName,
    this.visitDate,
  });

  @override
  State<_ConvertVisitorToMemberDialog> createState() =>
      _ConvertVisitorToMemberDialogState();
}

class _ConvertVisitorToMemberDialogState
    extends State<_ConvertVisitorToMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthday;
  String _role = 'member';
  bool _isNewComer = true;
  String _newcomerIntention = 'wants_to_stay';

  Future<void> _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: context.tr('Birthday *'),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  void _submit() {
    if (_birthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Birthday is required'))),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, {
      'birthday': _birthday,
      'role': _role,
      'isNewComer': _isNewComer,
      'newcomerIntention': _isNewComer ? _newcomerIntention : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        localizations?.convertVisitorToMember ?? 'Convert visitor to member',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations?.convertVisitorToMemberConfirm(
                        widget.visitorName,
                      ) ??
                      'Create a member profile for "${widget.visitorName}" using the visitor\'s contact details. The visitor record will be removed.',
                ),
                SizedBox(height: AppDimensions.spacingMD),
                InkWell(
                  onTap: _selectBirthday,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.tr('Birthday *'),
                      prefixIcon: Icon(Icons.cake_outlined),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _birthday != null
                          ? DateFormat('MMM d, yyyy').format(_birthday!)
                          : context.tr('Select birthday'),
                      style: TextStyle(
                        color: _birthday != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: context.tr('Role *'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'member',
                      child: Text(context.tr('Member')),
                    ),
                    DropdownMenuItem(
                      value: 'leader',
                      child: Text(context.tr('Leader')),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text(context.tr('Admin')),
                    ),
                    DropdownMenuItem(
                      value: 'worker',
                      child: Text(context.tr('Worker')),
                    ),
                    DropdownMenuItem(
                      value: 'sympathiser',
                      child: Text(context.tr('Sympathiser')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                SizedBox(height: AppDimensions.spacingSM),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('New Comer')),
                  subtitle: Text(
                    context.tr(
                      'Status will change to member after 9+ service attendances in 3 months.',
                    ),
                  ),
                  value: _isNewComer,
                  onChanged: (value) {
                    setState(() => _isNewComer = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_isNewComer) ...[
                  SizedBox(height: AppDimensions.spacingSM),
                  DropdownButtonFormField<String>(
                    initialValue: _newcomerIntention,
                    decoration: InputDecoration(
                      labelText: context.tr('Newcomer Intention'),
                      prefixIcon: Icon(Icons.help_outline),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'wants_to_stay',
                        child: Text(context.tr('Wants to stay')),
                      ),
                      DropdownMenuItem(
                        value: 'does_not_know_yet',
                        child: Text(context.tr('Does not know yet')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _newcomerIntention = value);
                      }
                    },
                  ),
                  if (widget.visitDate != null) ...[
                    SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      '${context.tr('Newcomer Join Date')}: ${DateFormat('MMM d, yyyy').format(widget.visitDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(localizations?.convertToMember ?? 'Convert to Member'),
        ),
      ],
    );
  }
}
