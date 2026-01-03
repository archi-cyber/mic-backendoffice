import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/department_service.dart';
import '../../services/task_service.dart';
import '../../services/member_service.dart';
import '../../services/department_report_service.dart';
import '../../services/department_report_pdf_service.dart';
import '../../services/task_report_pdf_service.dart';
import '../../services/task_report_service.dart';

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
  List<Map<String, dynamic>> _reports = [];
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

      // Load reports (might fail if table doesn't exist, so catch separately)
      List<Map<String, dynamic>> departmentReports = [];
      try {
        departmentReports = await DepartmentReportService.getDepartmentReports(
          departmentId: widget.departmentId,
        );
      } catch (e) {
        // Reports table might not exist yet, that's okay
        debugPrint('Could not load reports: $e');
      }

      setState(() {
        _department = department;
        // Store full department_members data (includes role)
        _members = departmentMembers;
        _tasks = departmentTasks;
        _reports = departmentReports;
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
            _ReportsTab(
              departmentId: widget.departmentId,
              reports: _reports,
              onReportsUpdated: _loadDepartmentData,
            ),
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
        // Department Files section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department Files',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                if (_hasDocuments(department)) ...[
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
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No files uploaded',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
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
              onPressed: () => _openDocument(context, fileUrl, fileName),
              tooltip: 'Open file',
            )
          : null,
      onTap: fileUrl != null
          ? () => _openDocument(context, fileUrl, fileName)
          : null,
    );
  }

  Future<void> _openDocument(
    BuildContext context,
    String fileUrl,
    String fileName,
  ) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open file: $fileName'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
class _TasksTab extends StatefulWidget {
  final String departmentId;
  final List<Map<String, dynamic>> tasks;

  const _TasksTab({required this.departmentId, required this.tasks});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab> {
  Map<String, dynamic>? _completionStats;

  @override
  void initState() {
    super.initState();
    _loadCompletionStats();
  }

  Future<void> _loadCompletionStats() async {
    try {
      final stats = await TaskReportService.getDepartmentTaskCompletion(
        departmentId: widget.departmentId,
      );
      setState(() {
        _completionStats = stats;
      });
    } catch (e) {
      debugPrint('Error loading completion stats: $e');
    }
  }

  Future<void> _generateReport() async {
    // Show dialog to select report type and period
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _TaskReportOptionsDialog(),
    );

    if (result != null) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        final reportType = result['reportType'] as String;
        final year = result['year'] as int;
        final month = result['month'] as int?;

        String? filePath;
        if (reportType == 'monthly' && month != null) {
          filePath = await TaskReportPdfService.generateMonthlyReport(
            departmentId: widget.departmentId,
            year: year,
            month: month,
          );
        } else if (reportType == 'yearly') {
          filePath = await TaskReportPdfService.generateYearlyReport(
            departmentId: widget.departmentId,
            year: year,
          );
        }

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report generated successfully: $filePath'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating report: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Completion Stats Card
        if (_completionStats != null)
          Container(
            margin: const EdgeInsets.all(AppDimensions.paddingMD),
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Task Completion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(_completionStats!['completion_percentage'] as double? ?? 0.0).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            (_completionStats!['completion_percentage']
                                        as double? ??
                                    0.0) >=
                                80
                            ? AppColors.success
                            : (_completionStats!['completion_percentage']
                                          as double? ??
                                      0.0) >=
                                  50
                            ? AppColors.warning
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${_completionStats!['total_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Completed',
                      '${_completionStats!['completed_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'Pending',
                      '${_completionStats!['pending_tasks'] ?? 0}',
                    ),
                    _buildStatItem(
                      'In Progress',
                      '${_completionStats!['in_progress_tasks'] ?? 0}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Buttons row
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      RouteNames.tasks,
                      arguments: widget.departmentId,
                    );
                  },
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Manage Tasks'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, AppDimensions.buttonHeightMD),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generateReport,
                  icon: const Icon(Icons.description),
                  label: const Text('Generate Report'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, AppDimensions.buttonHeightMD),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tasks list
        Expanded(
          child: widget.tasks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text('No tasks in this department'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: widget.tasks.length,
                  itemBuilder: (context, index) {
                    final task = widget.tasks[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                        vertical: AppDimensions.spacingXS,
                      ),
                      child: ListTile(
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Reports tab
class _ReportsTab extends StatefulWidget {
  final String departmentId;
  final List<Map<String, dynamic>> reports;
  final VoidCallback onReportsUpdated;

  const _ReportsTab({
    required this.departmentId,
    required this.reports,
    required this.onReportsUpdated,
  });

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _reports = widget.reports;
  }

  @override
  void didUpdateWidget(_ReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) {
      _reports = widget.reports;
    }
  }

  Future<void> _loadReports() async {
    try {
      final reports = await DepartmentReportService.getDepartmentReports(
        departmentId: widget.departmentId,
      );
      setState(() {
        _reports = reports;
      });
      widget.onReportsUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createReport() async {
    final result = await Navigator.of(context).pushNamed(
      RouteNames.addDepartmentReport.replaceAll(':id', widget.departmentId),
    );
    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _generateSummaryReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating summary report...')),
      );
      await DepartmentReportPdfService.generateSummaryPdf(widget.departmentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Summary report generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateReportPdf(String reportId) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
      await DepartmentReportPdfService.generateReportPdf(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editReport(String reportId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editDepartmentReport.replaceAll(':id', reportId));
    if (result == true) {
      _loadReports();
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Are you sure you want to delete "${report['title']}"?'),
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
        await DepartmentReportService.deleteReport(report['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadReports();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Create Report button
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createReport,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Report'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      AppDimensions.buttonHeightMD,
                    ),
                  ),
                ),
              ),
              if (_reports.isNotEmpty) ...[
                const SizedBox(width: AppDimensions.spacingMD),
                IconButton(
                  icon: const Icon(Icons.summarize),
                  onPressed: _generateSummaryReport,
                  tooltip: 'Generate Summary Report',
                ),
              ],
            ],
          ),
        ),
        // Reports list
        Expanded(
          child: _reports.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Text('No reports yet'),
                      SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        'Create your first report to get started',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
                    itemCount: _reports.length,
                    itemBuilder: (context, index) {
                      final report = _reports[index];
                      return Card(
                        margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacingMD,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.description,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            report['title'] ?? 'Untitled Report',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Created: ${DateFormat('MMM d, yyyy').format(DateTime.parse(report['created_at']))}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf, size: 20),
                                    SizedBox(width: 8),
                                    Text('Generate PDF'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'pdf') {
                                await _generateReportPdf(report['id']);
                              } else if (value == 'edit') {
                                await _editReport(report['id']);
                              } else if (value == 'delete') {
                                _deleteReport(report);
                              }
                            },
                          ),
                          onTap: () => _editReport(report['id']),
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

class _TaskReportOptionsDialog extends StatefulWidget {
  const _TaskReportOptionsDialog();

  @override
  State<_TaskReportOptionsDialog> createState() =>
      _TaskReportOptionsDialogState();
}

class _TaskReportOptionsDialogState extends State<_TaskReportOptionsDialog> {
  String _reportType = 'monthly';
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Task Report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Report Type
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Report Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            RadioListTile<String>(
              title: const Text('Monthly Report'),
              value: 'monthly',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value ?? 'monthly';
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Yearly Report'),
              value: 'yearly',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value ?? 'yearly';
                  if (_reportType == 'yearly') {
                    _selectedMonth = null;
                  } else {
                    _selectedMonth = DateTime.now().month;
                  }
                });
              },
            ),
            const Divider(),
            // Year Selection
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Year'),
              subtitle: Text(_selectedYear.toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        _selectedYear--;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _selectedYear++;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Month Selection (only for monthly reports)
            if (_reportType == 'monthly')
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Month'),
                subtitle: Text(
                  _selectedMonth != null
                      ? DateFormat(
                          'MMMM',
                        ).format(DateTime(_selectedYear, _selectedMonth!))
                      : 'Select month',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(_selectedYear, _selectedMonth ?? 1),
                      firstDate: DateTime(_selectedYear, 1),
                      lastDate: DateTime(_selectedYear, 12),
                      helpText: 'Select Month',
                      initialDatePickerMode: DatePickerMode.year,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = picked.month;
                        _selectedYear = picked.year;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reportType == 'monthly' && _selectedMonth == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a month'),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            Navigator.of(context).pop({
              'reportType': _reportType,
              'year': _selectedYear,
              'month': _selectedMonth,
            });
          },
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
