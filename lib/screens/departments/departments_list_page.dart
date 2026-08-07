import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../core/utils/permission_helper.dart';
import 'add_department_page.dart';
import 'department_form_ui.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Departments list page
class DepartmentsListPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  DepartmentsListPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<DepartmentsListPage> createState() => _DepartmentsListPageState();
}

class _DepartmentsListPageState extends State<DepartmentsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  int _deptPage = 0;
  static const int _deptRowsPerPage = 10;
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _canCreateDepartment().then((v) {
      if (mounted) setState(() => _canCreate = v);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Indique si l'utilisateur peut créer un département.
  ///
  /// Deux voies : la permission explicite, ou le fait de diriger déjà un
  /// département. Les appartenances sont connues depuis la connexion — les
  /// deux requêtes de l'ancienne version disparaissent.
  Future<bool> _canCreateDepartment() async {
    try {
      if (await PermissionHelper.canCreate('departments')) return true;

      // Un responsable de département peut en créer un autre, même sans la
      // permission explicite. Règle héritée, conservée telle quelle.
      return PermissionHelper.departmentRoles.any(
        (membership) => membership['role'] == 'leader',
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoading = true);
    try {
      final departments = await DepartmentService.getDepartments(limit: 100);
      final enrichedDepartments = await _enrichDepartmentsForTable(departments);
      if (!mounted) return;
      setState(() {
        _departments = enrichedDepartments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final errorMessage = ErrorMessageHelper.getErrorMessage(context, e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<List<Map<String, dynamic>>> _enrichDepartmentsForTable(
    List<Map<String, dynamic>> departments,
  ) async {
    final departmentIds = departments
        .map((dept) => dept['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    if (departmentIds.isEmpty) return departments;

    final taskCounts = <String, int>{for (final id in departmentIds) id: 0};
    final leaderNames = <String, String>{};

    // Décomptes et responsables arrivent avec la liste des départements : le
    // serveur les joint en une requête, là où le client en faisait deux.
    for (final dept in departments) {
      final id = dept['id']?.toString();
      if (id == null) continue;

      final counts = (dept['_count'] as Map?)?.cast<String, dynamic>();
      taskCounts[id] = counts?['tasks'] as int? ?? 0;

      final memberships =
          (dept['department_members'] as List?) ?? const <dynamic>[];

      final names = memberships
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .where((entry) => entry['role'] == 'leader')
          .map((entry) {
            final member = (entry['member'] as Map?)?.cast<String, dynamic>();
            final firstName = member?['first_name']?.toString() ?? '';
            final lastName = member?['last_name']?.toString() ?? '';
            return '$firstName $lastName'.trim();
          })
          .where((name) => name.isNotEmpty)
          .toList();

      if (names.isNotEmpty) {
        leaderNames[id] = names.join(', ');
      }
    }

    return departments.map((dept) {
      final id = dept['id']?.toString() ?? '';
      return {
        ...dept,
        'task_count': taskCounts[id] ?? 0,
        'leader_name': leaderNames[id] ?? '—',
      };
    }).toList();
  }

  Future<void> _openAddDepartment(BuildContext context) async {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= 700;

    if (isDesktop) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: EdgeInsets.all(AppDimensions.paddingLG),
            child: SizedBox(
              width: 920,
              height: MediaQuery.sizeOf(dialogContext).height * 0.88,
              child: AddDepartmentPage(
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true && mounted) _loadDepartments();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.addDepartment);
    if (result == true && mounted) _loadDepartments();
  }

  List<Map<String, dynamic>> get _filteredDepartments {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _departments;
    }
    return _departments
        .where(
          (dept) =>
              (dept['name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (dept['description']?.toString().toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  int get _totalDeptPages {
    if (_filteredDepartments.isEmpty) return 1;
    return (_filteredDepartments.length / _deptRowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedDepartments {
    final start = _deptPage * _deptRowsPerPage;
    final end = (start + _deptRowsPerPage).clamp(
      0,
      _filteredDepartments.length,
    );
    if (start >= _filteredDepartments.length) return [];
    return _filteredDepartments.sublist(start, end);
  }

  String _compactText(String value, {int maxLength = 24}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  String _compactLeaderLabel(String? raw) {
    final value = raw?.trim() ?? '—';
    if (value.isEmpty || value == '—') return '—';
    return _compactText(value.split(',').first.trim(), maxLength: 20);
  }

  Widget _wrapTabPanel({required Color tint, required Widget child}) {
    return ColoredBox(
      color: tint,
      child: child,
    );
  }

  Widget _buildDesktopDepartmentsTab(AppLocalizations? localizations) {
    final pageItems = _paginatedDepartments;

    return DesktopListWorkspace(
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: localizations?.departments ?? context.tr('Departments'),
        subtitle: context.tr('Organize teams, leaders, and ministry work'),
        icon: Icons.apartment_outlined,
        accent: DepartmentFormUi.accent,
      ),
      stats: [
        DesktopStatChip(
          label: context.tr('Total'),
          value: _isLoading ? '…' : '${_departments.length}',
          icon: Icons.apartment_outlined,
          color: DepartmentFormUi.accent,
        ),
        DesktopStatChip(
          label: context.tr('Active'),
          value: _isLoading ? '…' : '$_activeCount',
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        DesktopStatChip(
          label: context.tr('Showing'),
          value: _isLoading ? '…' : '${_filteredDepartments.length}',
          icon: Icons.filter_list_outlined,
          color: AppColors.accent,
        ),
      ],
      headerBelow: null,
      toolbar: _buildDepartmentsSearchBar(
        context,
        localizations,
        isDesktop: true,
      ),
      pagination: _filteredDepartments.isEmpty
          ? null
          : DesktopPaginationBar(
              currentPage: _deptPage.clamp(0, _totalDeptPages - 1),
              totalPages: _totalDeptPages,
              onPrevious:
                  _deptPage > 0 ? () => setState(() => _deptPage--) : null,
              onNext: _deptPage < _totalDeptPages - 1
                  ? () => setState(() => _deptPage++)
                  : null,
            ),
      child: DesktopDataTableCard(
          fitToWidth: true,
          emptyMessage: _searchController.text.isNotEmpty
              ? (localizations?.noDepartmentsFound ?? 'No departments found')
              : (localizations?.noDepartments ?? 'No departments yet'),
          emptyIcon: Icons.apartment_outlined,
          columns: [
            DataColumn(label: Text(context.tr('Name'))),
            DataColumn(label: Text(context.tr('Leader'))),
            DataColumn(label: Text(context.tr('Tasks'))),
            DataColumn(label: Text(context.tr('Status'))),
            DataColumn(label: Text(context.tr('Actions'))),
          ],
          rows: pageItems.map((department) {
            final name = department['name']?.toString() ?? 'Unnamed';
            final isActive = department['is_active'] == true;
            final departmentId = department['id'].toString();
            final leaderName = department['leader_name']?.toString() ?? '—';
            final taskCount = department['task_count'] as int? ?? 0;
            final theme = Theme.of(context);

            return DataRow(
              cells: [
                DataCell(
                  InkWell(
                    onTap: () => _openDepartment(departmentId),
                    child: Text(
                      _compactText(name, maxLength: 28),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _compactLeaderLabel(leaderName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                DataCell(
                  Text(
                    '$taskCount',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isActive
                          ? context.tr('Active')
                          : context.tr('Inactive'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    onPressed: () => _openDepartment(departmentId),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: context.tr('Open'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
    );
  }

  Widget _buildDepartmentsTabContent(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= 700;
    final pinnedSearchHeight = isDesktop ? 88.0 : 80.0;

    Widget buildListBody() {
      if (_isLoading) {
        return CustomScrollView(
          slivers: [
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }

      if (_filteredDepartments.isEmpty) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: isDesktop
                      ? Text(
                          _searchController.text.isNotEmpty
                              ? (localizations?.noDepartmentsFound ??
                                    'No departments found')
                              : (localizations?.noDepartments ??
                                    'No departments yet'),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_work_outlined,
                              size: 64,
                              color: context.mic.textSecondary,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? (localizations?.noDepartmentsFound ??
                                        'No departments found')
                                  : (localizations?.noDepartments ??
                                        'No departments yet'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      }

      final items = isDesktop ? _paginatedDepartments : _filteredDepartments;
      final list = ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _buildDepartmentCard(items[index]),
      );

      if (isDesktop) return list;

      return RefreshIndicator(
        onRefresh: _loadDepartments,
        child: list,
      );
    }

    final scrollView = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: _buildDepartmentsHeader()),
        SliverToBoxAdapter(child: SizedBox(height: AppDimensions.spacingMD)),
        SliverToBoxAdapter(child: _buildStatsRow()),
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: context.mic.background,
          surfaceTintColor: context.mic.background,
          elevation: 0,
          scrolledUnderElevation: 1,
          toolbarHeight: pinnedSearchHeight,
          titleSpacing: AppDimensions.paddingMD,
          title: _buildDepartmentsSearchBar(
            context,
            localizations,
            isDesktop: isDesktop,
          ),
        ),
      ],
      body: buildListBody(),
    );

    if (!isDesktop) return scrollView;

    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: scrollView),
          if (!_isLoading && _filteredDepartments.isNotEmpty)
            _buildDeptPagination(theme),
        ],
      ),
    );
  }

  Widget _buildDepartmentsSearchBar(
    BuildContext context,
    AppLocalizations? localizations, {
    required bool isDesktop,
  }) {
    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText:
            localizations?.searchDepartments ?? 'Search departments...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: context.mic.surface,
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _deptPage = 0);
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          borderSide: BorderSide(color: context.mic.border),
        ),
      ),
      onChanged: (_) => setState(() => _deptPage = 0),
    );

    if (!isDesktop) return searchField;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: searchField),
        SizedBox(width: AppDimensions.spacingMD),
        IconButton.filledTonal(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDepartments,
          tooltip: localizations?.refresh ?? 'Refresh',
        ),
        if (_canCreate) ...[
          SizedBox(width: AppDimensions.spacingSM),
          FilledButton.icon(
            onPressed: () => _openAddDepartment(context),
            icon: const Icon(Icons.add, size: 20),
            label: Text(localizations?.addDepartment ?? 'Add Department'),
          ),
        ],
      ],
    );
  }

  Widget _buildDeptPagination(ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(top: AppDimensions.spacingSM),
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
            'Page ${_deptPage + 1} of $_totalDeptPages',
            style: theme.textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _deptPage > 0 ? () => setState(() => _deptPage--) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _deptPage < _totalDeptPages - 1
                ? () => setState(() => _deptPage++)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDesktop = isDesktopEmbedded(
      context,
      hideAppBar: widget.hideAppBarAndBottomNav,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.mic.background,
        appBar: widget.hideAppBarAndBottomNav
            ? null
            : AppBar(
                title: Text(localizations?.departments ?? 'Departments'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadDepartments,
                    tooltip: localizations?.refresh ?? 'Refresh',
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.paddingMD,
                      0,
                      AppDimensions.paddingMD,
                      AppDimensions.spacingSM,
                    ),
                    child: DepartmentFormUi.listPageTabBar(
                      context: context,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.apartment_outlined, size: 18),
                          text: localizations?.departments ?? 'Departments',
                        ),
                        Tab(
                          icon: const Icon(Icons.badge_outlined, size: 18),
                          text: localizations?.workers ?? 'Workers',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.paddingMD,
                      AppDimensions.paddingMD,
                      AppDimensions.paddingMD,
                      AppDimensions.spacingSM,
                    ),
                    child: DepartmentFormUi.listPageTabBar(
                      context: context,
                      controller: tabController,
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.apartment_outlined, size: 18),
                          text: localizations?.departments ??
                              context.tr('Departments'),
                        ),
                        Tab(
                          icon: const Icon(Icons.badge_outlined, size: 18),
                          text: localizations?.workers ?? context.tr('Workers'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      _wrapTabPanel(
                        tint: DepartmentFormUi.departmentsTabTint(context),
                        child: isDesktop
                            ? _buildDesktopDepartmentsTab(localizations)
                            : _buildDepartmentsTabContent(
                                context,
                                localizations,
                              ),
                      ),
                      _wrapTabPanel(
                        tint: DepartmentFormUi.workersTabTint(context),
                        child: _WorkersTab(isDesktopView: isDesktop),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: widget.hideAppBarAndBottomNav
            ? null
            : FutureBuilder<bool>(
                future: _canCreateDepartment(),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return FloatingActionButton.extended(
                      onPressed: () => _openAddDepartment(context),
                      icon: const Icon(Icons.add),
                      label: Text(
                        localizations?.addDepartment ?? context.tr('Add Department'),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
      ),
    );
  }

  int get _activeCount =>
      _departments.where((d) => d['is_active'] == true).length;

  void _openDepartment(String departmentId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.departmentDetail, departmentId);
    } else {
      Navigator.pushNamed(
        context,
        RouteNames.departmentDetail.replaceAll(':id', departmentId),
      );
    }
  }

  Widget _buildDepartmentsHeader() {
    final localizations = AppLocalizations.of(context);
    return DepartmentFormUi.listHeaderBanner(
      context: context,
      title: localizations?.departments ?? context.tr('Departments'),
      subtitle: context.tr('Organize teams, leaders, and ministry work'),
      compactTop: widget.hideAppBarAndBottomNav,
    );
  }

  Widget _buildStatsRow() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        children: [
          DepartmentFormUi.statChip(
            context: context,
            label: context.tr('Total'),
            value: _isLoading ? '…' : '${_departments.length}',
            icon: Icons.apartment_outlined,
            color: DepartmentFormUi.accent,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          DepartmentFormUi.statChip(
            context: context,
            label: context.tr('Active'),
            value: _isLoading ? '…' : '$_activeCount',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          DepartmentFormUi.statChip(
            context: context,
            label: context.tr('Showing'),
            value: _isLoading ? '…' : '${_filteredDepartments.length}',
            icon: Icons.filter_list_outlined,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(Map<String, dynamic> department) {
    final name = department['name']?.toString() ?? 'Unnamed';
    final description = department['description']?.toString();
    final isActive = department['is_active'] == true;
    final departmentId = department['id'].toString();
    final leaderName = department['leader_name']?.toString() ?? '—';
    final taskCount = department['task_count'] as int? ?? 0;

    return DepartmentFormUi.departmentListTile(
      context: context,
      name: name,
      description: description,
      leaderName: leaderName,
      taskCount: taskCount,
      isActive: isActive,
      onTap: () => _openDepartment(departmentId),
    );
  }
}

/// Workers tab - shows all workers with their departments
class _WorkersTab extends StatefulWidget {
  const _WorkersTab({this.isDesktopView = false});

  final bool isDesktopView;

  @override
  State<_WorkersTab> createState() => _WorkersTabState();
}

class _WorkersTabState extends State<_WorkersTab> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      final workers = await DepartmentService.getAllWorkersWithDepartments();
      setState(() {
        _workers = workers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading workers: $e'))),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredWorkers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _workers;
    }
    return _workers.where((worker) {
      final member = worker['member'] as Map<String, dynamic>?;
      if (member == null) return false;

      final firstName = (member['first_name'] ?? '').toString().toLowerCase();
      final lastName = (member['last_name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final fullName = '$firstName $lastName';

      return fullName.contains(query) || email.contains(query);
    }).toList();
  }

  Widget _buildDepartmentChip(String deptName, String role, bool isMain) {
    Color color;
    IconData icon;

    switch (role) {
      case 'leader':
        color = AppColors.error;
        icon = Icons.star;
        break;
      case 'subleader':
        color = AppColors.primary;
        icon = Icons.star_border;
        break;
      default:
        color = context.mic.textSecondary;
        icon = Icons.business;
    }

    return Container(
      margin: EdgeInsets.only(right: AppDimensions.spacingXS),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMain
            ? AppColors.primary.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain ? AppColors.primary : color.withValues(alpha: 0.3),
          width: isMain ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMain) ...[
            Icon(Icons.home, size: 12, color: AppColors.primary),
            SizedBox(width: 4),
          ],
          Icon(icon, size: 12, color: isMain ? AppColors.primary : color),
          SizedBox(width: 4),
          Text(
            deptName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
              color: isMain ? AppColors.primary : color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (widget.isDesktopView) {
      return _buildDesktopWorkersBody(localizations);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: context.mic.background,
          surfaceTintColor: context.mic.background,
          elevation: innerBoxIsScrolled ? 1 : 0,
          scrolledUnderElevation: 1,
          toolbarHeight: 80,
          titleSpacing: AppDimensions.paddingMD,
          title: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  localizations?.searchWorkers ?? 'Search workers...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: context.mic.surface,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusMD,
                ),
                borderSide: BorderSide(color: context.mic.border),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
      body: _buildWorkersListBody(context, localizations),
    );
  }

  Widget _buildDesktopWorkersBody(AppLocalizations? localizations) {
    return DesktopListWorkspace(
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: localizations?.workers ?? context.tr('Workers'),
        subtitle: context.tr('Members serving across departments'),
        icon: Icons.badge_outlined,
        accent: AppColors.secondary,
      ),
      stats: [
        DesktopStatChip(
          label: context.tr('Total'),
          value: _isLoading ? '…' : '${_workers.length}',
          icon: Icons.groups_outlined,
          color: AppColors.secondary,
        ),
        DesktopStatChip(
          label: context.tr('Showing'),
          value: _isLoading ? '…' : '${_filteredWorkers.length}',
          icon: Icons.filter_list_outlined,
        ),
      ],
      toolbar: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          side: BorderSide(color: context.mic.border.withValues(alpha: 0.75)),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: localizations?.searchWorkers ??
                        context.tr('Search workers...'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.mic.background,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMD),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              IconButton.filledTonal(
                onPressed: _loadWorkers,
                icon: const Icon(Icons.refresh),
                tooltip: context.tr('Refresh'),
              ),
            ],
          ),
        ),
      ),
      child: DesktopDataTableCard(
          emptyMessage: localizations?.noWorkers ?? context.tr('No workers found'),
          emptyIcon: Icons.people_outline,
          columns: [
            DataColumn(label: Text(context.tr('Worker'))),
            DataColumn(label: Text(context.tr('Email'))),
            DataColumn(label: Text(context.tr('Departments'))),
          ],
          rows: _filteredWorkers.map((worker) {
            final member = worker['member'] as Map<String, dynamic>?;
            final departments =
                worker['departments'] as List<Map<String, dynamic>>? ?? [];
            if (member == null) {
              return DataRow(cells: List.generate(3, (_) => const DataCell(Text('—'))));
            }
            final firstName = member['first_name']?.toString() ?? '';
            final lastName = member['last_name']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            final email = member['email']?.toString() ?? '—';
            final mainDepartmentId = worker['main_department_id']?.toString();

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    fullName.isEmpty ? context.tr('Unnamed member') : fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(email, overflow: TextOverflow.ellipsis)),
                DataCell(
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: departments.map((dept) {
                      final deptName = dept['name']?.toString() ?? '';
                      final role = dept['role']?.toString() ?? 'member';
                      final deptId = dept['id']?.toString();
                      final isMain = deptId == mainDepartmentId;
                      return _buildDepartmentChip(deptName, role, isMain);
                    }).toList(),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
    );
  }

  Widget _buildWorkersListBody(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    if (_filteredWorkers.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: context.mic.textSecondary,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Text(
                      _searchController.text.isNotEmpty
                          ? (localizations?.noWorkersFound ??
                                'No workers found matching your search')
                          : (localizations?.noWorkers ?? 'No workers found'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkers,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        itemCount: _filteredWorkers.length,
        itemBuilder: (context, index) {
          final worker = _filteredWorkers[index];
          final member = worker['member'] as Map<String, dynamic>?;
          final departments =
              worker['departments'] as List<Map<String, dynamic>>? ?? [];

          if (member == null) return const SizedBox.shrink();

          final firstName = member['first_name']?.toString() ?? '';
          final lastName = member['last_name']?.toString() ?? '';
          final fullName = '$firstName $lastName'.trim();
          final email = member['email']?.toString() ?? '';
          final memberId = member['id']?.toString() ?? '';
          final mainDepartmentId = worker['main_department_id']?.toString();

          return Card(
            margin: EdgeInsets.only(bottom: AppDimensions.spacingSM),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'W',
                ),
              ),
              title: Text(
                fullName.isEmpty ? 'Unknown Worker' : fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (email.isNotEmpty) ...[
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppDimensions.spacingXS),
                  ],
                  if (departments.isNotEmpty) ...[
                    Wrap(
                      children: departments.map((dept) {
                        final deptId = dept['department_id']?.toString();
                        final isMain = deptId == mainDepartmentId;
                        return _buildDepartmentChip(
                          dept['department_name']?.toString() ?? 'Unknown',
                          dept['role']?.toString() ?? 'member',
                          isMain,
                        );
                      }).toList(),
                    ),
                  ] else
                    Text(
                      localizations?.noDepartmentsAssigned ??
                          'No departments assigned',
                      style: TextStyle(
                        color: context.mic.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.home, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          localizations?.setMainDepartment ??
                              'Set Main Department',
                        ),
                      ],
                    ),
                    onTap: () => Future.delayed(
                      const Duration(milliseconds: 100),
                      () => _showSetMainDepartmentDialog(
                        memberId,
                        fullName,
                        departments,
                        mainDepartmentId,
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.of(context).pushNamed(
                  RouteNames.memberDetail.replaceAll(':id', memberId),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSetMainDepartmentDialog(
    String memberId,
    String memberName,
    List<Map<String, dynamic>> departments,
    String? currentMainDeptId,
  ) async {
    final localizations = AppLocalizations.of(context);
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.workerNoDepartments ??
                'Worker has no departments assigned',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          localizations?.setMainDepartmentForWithName(memberName) ??
              'Set Main Department for $memberName',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: departments.length,
            itemBuilder: (context, index) {
              final dept = departments[index];
              final deptId = dept['department_id']?.toString();
              final deptName = dept['department_name']?.toString() ?? 'Unknown';
              final role = dept['role']?.toString() ?? 'member';
              final isCurrentMain = deptId == currentMainDeptId;

              return RadioListTile<String>(
                title: Text(deptName),
                subtitle: Text(
                  '${localizations?.role ?? 'Role'}: ${role.toUpperCase()}',
                ),
                value: deptId ?? '',
                groupValue: currentMainDeptId ?? '',
                onChanged: (value) async {
                  if (value != null && value != currentMainDeptId) {
                    // Close dialog first
                    Navigator.pop(context);

                    // Show loading indicator
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                localizations?.updatingMainDepartment ??
                                    'Updating main department...',
                              ),
                            ],
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }

                    try {
                      await DepartmentService.setMainDepartment(
                        memberId: memberId,
                        departmentId: value,
                      );

                      if (mounted) {
                        // Reload workers to reflect the change
                        await _loadWorkers();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localizations?.mainDepartmentUpdated ??
                                  'Main department updated successfully',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              localizations?.errorUpdatingMainDepartment ??
                                  'Error: $e',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  }
                },
                secondary: isCurrentMain
                    ? Icon(Icons.home, color: AppColors.primary)
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );
  }
}