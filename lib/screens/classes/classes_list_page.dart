import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/class_service.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../core/localization/app_localizations.dart';
import 'add_class_page.dart';
import 'edit_class_page.dart';

/// Trainings list page
class ClassesListPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const ClassesListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<ClassesListPage> createState() => _ClassesListPageState();
}

const double _kClassesDesktopBreakpoint = 700;
const double _kClassesDesktopMaxWidth = 1000;
const int _kClassesRowsPerPage = 10;

class _ClassesListPageState extends State<ClassesListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _canCreate = false;
  int _classesPage = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadClasses();
  }

  Future<void> _checkPermissions() async {
    final canCreate = await PermissionHelper.canCreate('trainings');
    if (!mounted) return;
    setState(() => _canCreate = canCreate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final classes = await ClassService.getClasses(limit: 100);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _isLoading = false;
        _classesPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading trainings: $e'))),
        );
      }
    }
  }

  int get _totalClassesPages {
    if (_filteredClasses.isEmpty) return 1;
    return (_filteredClasses.length / _kClassesRowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedClasses {
    final start = _classesPage * _kClassesRowsPerPage;
    final end = (start + _kClassesRowsPerPage).clamp(
      0,
      _filteredClasses.length,
    );
    if (start >= _filteredClasses.length) return [];
    return _filteredClasses.sublist(start, end);
  }

  void _openClassDetail(String classId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.classDetail, classId);
    } else {
      Navigator.pushNamed(context, '${RouteNames.classes}/$classId');
    }
  }

  Future<void> _openAddClass() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      final result = await _showClassFormDialog(
        builder: (dialogContext) => AddClassPage(
          onClose: (result) => Navigator.of(dialogContext).pop(result),
        ),
      );
      if (result == true) _loadClasses();
      return;
    }

    final result = await Navigator.of(context).pushNamed(RouteNames.addClass);
    if (result == true) _loadClasses();
  }

  Future<void> _openEditClass(String classId) async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      final result = await _showClassFormDialog(
        builder: (dialogContext) => EditClassPage(
          classId: classId,
          onClose: (result) => Navigator.of(dialogContext).pop(result),
        ),
      );
      if (result == true) _loadClasses();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editClass.replaceAll(':id', classId));
    if (result == true) _loadClasses();
  }

  Future<bool?> _showClassFormDialog({
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

  List<Map<String, dynamic>> get _filteredClasses {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _classes;
    }
    return _classes
        .where(
          (cls) =>
              (cls['name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (cls['description']?.toString().toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kClassesDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Trainings')),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadClasses,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
      floatingActionButton: isDesktop
          ? null
          : FutureBuilder<bool>(
              future: PermissionHelper.canCreate('trainings'),
              builder: (context, snapshot) {
                final canCreate = snapshot.data ?? false;
                if (!canCreate) return SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: _openAddClass,
                  child: Icon(Icons.add),
                );
              },
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kClassesDesktopMaxWidth),
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
                        hintText: context.tr('Search trainings...'),
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() => _classesPage = 0),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadClasses,
                    tooltip: context.tr('Refresh'),
                  ),
                  Spacer(),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: _openAddClass,
                      icon: Icon(Icons.add, size: 20),
                      label: Text(context.tr('Add Training')),
                    ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _filteredClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 64,
                              color: context.mic.textSecondary,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No trainings found'
                                  : 'No trainings yet',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClasses,
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
                                        label: Text(context.tr('Name')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Description')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Status')),
                                      ),
                                      DataColumn(
                                        label: Text(context.tr('Actions')),
                                      ),
                                    ],
                                    rows: _paginatedClasses.map((cls) {
                                      final id = cls['id']?.toString() ?? '';
                                      final name =
                                          cls['name']?.toString() ?? 'Unnamed';
                                      final desc =
                                          cls['description']?.toString() ?? '—';
                                      final isActive = cls['is_active'] == true;
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            InkWell(
                                              onTap: () => _openClassDetail(id),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              desc,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              isActive ? 'Active' : 'Inactive',
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      _openClassDetail(id),
                                                  child: Text(
                                                    context.tr('View'),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      _openEditClass(id),
                                                  child: Text(
                                                    context.tr('Edit'),
                                                  ),
                                                ),
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
              if (_filteredClasses.isNotEmpty) ...[
                SizedBox(height: AppDimensions.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rows per page: $_kClassesRowsPerPage',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${_classesPage + 1} of $_totalClassesPages',
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(width: AppDimensions.spacingSM),
                        IconButton(
                          icon: Icon(Icons.chevron_left),
                          onPressed: _classesPage > 0
                              ? () => setState(
                                  () => _classesPage = _classesPage - 1,
                                )
                              : null,
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: _classesPage < _totalClassesPages - 1
                              ? () => setState(
                                  () => _classesPage = _classesPage + 1,
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
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search trainings...'),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _filteredClasses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 64,
                        color: context.mic.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No trainings found'
                            : 'No trainings yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadClasses,
                  child: ListView.builder(
                    itemCount: _filteredClasses.length,
                    itemBuilder: (context, index) {
                      final classItem = _filteredClasses[index];
                      return _buildClassCard(classItem);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classItem) {
    final name = classItem['name']?.toString() ?? 'Unnamed';
    final description = classItem['description']?.toString();
    final isActive = classItem['is_active'] == true;
    final classId = classItem['id'].toString();

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
        onTap: () => _openClassDetail(classId),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              // Training icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Icon(Icons.class_, color: AppColors.primary, size: 32),
              ),
              SizedBox(width: AppDimensions.spacingMD),
              // Training info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Inactive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right, color: context.mic.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
