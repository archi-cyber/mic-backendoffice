import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/permission_helper.dart';
import 'add_department_page.dart';
import 'department_form_ui.dart';
import '../desktop/desktop_shell_scope.dart';

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

  Future<bool> _canCreateDepartment() async {
    try {
      // Check leader access first
      final canCreate = await PermissionHelper.canCreate('departments');
      if (canCreate) return true;

      // Fallback: Check if user is a leader of any department (legacy check)
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return false;

      final user = await SupabaseService.client
          .from('users')
          .select('member_id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (user == null || user['member_id'] == null) return false;

      final memberId = user['member_id'].toString();

      final hasLeadership = await SupabaseService.client
          .from('department_members')
          .select('id')
          .eq('member_id', memberId)
          .eq('role', 'leader')
          .maybeSingle();

      return hasLeadership != null;
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

    try {
      final tasks = await SupabaseService.client
          .from('tasks')
          .select('department_id')
          .inFilter('department_id', departmentIds);

      for (final task in List<Map<String, dynamic>>.from(tasks)) {
        final departmentId = task['department_id']?.toString();
        if (departmentId == null) continue;
        taskCounts[departmentId] = (taskCounts[departmentId] ?? 0) + 1;
      }
    } catch (_) {
      // Keep counts at zero if the task lookup fails.
    }

    try {
      final leaders = await SupabaseService.client
          .from('department_members')
          .select('department_id, role, members(first_name, last_name)')
          .inFilter('department_id', departmentIds)
          .eq('role', 'leader');

      for (final leader in List<Map<String, dynamic>>.from(leaders)) {
        final departmentId = leader['department_id']?.toString();
        final member = leader['members'];
        if (departmentId == null || member is! Map) continue;
        final firstName = member['first_name']?.toString() ?? '';
        final lastName = member['last_name']?.toString() ?? '';
        final name = '$firstName $lastName'.trim();
        if (name.isEmpty) continue;

        final existing = leaderNames[departmentId];
        leaderNames[departmentId] = existing == null || existing.isEmpty
            ? name
            : '$existing, $name';
      }
    } catch (_) {
      // Leave leader names empty if the lookup fails.
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
                bottom: DepartmentFormUi.coloredTabBar(
                  context: context,
                  tabs: [
                    Tab(text: localizations?.departments ?? 'Departments'),
                    Tab(text: localizations?.workers ?? 'Workers'),
                  ],
                ),
              ),
        body: TabBarView(
          children: [
            _buildDepartmentsTabContent(context, localizations),
            _WorkersTab(),
          ],
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
      scope.pushDetail(RouteNames.departments, departmentId);
    } else {
      Navigator.pushNamed(
        context,
        '${RouteNames.departments}/$departmentId',
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
  _WorkersTab();

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
