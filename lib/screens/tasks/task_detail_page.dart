import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/tag_colors.dart';
import '../../core/routes/route_names.dart';
import '../../services/task_service.dart';
import '../../services/member_service.dart';
import '../../services/department_service.dart';
import '../../services/role_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Task detail page with assign and remind functionality
class TaskDetailPage extends StatefulWidget {
  final String taskId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const TaskDetailPage({super.key, required this.taskId, this.onClose});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  bool _canAssignMembers = false;

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  Future<void> _loadTaskData() async {
    setState(() => _isLoading = true);
    try {
      final task = await TaskService.getTaskById(widget.taskId);
      final assignments = await TaskService.getTaskAssignments(widget.taskId);

      // Check if user can assign members (admin or department leader)
      bool canAssign = false;
      final isAdmin = await RoleService.isCurrentUserAdmin();
      if (isAdmin) {
        canAssign = true;
      } else if (task['department_id'] != null) {
        // Check if user is a leader of the task's department
        canAssign = await DepartmentService.isDepartmentLeader(
          task['department_id'].toString(),
        );
      }

      if (!mounted) return;
      setState(() {
        _task = task;
        _assignments = assignments;
        _canAssignMembers = canAssign;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading task: $e')));
      }
    }
  }

  Future<void> _assignTask(String memberId) async {
    try {
      await TaskService.assignTask(taskId: widget.taskId, memberId: memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task assigned successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadTaskData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign task: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _remindTask() async {
    try {
      await TaskService.remindTask(taskId: widget.taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reminder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAssignDialog() async {
    try {
      // Get department ID from task
      final departmentId = _task?['department_id']?.toString();

      if (departmentId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task must be assigned to a department first'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Load department members
      final departmentMembers = await DepartmentService.getDepartmentMembers(
        departmentId,
      );

      if (!mounted) return;

      // Extract member data from department_members structure
      final members = departmentMembers
          .map((dm) => dm['members'] as Map<String, dynamic>?)
          .where((m) => m != null)
          .cast<Map<String, dynamic>>()
          .toList();

      if (members.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No members found in this department'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      final selectedMember = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _AssignMemberDialog(members: members),
      );

      if (selectedMember != null) {
        await _assignTask(selectedMember['id'].toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onClose != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                )
              : null,
          title: const Text('Task'),
        ),
        body: const Center(child: Text('Task not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
              )
            : null,
        title: Text(_task!['title'] ?? 'Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              final scope = DesktopShellScope.maybeOf(context);
              if (scope != null) {
                scope.pushDetail(RouteNames.editTask, widget.taskId);
              } else {
                Navigator.of(context)
                    .pushNamed(
                      RouteNames.editTask.replaceAll(':id', widget.taskId),
                    )
                    .then((result) {
                      if (result == true) _loadTaskData();
                    });
              }
            },
            tooltip: 'Edit Task',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _remindTask,
            tooltip: 'Send Reminder',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.delete, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete Task'),
                  ],
                ),
                onTap: () => _deleteTask(),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  static const double _kTaskDetailDesktopBreakpoint = 700;
  static const double _kTaskDetailDesktopMaxWidth = 900;

  Widget _detailLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kTaskDetailDesktopBreakpoint;
    final theme = Theme.of(context);
    final status = _task!['status']?.toString() ?? 'pending';
    final priority = _task!['priority']?.toString() ?? 'medium';
    final description = (_task!['description']?.toString())?.trim() ?? '';
    final departmentName = _getDepartmentName();
    final projectTitle = _task!['projects'] is Map
        ? (_task!['projects'] as Map)['title']?.toString()
        : null;
    final taskTags = _task!['task_tags'];
    final hasTags = taskTags is List && taskTags.isNotEmpty;
    final dueDateStr = _task!['due_date'];

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            _task!['title'] ?? 'Task',
            style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ) ??
                theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ) ??
                TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: AppDimensions.spacingLG),
          // Details card: all fields in a consistent layout
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: isDesktop ? _buildDetailsGrid(theme, description, status, priority, departmentName, projectTitle, hasTags, taskTags, dueDateStr) : _buildDetailsColumn(theme, description, status, priority, departmentName, projectTitle, hasTags, taskTags, dueDateStr),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          // Assignments
          Text('Assigned To', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppDimensions.spacingSM),
          _assignments.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
                    child: Center(
                      child: Text(
                        'No assignments yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = _assignments[index];
                    final member =
                        assignment['members'] as Map<String, dynamic>?;
                    final memberName = member != null
                        ? '${member['first_name']} ${member['last_name']}'
                        : 'Member';
                    final assignmentStatus =
                        assignment['status']?.toString() ?? 'pending';
                    final memberId = assignment['member_id']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingXS,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            member?['first_name']?[0]
                                    ?.toString()
                                    .toUpperCase() ??
                                'M',
                          ),
                        ),
                        title: Text(memberName),
                        subtitle: Text(member?['email']?.toString() ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (newStatus) async {
                                final messenger = ScaffoldMessenger.maybeOf(context);
                                try {
                                  await TaskService.updateAssignmentStatus(
                                    taskId: widget.taskId,
                                    memberId: memberId,
                                    status: newStatus,
                                  );
                                  if (mounted && messenger != null) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Status updated'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _loadTaskData();
                                  }
                                } catch (e) {
                                  if (mounted && messenger != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
                                const PopupMenuItem(
                                  value: 'in_progress',
                                  child: Text('In Progress'),
                                ),
                                const PopupMenuItem(
                                  value: 'completed',
                                  child: Text('Completed'),
                                ),
                                const PopupMenuItem(
                                  value: 'cancelled',
                                  child: Text('Cancelled'),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    assignmentStatus,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  assignmentStatus.replaceAll('_', ' '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(assignmentStatus),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.message, size: 18),
                              onPressed: () => _showReminderDialog(
                                member: member,
                                memberId: memberId,
                                memberName: memberName,
                              ),
                              tooltip: 'Send Reminder',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  _removeAssignment(memberId, memberName),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            RouteNames.memberDetail.replaceAll(
                              ':id',
                              member?['id']?.toString() ?? '',
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
          const SizedBox(height: AppDimensions.spacingXL),
          // Action buttons - only show if user can assign members
          if (_canAssignMembers)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAssignDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Assign to Member'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppDimensions.buttonHeightLG,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _kTaskDetailDesktopMaxWidth,
          ),
          child: content,
        ),
      );
    }
    return content;
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
          'Are you sure you want to delete this task? This action cannot be undone.',
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
        await TaskService.deleteTask(widget.taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting task: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeAssignment(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text('Remove $memberName from this task?'),
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
        await TaskService.removeAssignment(
          taskId: widget.taskId,
          memberId: memberId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment removed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTaskData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing assignment: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return AppColors.primary;
      case 'low':
        return AppColors.textSecondary;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDepartmentName() {
    final department = _task!['departments'];
    if (department is Map<String, dynamic>) {
      return department['name']?.toString() ?? 'Unknown Department';
    }
    final departmentId = _task!['department_id']?.toString();
    return departmentId ?? '—';
  }

  Widget _buildDetailsColumn(
    ThemeData theme,
    String description,
    String status,
    String priority,
    String departmentName,
    String? projectTitle,
    bool hasTags,
    dynamic taskTags,
    dynamic dueDateStr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailLabel(context, 'Description'),
        const SizedBox(height: 4),
        Text(
          description.isEmpty ? '—' : description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Status'),
        const SizedBox(height: 4),
        _statusPriorityChip(status, true),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Priority'),
        const SizedBox(height: 4),
        _statusPriorityChip(priority, false),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Department'),
        const SizedBox(height: 4),
        Text(departmentName, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Project'),
        const SizedBox(height: 4),
        Text(projectTitle ?? '—', style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Due date'),
        const SizedBox(height: 4),
        Text(
          dueDateStr != null ? _formatDate(DateTime.parse(dueDateStr)) : '—',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Tags'),
        const SizedBox(height: 4),
        hasTags && taskTags is List
            ? Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _buildTagChips(taskTags),
              )
            : Text('—', style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildDetailsGrid(
    ThemeData theme,
    String description,
    String status,
    String priority,
    String departmentName,
    String? projectTitle,
    bool hasTags,
    dynamic taskTags,
    dynamic dueDateStr,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailLabel(context, 'Description'),
        const SizedBox(height: 4),
        Text(
          description.isEmpty ? '—' : description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimensions.spacingLG),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: AppDimensions.spacingLG,
              runSpacing: AppDimensions.spacingMD,
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel(context, 'Status'),
                      const SizedBox(height: 4),
                      _statusPriorityChip(status, true),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel(context, 'Priority'),
                      const SizedBox(height: 4),
                      _statusPriorityChip(priority, false),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel(context, 'Department'),
                      const SizedBox(height: 4),
                      Text(departmentName, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel(context, 'Project'),
                      const SizedBox(height: 4),
                      Text(projectTitle ?? '—', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailLabel(context, 'Due date'),
                      const SizedBox(height: 4),
                      Text(
                        dueDateStr != null
                            ? _formatDate(DateTime.parse(dueDateStr))
                            : '—',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, 'Tags'),
        const SizedBox(height: 4),
        hasTags && taskTags is List
            ? Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _buildTagChips(taskTags),
              )
            : Text('—', style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _statusPriorityChip(String value, bool isStatus) {
    final color = isStatus ? _getStatusColor(value) : _getPriorityColor(value);
    final text = (value.replaceAll('_', ' ')).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSM,
        vertical: AppDimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<Widget> _buildTagChips(List taskTags) {
    return taskTags.map<Widget>((e) {
      final tag = e is Map ? e['tags'] : null;
      final name = tag is Map ? tag['name']?.toString() : null;
      if (name == null) return const SizedBox.shrink();
      final color = TagColors.colorFromHex(
          tag is Map ? tag['color']?.toString() : null);
      return Chip(
        label: Text(name, style: const TextStyle(fontSize: 12)),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: color.withValues(alpha: 0.2),
        side: BorderSide(color: color),
      );
    }).toList();
  }

  Future<void> _showReminderDialog({
    required Map<String, dynamic>? member,
    required String memberId,
    required String memberName,
  }) async {
    // Get assigned member's phone - try from member object first
    String? assignedMemberPhone = member?['phone']?.toString();

    // If phone not in member object, try to fetch it directly
    if ((assignedMemberPhone == null || assignedMemberPhone.isEmpty) &&
        memberId.isNotEmpty) {
      try {
        final memberProfile = await MemberService.getMemberById(memberId);
        assignedMemberPhone = memberProfile['phone']?.toString();
      } catch (e) {
        // Continue with phone from member object or null
      }
    }

    // Show dialog to select platform and confirm phone number
    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ReminderDialog(
        assignedMemberPhone: assignedMemberPhone,
        memberName: memberName,
        taskTitle: _task!['title']?.toString() ?? 'Task',
      ),
    );

    if (result != null) {
      final receiverPhone = result['receiver'];
      final platform = result['platform'];

      if (receiverPhone != null &&
          receiverPhone.isNotEmpty &&
          platform != null) {
        await _sendReminder(
          receiverPhone: receiverPhone,
          platform: platform,
          taskTitle: _task!['title']?.toString() ?? 'Task',
          taskDescription: _task!['description']?.toString() ?? '',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number is required'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _sendReminder({
    required String receiverPhone,
    required String platform,
    required String taskTitle,
    required String taskDescription,
  }) async {
    try {
      // Format phone numbers (remove any non-digit characters except +)
      String formatPhone(String phone) {
        if (phone.isEmpty) {
          throw Exception('Invalid phone number format');
        }

        // Extract all digits from the phone number (this preserves ALL digits)
        final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');

        // Ensure we have digits
        if (digitsOnly.isEmpty) {
          throw Exception('Invalid phone number format');
        }

        // Always return with + prefix for international format
        return '+$digitsOnly';
      }

      final formattedReceiver = formatPhone(receiverPhone);
      final message =
          'Reminder: $taskTitle\n\n${taskDescription.isNotEmpty ? taskDescription : "Please check your assigned task."}';

      Uri uri;
      if (platform == 'whatsapp') {
        // WhatsApp URL format: https://wa.me/PHONENUMBER?text=MESSAGE
        // Remove + from phone number for WhatsApp URL
        final phoneForUrl = formattedReceiver.replaceAll('+', '');
        uri = Uri.parse(
          'https://wa.me/$phoneForUrl?text=${Uri.encodeComponent(message)}',
        );
      } else {
        // Telegram URL format: https://t.me/share/url?url=&text=
        // For Telegram, we'll use the share URL format as direct messaging requires username
        uri = Uri.parse(
          'https://t.me/share/url?url=&text=${Uri.encodeComponent(message)}',
        );
      }

      // Try to launch the URL
      // Note: canLaunchUrl can be unreliable, so we'll try to launch anyway
      bool canLaunch = false;
      try {
        canLaunch = await canLaunchUrl(uri);
      } catch (e) {
        // If canLaunchUrl fails, we'll still try to launch
        canLaunch = true;
      }

      if (canLaunch) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening $platform...'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          // If launchUrl fails, try with platformDefault mode
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening $platform...'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e2) {
            throw Exception(
              'Could not launch $platform. Please make sure $platform is installed on your device.',
            );
          }
        }
      } else {
        // If canLaunchUrl returns false, still try to launch
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening $platform...'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (e) {
          throw Exception(
            'Could not launch $platform. Please make sure $platform is installed on your device.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reminder: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _ReminderDialog extends StatefulWidget {
  final String? assignedMemberPhone;
  final String memberName;
  final String taskTitle;

  const _ReminderDialog({
    required this.assignedMemberPhone,
    required this.memberName,
    required this.taskTitle,
  });

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _receiverController = TextEditingController();
  String _selectedPlatform = 'whatsapp';

  @override
  void initState() {
    super.initState();
    // Auto-fill assigned member's phone number
    _receiverController.text = widget.assignedMemberPhone ?? '';
  }

  @override
  void dispose() {
    _receiverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task: ${widget.taskTitle}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'To: ${widget.memberName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingLG),
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(
                labelText: 'Platform',
                prefixIcon: Icon(Icons.message),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      Icon(Icons.chat, color: Colors.green),
                      SizedBox(width: 8),
                      Text('WhatsApp'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'telegram',
                  child: Row(
                    children: [
                      Icon(Icons.send, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Telegram'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPlatform = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _receiverController,
              decoration: InputDecoration(
                labelText: '${widget.memberName}\'s Phone Number *',
                prefixIcon: const Icon(Icons.phone),
                helperText: 'The recipient\'s phone number',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_receiverController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'receiver': _receiverController.text.trim(),
                'platform': _selectedPlatform,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter the phone number'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

/// Dialog for assigning task to a department member with search
class _AssignMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;

  const _AssignMemberDialog({required this.members});

  @override
  State<_AssignMemberDialog> createState() => _AssignMemberDialogState();
}

class _AssignMemberDialogState extends State<_AssignMemberDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _filteredMembers = widget.members;
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = widget.members;
      } else {
        _filteredMembers = widget.members.where((member) {
          final firstName = (member['first_name'] ?? '')
              .toString()
              .toLowerCase();
          final lastName = (member['last_name'] ?? '').toString().toLowerCase();
          final email = (member['email'] ?? '').toString().toLowerCase();
          final phone = (member['phone'] ?? '').toString().toLowerCase();

          return firstName.contains(query) ||
              lastName.contains(query) ||
              email.contains(query) ||
              phone.contains(query) ||
              '$firstName $lastName'.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                children: [
                  const Text(
                    'Assign Task to Member',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
            // Members list
            Expanded(
              child: _filteredMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppDimensions.spacingSM),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No members available'
                                : 'No members found',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final memberName =
                            '${member['first_name']} ${member['last_name']}';
                        final memberEmail = member['email']?.toString() ?? '';
                        final memberPhone = member['phone']?.toString() ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member['first_name']?[0]
                                      ?.toString()
                                      .toUpperCase() ??
                                  'M',
                            ),
                          ),
                          title: Text(memberName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (memberEmail.isNotEmpty)
                                Text(
                                  memberEmail,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (memberPhone.isNotEmpty)
                                Text(
                                  memberPhone,
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          onTap: () => Navigator.pop(context, member),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredMembers.length} member${_filteredMembers.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
