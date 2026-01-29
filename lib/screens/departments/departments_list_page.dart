import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/permission_helper.dart';
import '../desktop/desktop_shell_scope.dart';

/// Departments list page
class DepartmentsListPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  const DepartmentsListPage({super.key, this.hideAppBarAndBottomNav = false});

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
      setState(() {
        _departments = departments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final errorMessage = ErrorMessageHelper.getErrorMessage(context, e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    }
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

  Widget _buildDesktopDepartmentsContent(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    final scope = DesktopShellScope.maybeOf(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search + Add row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        localizations?.searchDepartments ??
                        'Search departments...',
                    prefixIcon: const Icon(Icons.search),
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
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMD,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _deptPage = 0),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDepartments,
                tooltip: localizations?.refresh ?? 'Refresh',
              ),
              const Spacer(),
              if (_canCreate)
                FilledButton.icon(
                  onPressed: () {
                    if (scope != null) {
                      scope.pushDetail(RouteNames.addDepartment, '');
                    } else {
                      Navigator.of(
                        context,
                      ).pushNamed(RouteNames.addDepartment).then((_) {
                        if (mounted) _loadDepartments();
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(localizations?.addDepartment ?? 'Add Department'),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDepartments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.group_work_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          _searchController.text.isNotEmpty
                              ? (localizations?.noDepartmentsFound ??
                                    'No departments found')
                              : (localizations?.noDepartments ??
                                    'No departments yet'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        theme.colorScheme.surfaceContainerHighest,
                      ),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _paginatedDepartments.map((dept) {
                        final id = dept['id']?.toString() ?? '';
                        final name = dept['name']?.toString() ?? 'Unnamed';
                        final desc = dept['description']?.toString() ?? '—';
                        final isActive = dept['is_active'] == true;
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(name, overflow: TextOverflow.ellipsis),
                            ),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Text(
                                  desc,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                isActive
                                    ? (localizations?.active ?? 'Active')
                                    : (localizations?.inactive ?? 'Inactive'),
                                style: TextStyle(
                                  color: isActive
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(
                              TextButton(
                                onPressed: () {
                                  if (id.isEmpty) return;
                                  if (scope != null) {
                                    scope.pushDetail(
                                      RouteNames.departmentDetail,
                                      id,
                                    );
                                  } else {
                                    Navigator.of(context).pushNamed(
                                      RouteNames.departmentDetail.replaceAll(
                                        ':id',
                                        id,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('View'),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          if (!_filteredDepartments.isEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSM),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rows per page: $_deptRowsPerPage',
                  style: theme.textTheme.bodySmall,
                ),
                Row(
                  children: [
                    Text(
                      'Page ${_deptPage + 1} of $_totalDeptPages',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppDimensions.spacingMD),
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _deptPage > 0
                          ? () => setState(() => _deptPage--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _deptPage < _totalDeptPages - 1
                          ? () => setState(() => _deptPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileDepartmentsContent(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  localizations?.searchDepartments ?? 'Search departments...',
              prefixIcon: const Icon(Icons.search),
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
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredDepartments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.group_work_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
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
                )
              : RefreshIndicator(
                  onRefresh: _loadDepartments,
                  child: ListView.builder(
                    itemCount: _filteredDepartments.length,
                    itemBuilder: (context, index) {
                      final department = _filteredDepartments[index];
                      return _buildDepartmentCard(department);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                bottom: TabBar(
                  tabs: [
                    Tab(text: localizations?.departments ?? 'Departments'),
                    Tab(text: localizations?.workers ?? 'Workers'),
                  ],
                ),
              ),
        body: TabBarView(
          children: [
            // Departments tab
            widget.hideAppBarAndBottomNav
                ? _buildDesktopDepartmentsContent(context, localizations)
                : _buildMobileDepartmentsContent(context, localizations),
            // Workers tab
            _WorkersTab(),
          ],
        ),
        floatingActionButton: widget.hideAppBarAndBottomNav
            ? null
            : FutureBuilder<bool>(
                future: _canCreateDepartment(),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return FloatingActionButton(
                      onPressed: () async {
                        final result = await Navigator.of(
                          context,
                        ).pushNamed(RouteNames.addDepartment);
                        if (result == true) _loadDepartments();
                      },
                      child: const Icon(Icons.add),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
      ),
    );
  }

  Widget _buildDepartmentCard(Map<String, dynamic> department) {
    final name = department['name']?.toString() ?? 'Unnamed';
    final description = department['description']?.toString();
    final isActive = department['is_active'] == true;
    final departmentId = department['id'].toString();
    final localizations = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '${RouteNames.departments}/$departmentId',
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              // Department icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Center(
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              // Department info
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              localizations?.inactive ?? 'Inactive',
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
                      const SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workers tab - shows all workers with their departments
class _WorkersTab extends StatefulWidget {
  const _WorkersTab();

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading workers: $e')));
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
        color = AppColors.textSecondary;
        icon = Icons.business;
    }

    return Container(
      margin: const EdgeInsets.only(right: AppDimensions.spacingXS),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMain
            ? AppColors.primary.withOpacity(0.2)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMain ? AppColors.primary : color.withOpacity(0.3),
          width: isMain ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMain) ...[
            const Icon(Icons.home, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
          ],
          Icon(icon, size: 12, color: isMain ? AppColors.primary : color),
          const SizedBox(width: 4),
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

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: localizations?.searchWorkers ?? 'Search workers...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
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
        // Workers list
        Expanded(
          child: _filteredWorkers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        _searchController.text.isNotEmpty
                            ? (localizations?.noWorkersFound ??
                                  'No workers found matching your search')
                            : (localizations?.noWorkers ?? 'No workers found'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWorkers,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingMD,
                    ),
                    itemCount: _filteredWorkers.length,
                    itemBuilder: (context, index) {
                      final worker = _filteredWorkers[index];
                      final member = worker['member'] as Map<String, dynamic>?;
                      final departments =
                          worker['departments']
                              as List<Map<String, dynamic>>? ??
                          [];

                      if (member == null) return const SizedBox.shrink();

                      final firstName = member['first_name']?.toString() ?? '';
                      final lastName = member['last_name']?.toString() ?? '';
                      final fullName = '$firstName $lastName'.trim();
                      final email = member['email']?.toString() ?? '';
                      final memberId = member['id']?.toString() ?? '';
                      final mainDepartmentId = worker['main_department_id']
                          ?.toString();

                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacingSM,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              fullName.isNotEmpty
                                  ? fullName[0].toUpperCase()
                                  : 'W',
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
                                const SizedBox(height: AppDimensions.spacingXS),
                              ],
                              if (departments.isNotEmpty) ...[
                                Wrap(
                                  children: departments.map((dept) {
                                    final deptId = dept['department_id']
                                        ?.toString();
                                    final isMain = deptId == mainDepartmentId;
                                    return _buildDepartmentChip(
                                      dept['department_name']?.toString() ??
                                          'Unknown',
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
                                    color: AppColors.textSecondary,
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
                              RouteNames.memberDetail.replaceAll(
                                ':id',
                                memberId,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
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
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                localizations?.updatingMainDepartment ??
                                    'Updating main department...',
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
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
                    ? const Icon(Icons.home, color: AppColors.primary)
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
