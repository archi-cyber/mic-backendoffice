import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../services/task_service.dart';
import '../../services/member_service.dart';

/// Department detail with members, docs, tasks, and reports
class DepartmentDetailPage extends StatefulWidget {
  final String departmentId;

  const DepartmentDetailPage({super.key, required this.departmentId});

  @override
  State<DepartmentDetailPage> createState() => _DepartmentDetailPageState();
}

class _DepartmentDetailPageState extends State<DepartmentDetailPage> {
  Map<String, dynamic>? _department;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartmentData();
  }

  Future<void> _loadDepartmentData() async {
    setState(() => _isLoading = true);
    try {
      final department = await DepartmentService.getDepartmentById(
        widget.departmentId,
      );
      final departmentMembers = await DepartmentService.getDepartmentMembers(
        widget.departmentId,
      );
      final departmentTasks = await TaskService.getDepartmentTasks(
        departmentId: widget.departmentId,
        limit: 100,
      );

      setState(() {
        _department = department;
        // Store full department_members data (includes role)
        _members = departmentMembers;
        _tasks = departmentTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading department: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_department == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Department')),
        body: const Center(child: Text('Department not found')),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_department!['name'] ?? 'Department'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed(
                  RouteNames.editDepartment.replaceAll(
                    ':id',
                    widget.departmentId,
                  ),
                );
                if (result == true) {
                  _loadDepartmentData();
                }
              },
              tooltip: 'Edit Department',
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete Department'),
                    ],
                  ),
                  onTap: () => _deleteDepartment(),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'Tasks'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              department: _department!,
              memberCount: _members.length,
              taskCount: _tasks.length,
              onDepartmentUpdated: _loadDepartmentData,
            ),
            _MembersTab(
              departmentId: widget.departmentId,
              onMembersUpdated: _loadDepartmentData,
            ),
            _TasksTab(departmentId: widget.departmentId, tasks: _tasks),
            _ReportsTab(departmentId: widget.departmentId),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDepartment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Department'),
        content: const Text(
          'Are you sure you want to delete this department? This will deactivate it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DepartmentService.deleteDepartment(widget.departmentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Department deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting department: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

/// Overview tab
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> department;
  final int memberCount;
  final int taskCount;
  final VoidCallback onDepartmentUpdated;

  const _OverviewTab({
    required this.department,
    required this.memberCount,
    required this.taskCount,
    required this.onDepartmentUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                Text(
                  department['description'] ?? 'No description',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        // Documents section
        if (_hasDocuments(department))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  if (department['document_1_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_1_name'].toString(),
                      department['document_1_url']?.toString(),
                    ),
                  if (department['document_2_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_2_name'].toString(),
                      department['document_2_url']?.toString(),
                    ),
                  if (department['document_3_name'] != null)
                    _buildDocumentTile(
                      context,
                      department['document_3_name'].toString(),
                      department['document_3_url']?.toString(),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.spacingMD),
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Members',
                value: memberCount.toString(),
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: _StatCard(
                title: 'Tasks',
                value: taskCount.toString(),
                icon: Icons.task,
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _hasDocuments(Map<String, dynamic> department) {
    return department['document_1_name'] != null ||
        department['document_2_name'] != null ||
        department['document_3_name'] != null;
  }

  Widget _buildDocumentTile(
    BuildContext context,
    String fileName,
    String? fileUrl,
  ) {
    return ListTile(
      leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
      title: Text(fileName),
      trailing: fileUrl != null
          ? IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                final uri = Uri.parse(fileUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              tooltip: 'Open document',
            )
          : null,
      onTap: fileUrl != null
          ? () async {
              final uri = Uri.parse(fileUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          : null,
    );
  }
}

/// Members tab
class _MembersTab extends StatefulWidget {
  final String departmentId;
  final VoidCallback onMembersUpdated;

  const _MembersTab({
    required this.departmentId,
    required this.onMembersUpdated,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await DepartmentService.getDepartmentMembers(
        widget.departmentId,
      );
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  Future<void> _showAddMemberDialog() async {
    try {
      // Get all members
      final allMembers = await MemberService.getMembers(limit: 1000);

      // Get current member IDs in department
      final currentMemberIds = _members
          .map((dm) => dm['member_id']?.toString())
          .where((id) => id != null)
          .toSet();

      // Filter out members already in department
      final availableMembers = allMembers
          .where((m) => !currentMemberIds.contains(m['id']?.toString()))
          .toList();

      if (availableMembers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All members are already in this department'),
            ),
          );
        }
        return;
      }

      String? selectedMemberId;
      String selectedRole = 'member';

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Member'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Member',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: availableMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'].toString(),
                        child: Text(
                          '${member['first_name']} ${member['last_name']}',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedMemberId = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(
                        value: 'subleader',
                        child: Text('Subleader'),
                      ),
                      DropdownMenuItem(value: 'leader', child: Text('Leader')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRole = value ?? 'member';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedMemberId == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );

      if (result == true && selectedMemberId != null) {
        await DepartmentService.addMemberToDepartment(
          departmentId: widget.departmentId,
          memberId: selectedMemberId!,
          role: selectedRole,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member added successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadMembers();
          widget.onMembersUpdated();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeMemberRole(String memberId, String currentRole) async {
    String? selectedRole = currentRole;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Role'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge),
            ),
            items: const [
              DropdownMenuItem(value: 'member', child: Text('Member')),
              DropdownMenuItem(value: 'subleader', child: Text('Subleader')),
              DropdownMenuItem(value: 'leader', child: Text('Leader')),
            ],
            onChanged: (value) {
              setDialogState(() {
                selectedRole = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedRole != null && selectedRole != currentRole) {
      try {
        await DepartmentService.addMemberToDepartment(
          departmentId: widget.departmentId,
          memberId: memberId,
          role: selectedRole!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Role updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadMembers();
          widget.onMembersUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating role: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from this department?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DepartmentService.removeMemberFromDepartment(
          departmentId: widget.departmentId,
          memberId: memberId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadMembers();
          widget.onMembersUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildRoleChip(String role) {
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
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Add member button
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: ElevatedButton.icon(
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Member'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                AppDimensions.buttonHeightMD,
              ),
            ),
          ),
        ),
        // Members list
        Expanded(
          child: _members.isEmpty
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
                      const Text('No members in this department'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final departmentMember = _members[index];
                      final member =
                          departmentMember['members'] as Map<String, dynamic>?;
                      if (member == null) return const SizedBox.shrink();

                      final role =
                          departmentMember['role']?.toString() ?? 'member';
                      final memberId =
                          departmentMember['member_id']?.toString() ?? '';
                      final memberName =
                          '${member['first_name']} ${member['last_name']}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingMD,
                          vertical: AppDimensions.spacingXS,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member['first_name']?[0]
                                      ?.toString()
                                      .toUpperCase() ??
                                  'M',
                            ),
                          ),
                          title: Text(memberName),
                          subtitle: Text(member['email']?.toString() ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildRoleChip(role),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.badge, size: 20),
                                        SizedBox(width: 8),
                                        Text('Change Role'),
                                      ],
                                    ),
                                    onTap: () =>
                                        _changeMemberRole(memberId, role),
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.remove_circle,
                                          color: AppColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Remove'),
                                      ],
                                    ),
                                    onTap: () =>
                                        _removeMember(memberId, memberName),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              RouteNames.memberDetail.replaceAll(
                                ':id',
                                member['id'].toString(),
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
}

/// Tasks tab
class _TasksTab extends StatelessWidget {
  final String departmentId;
  final List<Map<String, dynamic>> tasks;

  const _TasksTab({required this.departmentId, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return tasks.isEmpty
        ? const Center(child: Text('No tasks in this department'))
        : ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: const Icon(Icons.task),
                title: Text(task['title'] ?? 'Task'),
                subtitle: Text(task['description'] ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    RouteNames.taskDetail.replaceAll(
                      ':id',
                      task['id'].toString(),
                    ),
                  );
                },
              );
            },
          );
  }
}

/// Reports tab
class _ReportsTab extends StatelessWidget {
  final String departmentId;

  const _ReportsTab({required this.departmentId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Department reports coming soon'));
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: AppDimensions.spacingSM),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
