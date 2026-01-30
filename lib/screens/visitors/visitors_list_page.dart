import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/visitor_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Visitors list page
class VisitorsListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const VisitorsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<VisitorsListPage> createState() => _VisitorsListPageState();
}

class _VisitorsListPageState extends State<VisitorsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _visitors = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;
  int _visitorsRowsPerPage = 10;
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
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildVisitorsTable() {
    final visitors = _filteredVisitors;
    final total = visitors.length;
    final rowsPerPage = _visitorsRowsPerPage;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    final maxPage = (total - 1) ~/ rowsPerPage;
    final currentPage = _visitorsPage.clamp(0, maxPage);
    final startIndex = currentPage * rowsPerPage;
    final endIndex = startIndex + rowsPerPage > total
        ? total
        : startIndex + rowsPerPage;
    final pageItems = visitors.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Visit date')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Notes')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: pageItems.map((visitor) {
                  final firstName = visitor['first_name']?.toString() ?? '';
                  final lastName = visitor['last_name']?.toString() ?? '';
                  final fullName = '$firstName $lastName'.trim();
                  final email = visitor['email']?.toString() ?? '';
                  final phone = visitor['phone']?.toString() ?? '';
                  final visitDate = visitor['visit_date'] != null
                      ? DateTime.parse(visitor['visit_date'])
                      : null;
                  final notes = visitor['notes']?.toString() ?? '';
                  final visitorId = visitor['id'].toString();

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          fullName.isEmpty ? 'Unnamed Visitor' : fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () async {
                          if (!_canEdit) return;
                          final scope = DesktopShellScope.maybeOf(context);
                          if (scope != null) {
                            scope.pushDetail(
                                RouteNames.editVisitor, visitorId);
                          } else {
                            final result =
                                await Navigator.of(
                                  context,
                                  rootNavigator: widget.hideAppBarAndBottomNav,
                                ).pushNamed(
                                  RouteNames.editVisitor.replaceAll(
                                    ':id',
                                    visitorId,
                                  ),
                                );
                            if (result == true) _loadVisitors();
                          }
                        },
                      ),
                      DataCell(
                        Text(
                          visitDate != null ? _formatDate(visitDate) : '—',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(Text(email, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(phone, overflow: TextOverflow.ellipsis)),
                      DataCell(
                        Text(
                          notes,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_canEdit)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: AppColors.primary,
                                onPressed: () async {
                                  final scope =
                                      DesktopShellScope.maybeOf(context);
                                  if (scope != null) {
                                    scope.pushDetail(
                                        RouteNames.editVisitor, visitorId);
                                  } else {
                                    final result =
                                        await Navigator.of(
                                          context,
                                          rootNavigator:
                                              widget.hideAppBarAndBottomNav,
                                        ).pushNamed(
                                          RouteNames.editVisitor.replaceAll(
                                            ':id',
                                            visitorId,
                                          ),
                                        );
                                    if (result == true) _loadVisitors();
                                  }
                                },
                                tooltip: 'Edit',
                              ),
                            if (_canDelete)
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: AppColors.error,
                                onPressed: () =>
                                    _deleteVisitor(visitorId, fullName),
                                tooltip: 'Delete',
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Rows per page: $rowsPerPage'),
              const SizedBox(width: AppDimensions.spacingMD),
              Text('Page ${currentPage + 1} of ${maxPage + 1}'),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0
                    ? () {
                        setState(() {
                          _visitorsPage = currentPage - 1;
                        });
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < maxPage
                    ? () {
                        setState(() {
                          _visitorsPage = currentPage + 1;
                        });
                      }
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

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final firstName = visitor['first_name']?.toString() ?? '';
    final lastName = visitor['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = visitor['email']?.toString() ?? '';
    final phone = visitor['phone']?.toString() ?? '';
    final visitDate = visitor['visit_date'] != null
        ? DateTime.parse(visitor['visit_date'])
        : null;
    final visitorId = visitor['id'].toString();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Unnamed Visitor' : fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: AppColors.primary,
                    onPressed: () async {
                      final scope = DesktopShellScope.maybeOf(context);
                      if (scope != null) {
                        scope.pushDetail(
                            RouteNames.editVisitor, visitorId);
                      } else {
                        final result = await Navigator.of(context).pushNamed(
                          RouteNames.editVisitor.replaceAll(
                              ':id', visitorId),
                        );
                        if (result == true) _loadVisitors();
                      }
                    },
                    tooltip: 'Edit Visitor',
                  ),
                ],
                if (_canDelete) ...[
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: AppColors.error,
                    onPressed: () => _deleteVisitor(visitorId, fullName),
                    tooltip: 'Delete Visitor',
                  ),
                ],
              ],
            ),
            if (visitDate != null) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Text(
                    'Visited: ${_formatDate(visitDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Expanded(
                    child: Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Expanded(
                    child: Text(
                      phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (visitor['notes'] != null &&
                visitor['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Text(
                visitor['notes'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(
                '${localizations?.visitors ?? 'Visitors'} (${_filteredVisitors.length})',
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadVisitors,
                  tooltip: localizations?.refresh ?? 'Refresh',
                ),
              ],
            ),
      body: Column(
        children: [
          // Top row: search, refresh (desktop), Add (desktop) — same line, aligned to table
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.paddingMD,
            ),
            child: widget.hideAppBarAndBottomNav
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 400,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                localizations?.searchVisitors ??
                                'Search visitors...',
                            prefixIcon: const Icon(Icons.search),
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
                          ),
                          onChanged: (_) {
                            setState(() {
                              _visitorsPage = 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadVisitors,
                        tooltip: localizations?.refresh ?? 'Refresh',
                      ),
                      const Spacer(),
                      FutureBuilder<bool>(
                        future: PermissionHelper.canCreate('visitors'),
                        builder: (context, snapshot) {
                          final canCreate = snapshot.data ?? false;
                          if (!canCreate) return const SizedBox.shrink();
                          return ElevatedButton.icon(
                            onPressed: () async {
                              final scope =
                                  DesktopShellScope.maybeOf(context);
                              if (scope != null) {
                                scope.pushDetail(RouteNames.addVisitor, '');
                              } else {
                                final result = await Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pushNamed(RouteNames.addVisitor);
                                if (result == true) _loadVisitors();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: Text(
                              localizations?.addVisitor ?? 'Add Visitor',
                            ),
                          );
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    localizations?.searchVisitors ??
                                    'Search visitors...',
                                prefixIcon: const Icon(Icons.search),
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
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _visitorsPage = 0;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadVisitors,
                        tooltip: localizations?.refresh ?? 'Refresh',
                      ),
                    ],
                  ),
          ),
          // Visitors list or table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisitors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No visitors found matching your search'
                              : 'No visitors yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : widget.hideAppBarAndBottomNav
                ? _buildVisitorsTable()
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    child: ListView.builder(
                      itemCount: _filteredVisitors.length,
                      itemBuilder: (context, index) {
                        return _buildVisitorCard(_filteredVisitors[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.hideAppBarAndBottomNav
          ? null
          : FutureBuilder<bool>(
              future: PermissionHelper.canCreate('visitors'),
              builder: (context, snapshot) {
                final canCreate = snapshot.data ?? false;
                if (!canCreate) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await Navigator.of(
                      context,
                      rootNavigator: widget.hideAppBarAndBottomNav,
                    ).pushNamed(RouteNames.addVisitor);
                    if (result == true) {
                      _loadVisitors();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(localizations?.addVisitor ?? 'Add Visitor'),
                );
              },
            ),
    );
  }
}
