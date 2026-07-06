import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/teaching_service.dart';
import '../desktop/desktop_shell_scope.dart';
import 'add_teaching_page.dart';
import 'edit_teaching_page.dart';

/// Teachings list page
class TeachingsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const TeachingsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<TeachingsListPage> createState() => _TeachingsListPageState();
}

const double _kTeachingsDesktopBreakpoint = 700;
const double _kTeachingsDesktopMaxWidth = 1000;
const int _kTeachingsRowsPerPage = 10;

class _TeachingsListPageState extends State<TeachingsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _teachings = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;
  int _teachingsPage = 0;
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTeachings();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('teachings');
    final canDelete = await PermissionHelper.canDelete('teachings');
    final canCreate = await PermissionHelper.canCreate('teachings');
    if (!mounted) return;
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
      _canCreate = canCreate;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachings() async {
    setState(() => _isLoading = true);
    try {
      final teachings = await TeachingService.getTeachings(limit: 200);
      if (!mounted) return;
      setState(() {
        _teachings = teachings;
        _isLoading = false;
        _teachingsPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorLoadingTeaching ??
                  'Error loading teaching: $e',
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTeachings {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _teachings;
    }
    return _teachings.where((teaching) {
      final title = (teaching['title'] ?? '').toString().toLowerCase();
      final description = (teaching['description'] ?? '')
          .toString()
          .toLowerCase();
      final speaker = (teaching['speaker'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          speaker.contains(query);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  int get _totalTeachingsPages {
    if (_filteredTeachings.isEmpty) return 1;
    return (_filteredTeachings.length / _kTeachingsRowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedTeachings {
    final start = _teachingsPage * _kTeachingsRowsPerPage;
    final end = (start + _kTeachingsRowsPerPage).clamp(
      0,
      _filteredTeachings.length,
    );
    if (start >= _filteredTeachings.length) return [];
    return _filteredTeachings.sublist(start, end);
  }

  void _openTeachingDetail(String teachingId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.teachingDetail, teachingId);
    } else {
      Navigator.of(
        context,
      ).pushNamed(RouteNames.teachingDetail.replaceAll(':id', teachingId));
    }
  }

  Future<void> _openAddTeaching() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      final result = await _showTeachingFormDialog(
        builder: (dialogContext) => AddTeachingPage(
          onClose: (result) => Navigator.of(dialogContext).pop(result),
        ),
      );
      if (result == true) _loadTeachings();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.addTeaching);
    if (result == true) _loadTeachings();
  }

  Future<void> _openEditTeaching(String teachingId) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      final result = await _showTeachingFormDialog(
        builder: (dialogContext) => EditTeachingPage(
          teachingId: teachingId,
          onClose: (result) => Navigator.of(dialogContext).pop(result),
        ),
      );
      if (result == true) _loadTeachings();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editTeaching.replaceAll(':id', teachingId));
    if (result == true) _loadTeachings();
  }

  Future<bool?> _showTeachingFormDialog({
    required Widget Function(BuildContext dialogContext) builder,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final height = MediaQuery.sizeOf(dialogContext).height;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXL,
            vertical: AppDimensions.paddingLG,
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 760,
            height: height * 0.86,
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  Future<void> _deleteTeaching(String teachingId, String teachingTitle) async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.delete ?? 'Delete'),
        content: Text(
          localizations?.deleteTeachingConfirmWithTitle(teachingTitle) ??
              'Are you sure you want to delete "$teachingTitle"?',
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
        await TeachingService.deleteTeaching(teachingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.teachingDeleted ??
                    'Teaching deleted successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTeachings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.errorDeletingTeaching ??
                    'Error deleting teaching: $e',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildTeachingCard(Map<String, dynamic> teaching) {
    final title = teaching['title']?.toString() ?? 'Untitled Teaching';
    final teachingDate = teaching['teaching_date'] != null
        ? DateTime.parse(teaching['teaching_date'])
        : null;
    final speaker = teaching['speaker']?.toString() ?? '';
    final description = teaching['description']?.toString() ?? '';
    final teachingId = teaching['id'].toString();

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: InkWell(
        onTap: () => _openTeachingDetail(teachingId),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_canEdit || _canDelete) ...[
                    if (_canEdit)
                      IconButton(
                        icon: Icon(Icons.edit, size: 20),
                        color: AppColors.primary,
                        onPressed: () => _openEditTeaching(teachingId),
                        tooltip: context.tr('Edit Teaching'),
                      ),
                    if (_canDelete)
                      IconButton(
                        icon: Icon(Icons.delete, size: 20),
                        color: AppColors.error,
                        onPressed: () => _deleteTeaching(teachingId, title),
                        tooltip: context.tr('Delete Teaching'),
                      ),
                  ],
                ],
              ),
              if (teachingDate != null) ...[
                SizedBox(height: AppDimensions.spacingXS),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: context.mic.textSecondary,
                    ),
                    SizedBox(width: AppDimensions.spacingXS),
                    Text(
                      _formatDate(teachingDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              if (speaker.isNotEmpty) ...[
                SizedBox(height: AppDimensions.spacingXS),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: context.mic.textSecondary,
                    ),
                    SizedBox(width: AppDimensions.spacingXS),
                    Expanded(
                      child: Text(
                        speaker,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (description.isNotEmpty) ...[
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kTeachingsDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(
                '${localizations?.teachings ?? 'Teachings'} (${_filteredTeachings.length})',
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadTeachings,
                  tooltip: localizations?.refresh ?? 'Refresh',
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
      floatingActionButton: isDesktop
          ? null
          : FutureBuilder<bool>(
              future: PermissionHelper.canCreate('teachings'),
              builder: (context, snapshot) {
                final canCreate = snapshot.data ?? false;
                if (!canCreate) return SizedBox.shrink();
                return FloatingActionButton.extended(
                  onPressed: _openAddTeaching,
                  icon: Icon(Icons.add),
                  label: Text(localizations?.addTeaching ?? 'Add Teaching'),
                );
              },
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kTeachingsDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            localizations?.searchTeachings ??
                            'Search teachings...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        _teachingsPage = 0;
                      }),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadTeachings,
                    tooltip: localizations?.refresh ?? 'Refresh',
                  ),
                  Spacer(),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: _openAddTeaching,
                      icon: Icon(Icons.add, size: 20),
                      label: Text(localizations?.addTeaching ?? 'Add Teaching'),
                    ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredTeachings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 64,
                              color: context.mic.textSecondary,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? (localizations?.noTeachingsFound ??
                                        'No teachings found matching your search')
                                  : (localizations?.noTeachings ??
                                        'No teachings yet'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: context.mic.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTeachings,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      theme.colorScheme.surfaceContainerHighest,
                                    ),
                                    columns: [
                                      DataColumn(
                                        label: Text(context.tr('Title')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Date')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Speaker')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Actions')),
                                      ),
                                    ],
                                    rows: _paginatedTeachings.map((teaching) {
                                      final id =
                                          teaching['id']?.toString() ?? '';
                                      final title =
                                          teaching['title']?.toString() ??
                                          'Untitled';
                                      final dateStr = teaching['teaching_date'];
                                      final dateFormatted = dateStr != null
                                          ? _formatDate(DateTime.parse(dateStr))
                                          : '—';
                                      final speaker =
                                          teaching['speaker']?.toString() ??
                                          '—';
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            InkWell(
                                              onTap: () =>
                                                  _openTeachingDetail(id),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  title,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(dateFormatted)),
                                          DataCell(
                                            Text(
                                              speaker,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _openTeachingDetail(id),
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                                if (_canEdit) ...[
                                                  SizedBox(width: 4),
                                                  TextButton(
                                                    onPressed: () async {
                                                      final scope =
                                                          DesktopShellScope.maybeOf(
                                                            context,
                                                          );
                                                      if (scope != null) {
                                                        scope.pushDetail(
                                                          RouteNames
                                                              .editTeaching,
                                                          id,
                                                        );
                                                      } else {
                                                        final result =
                                                            await Navigator.of(
                                                              context,
                                                            ).pushNamed(
                                                              RouteNames
                                                                  .editTeaching
                                                                  .replaceAll(
                                                                    ':id',
                                                                    id,
                                                                  ),
                                                            );
                                                        if (result == true) {
                                                          _loadTeachings();
                                                        }
                                                      }
                                                    },
                                                    child: Text(
                                                      context.tr('Edit'),
                                                    ),
                                                  ),
                                                ],
                                                if (_canDelete) ...[
                                                  SizedBox(width: 4),
                                                  TextButton(
                                                    onPressed: () =>
                                                        _deleteTeaching(
                                                          id,
                                                          title,
                                                        ),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          AppColors.error,
                                                    ),
                                                    child: Text(
                                                      context.tr('Delete'),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
              if (_filteredTeachings.isNotEmpty) ...[
                SizedBox(height: AppDimensions.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rows per page: $_kTeachingsRowsPerPage',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${_teachingsPage + 1} of $_totalTeachingsPages',
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(width: AppDimensions.spacingSM),
                        IconButton(
                          icon: Icon(Icons.chevron_left),
                          onPressed: _teachingsPage > 0
                              ? () => setState(
                                  () => _teachingsPage = _teachingsPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: _teachingsPage < _totalTeachingsPages - 1
                              ? () => setState(
                                  () => _teachingsPage = _teachingsPage + 1,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: localizations?.searchTeachings ?? 'Search teachings...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filteredTeachings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        _searchController.text.isNotEmpty
                            ? (localizations?.noTeachingsFound ??
                                  'No teachings found matching your search')
                            : (localizations?.noTeachings ??
                                  'No teachings yet'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeachings,
                  child: ListView.builder(
                    itemCount: _filteredTeachings.length,
                    itemBuilder: (context, index) {
                      return _buildTeachingCard(_filteredTeachings[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
