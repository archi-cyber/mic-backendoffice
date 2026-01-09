import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../services/role_service.dart';
import '../../services/supabase_service.dart';
import '../../core/utils/permission_helper.dart';

/// Departments list page
class DepartmentsListPage extends StatefulWidget {
  const DepartmentsListPage({super.key});

  @override
  State<DepartmentsListPage> createState() => _DepartmentsListPageState();
}

class _DepartmentsListPageState extends State<DepartmentsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.departments ?? 'Departments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDepartments,
            tooltip: localizations?.refresh ?? 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
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
          // Departments list
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
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canCreateDepartment(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () async {
                // Navigate to add department page and wait for result
                final result = await Navigator.of(
                  context,
                ).pushNamed(RouteNames.addDepartment);
                // If department was created (result is true), reload the list
                if (result == true) {
                  _loadDepartments();
                }
              },
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
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
