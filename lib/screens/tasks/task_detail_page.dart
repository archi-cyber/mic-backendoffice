import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/tag_colors.dart';
import '../../core/routes/route_names.dart';
import '../../services/task_service.dart';
import '../../services/task_penalty_service.dart';
import '../../services/member_service.dart';
import '../../services/department_service.dart';
import '../../services/role_service.dart';
import 'edit_task_page.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/phone_number_utils.dart';
import '../../widgets/phone_number_field.dart';

/// Task detail page with assign and remind functionality
class TaskDetailPage extends StatefulWidget {
  final String taskId;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  TaskDetailPage({super.key, required this.taskId, this.onClose});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading task: $e'))),
        );
      }
    }
  }

  Future<void> _assignTask(String memberId) async {
    try {
      await TaskService.assignTask(taskId: widget.taskId, memberId: memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Task assigned successfully')),
            backgroundColor: AppColors.success,
          ),
        );
        _loadTaskData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Failed to assign task: $e')),
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
          SnackBar(
            content: Text(context.tr('Reminder sent successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Failed to send reminder: $e')),
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
            SnackBar(
              content: Text(
                context.tr('Task must be assigned to a department first'),
              ),
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
      final membersWithPenalties =
          await TaskPenaltyService.annotateMembersWithPenalties(members);
      if (!mounted) return;

      if (membersWithPenalties.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('No members found in this department')),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final selectedMember = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            _AssignMemberDialog(members: membersWithPenalties),
      );

      if (selectedMember != null) {
        await _assignTask(selectedMember['id'].toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading members: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditTask() async {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kTaskDetailDesktopBreakpoint &&
        widget.onClose != null;

    if (isDesktop) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            clipBehavior: Clip.antiAlias,
            insetPadding: EdgeInsets.all(AppDimensions.paddingLG),
            child: SizedBox(
              width: 1120,
              height: MediaQuery.sizeOf(dialogContext).height * 0.9,
              child: EditTaskPage(
                taskId: widget.taskId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true && mounted) _loadTaskData();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editTask.replaceAll(':id', widget.taskId));
    if (result == true && mounted) _loadTaskData();
  }

  bool _isCompactTaskDetail(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _kTaskDetailDesktopBreakpoint;

  static const double _kTaskDetailDesktopBreakpoint = 700;
  static const double _kTaskDetailDesktopMaxWidth = 900;

  List<Widget> _buildTaskAppBarActions({required bool compact}) {
    if (compact) {
      return [
        PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                _openEditTask();
              case 'remind':
                _remindTask();
              case 'archive':
                _archiveTask();
              case 'delete':
                _deleteTask();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text(context.tr('Edit task')),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: 'remind',
              child: ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text(context.tr('Send reminder')),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: 'archive',
              child: ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text(context.tr('Archive task')),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(
                  context.tr('Delete task'),
                  style: TextStyle(color: AppColors.error),
                ),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ];
    }

    return [
      IconButton(
        icon: Icon(Icons.edit),
        onPressed: _openEditTask,
        tooltip: context.tr('Edit Task'),
      ),
      IconButton(
        icon: Icon(Icons.notifications_outlined),
        onPressed: _remindTask,
        tooltip: context.tr('Send Reminder'),
      ),
      PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            onTap: _archiveTask,
            child: Row(
              children: [
                Icon(Icons.archive_outlined),
                SizedBox(width: 8),
                Text(context.tr('Archive Task')),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: _deleteTask,
            child: Row(
              children: [
                Icon(Icons.delete, color: AppColors.error),
                SizedBox(width: 8),
                Text(context.tr('Delete Task')),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onClose != null
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                )
              : null,
          title: Text(context.tr('Task')),
        ),
        body: Center(child: Text(context.tr('Task not found'))),
      );
    }

    final compact = _isCompactTaskDetail(context);
    final isDesktopShell = !compact && widget.onClose != null;
    final isMobile =
        MediaQuery.sizeOf(context).width < _kTaskDetailDesktopBreakpoint;

    return Scaffold(
      backgroundColor: isMobile ? context.mic.background : null,
      appBar: isDesktopShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: widget.onClose,
                    )
                  : null,
              title: Text(
                compact
                    ? context.tr('Task details')
                    : (isMobile
                          ? context.tr('Task')
                          : (_task!['title']?.toString() ?? context.tr('Task'))),
              ),
              actions: _buildTaskAppBarActions(compact: compact),
            ),
      body: _buildBody(context),
    );
  }

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
    if (!isDesktop) {
      return _buildMobileBody(context);
    }

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

    return _buildDesktopBody(
      theme: theme,
      status: status,
      priority: priority,
      description: description,
      departmentName: departmentName,
      projectTitle: projectTitle,
      hasTags: hasTags,
      taskTags: taskTags,
      dueDateStr: dueDateStr,
    );
  }

  Widget _buildDesktopBody({
    required ThemeData theme,
    required String status,
    required String priority,
    required String description,
    required String departmentName,
    required String? projectTitle,
    required bool hasTags,
    required dynamic taskTags,
    required dynamic dueDateStr,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kTaskDetailDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.45),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getStatusColor(status).withValues(alpha: 0.12),
                      theme.colorScheme.surface,
                      theme.colorScheme.surface,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLG),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _task!['title']?.toString() ?? context.tr('Task'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                          SizedBox(width: AppDimensions.spacingMD),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _buildTaskAppBarActions(compact: false),
                          ),
                        ],
                      ),
                      SizedBox(height: AppDimensions.spacingMD),
                      Wrap(
                        spacing: AppDimensions.spacingSM,
                        runSpacing: AppDimensions.spacingSM,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusPriorityChip(status, true),
                          _statusPriorityChip(priority, false),
                          if (dueDateStr != null)
                            _DesktopInfoChip(
                              icon: Icons.event_outlined,
                              label: context.tr(
                                'Due {date}',
                                {
                                  'date': _formatDate(
                                    DateTime.parse(dueDateStr.toString()),
                                  ),
                                },
                              ),
                            ),
                            _DesktopInfoChip(
                              icon: Icons.people_outline,
                              label:
                                  '${_assignments.length} ${_assignments.length == 1 ? context.tr('assignee') : context.tr('assignees')}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DesktopPanel(
                          title: context.tr('Task information'),
                          icon: Icons.info_outline,
                          child: _buildDetailsGrid(
                            theme,
                            description,
                            status,
                            priority,
                            departmentName,
                            projectTitle,
                            hasTags,
                            taskTags,
                            dueDateStr,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    flex: 2,
                    child: _DesktopPanel(
                      title: context.tr('Assigned to'),
                      icon: Icons.people_outline,
                      trailing: _canAssignMembers
                          ? TextButton.icon(
                              onPressed: _showAssignDialog,
                              icon: Icon(Icons.person_add_outlined),
                              label: Text(context.tr('Assign')),
                            )
                          : null,
                      child: _buildDesktopAssignmentsList(theme),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAssignmentsList(ThemeData theme) {
    if (_assignments.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingLG),
        child: Center(
          child: Text(
            context.tr('No assignments yet'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _assignments.map((assignment) {
        final member = assignment['members'] as Map<String, dynamic>?;
        final memberName = member != null
            ? '${member['first_name']} ${member['last_name']}'
            : context.tr('Member');
        final assignmentStatus = assignment['status']?.toString() ?? 'pending';
        final memberId = assignment['member_id']?.toString() ?? '';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(
              assignmentStatus,
            ).withValues(alpha: 0.12),
            child: Text(
              member?['first_name']?[0]?.toString().toUpperCase() ?? 'M',
              style: TextStyle(
                color: _getStatusColor(assignmentStatus),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(memberName),
          subtitle: Text(
            assignmentStatus.replaceAll('_', ' '),
            style: TextStyle(color: _getStatusColor(assignmentStatus)),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (action) async {
              if (action.startsWith('status:')) {
                await _handleMobileAssignmentAction(
                  action: action,
                  member: member,
                  memberId: memberId,
                  memberName: memberName,
                );
              } else if (action == 'remind') {
                await _showReminderDialog(
                  member: member,
                  memberId: memberId,
                  memberName: memberName,
                );
              } else if (action == 'payment') {
                await _showRecordPaymentDialog(memberId, memberName);
              } else if (action == 'remove') {
                await _removeAssignment(memberId, memberName);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'status:pending',
                child: Text(context.tr('Pending')),
              ),
              PopupMenuItem(
                value: 'status:in_progress',
                child: Text(context.tr('In progress')),
              ),
              PopupMenuItem(
                value: 'status:completed',
                child: Text(context.tr('Completed')),
              ),
              PopupMenuItem(
                value: 'status:cancelled',
                child: Text(context.tr('Cancelled')),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'remind',
                child: Text(context.tr('Send reminder')),
              ),
              PopupMenuItem(
                value: 'payment',
                child: Text(context.tr('Record penalty payment')),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(context.tr('Remove'), style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
          onTap: member?['id'] == null
              ? null
              : () {
                  Navigator.of(context).pushNamed(
                    RouteNames.memberDetail.replaceAll(
                      ':id',
                      member!['id'].toString(),
                    ),
                  );
                },
        );
      }).toList(),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
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

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacingMD,
              AppDimensions.spacingSM,
              AppDimensions.spacingMD,
              AppDimensions.spacingSM,
            ),
            child: _buildMobileTaskHeader(
              theme: theme,
              status: status,
              priority: priority,
              dueDateStr: dueDateStr,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingMD),
            child: Container(
              decoration: BoxDecoration(
                color: context.mic.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                border: Border.all(color: context.mic.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terracotta.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: context.mic.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: context.mic.surfaceTint.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                dividerColor: Colors.transparent,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: context.tr('Details')),
                  Tab(text: context.tr('Assignees (${_assignments.length})')),
                ],
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Expanded(
            child: TabBarView(
              children: [
                _buildMobileDetailsTab(
                  theme: theme,
                  description: description,
                  departmentName: departmentName,
                  projectTitle: projectTitle,
                  hasTags: hasTags,
                  taskTags: taskTags,
                ),
                _buildMobileAssigneesTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTaskHeader({
    required ThemeData theme,
    required String status,
    required String priority,
    required dynamic dueDateStr,
  }) {
    final title = _task!['title']?.toString() ?? context.tr('Task');
    final statusColor = _getStatusColor(status);
    String? dueLabel;
    Color? dueColor;
    bool isOverdue = false;

    if (dueDateStr != null) {
      try {
        final dueDate = DateTime.parse(dueDateStr.toString());
        dueLabel = DateFormat('EEE, MMM d').format(dueDate);
        if (dueDate.isBefore(DateTime.now()) && status != 'completed') {
          dueColor = AppColors.error;
          isOverdue = true;
        }
      } catch (_) {
        dueLabel = dueDateStr.toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.22),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.task_alt,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: context.mic.appBarForeground,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _statusPriorityChip(status, true),
                _statusPriorityChip(priority, false),
                if (dueLabel != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingSM,
                      vertical: AppDimensions.paddingXS,
                    ),
                    decoration: BoxDecoration(
                      color: (dueColor ?? AppColors.info)
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSM),
                      border: Border.all(
                        color: (dueColor ?? AppColors.info)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.event_outlined,
                          size: 15,
                          color: dueColor ?? AppColors.info,
                        ),
                        SizedBox(width: 4),
                        Text(
                          dueLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: dueColor ?? AppColors.info,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingSM,
                    vertical: AppDimensions.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 15,
                        color: AppColors.secondaryDark,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${_assignments.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondaryDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        SizedBox(width: AppDimensions.spacingSM),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.mic.appBarForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDetailsTab({
    required ThemeData theme,
    required String description,
    required String departmentName,
    required String? projectTitle,
    required bool hasTags,
    required dynamic taskTags,
  }) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
        AppDimensions.spacingMD,
        AppDimensions.spacingLG,
      ),
      children: [
        Container(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          decoration: BoxDecoration(
            color: context.mic.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: context.mic.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.sage.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileSectionHeader(
                title: context.tr('Description'),
                icon: Icons.notes_outlined,
                color: AppColors.secondary,
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Text(
                description.isEmpty
                    ? context.tr('No description provided.')
                    : description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: description.isEmpty
                      ? context.mic.textSecondary
                      : context.mic.textPrimary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        _buildMobileInfoCard(
          theme: theme,
          accentColor: AppColors.primary,
          children: [
            _buildMobileMetaRow(
              icon: Icons.apartment_outlined,
              label: context.tr('Department'),
              value: departmentName,
              iconColor: AppColors.primary,
            ),
            _mobileMetaDivider(theme),
            _buildMobileMetaRow(
              icon: Icons.folder_outlined,
              label: context.tr('Project'),
              value: projectTitle ?? '—',
              iconColor: AppColors.accent,
            ),
            if (hasTags && taskTags is List) ...[
              _mobileMetaDivider(theme),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.spacingMD,
                  14,
                  AppDimensions.spacingMD,
                  14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMobileSectionHeader(
                      title: context.tr('Tags'),
                      icon: Icons.sell_outlined,
                      color: AppColors.terracotta,
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _buildTagChips(taskTags),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMobileInfoCard({
    required ThemeData theme,
    required List<Widget> children,
    Color accentColor = AppColors.primary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.spacingSM,
            ),
            color: accentColor.withValues(alpha: 0.08),
            child: Text(
              context.tr('Task information'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.mic.appBarForeground,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _mobileMetaDivider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 58,
      color: context.mic.border.withValues(alpha: 0.7),
    );
  }

  Widget _buildMobileMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMD,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.mic.appBarForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAssigneesTab(ThemeData theme) {
    return Column(
      children: [
        if (_canAssignMembers)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacingMD,
              AppDimensions.spacingMD,
              AppDimensions.spacingMD,
              0,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAssignDialog,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: Text(context.tr('Assign member')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: _assignments.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingLG),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.mic.surfaceTint.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people_outline,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          context.tr('No one assigned yet'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.mic.appBarForeground,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          context.tr(
                            'Assign members from the department to this task.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppDimensions.spacingMD),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _assignments.length - 1
                            ? AppDimensions.spacingSM
                            : 0,
                      ),
                      child: _buildMobileAssignmentTile(_assignments[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMobileAssignmentTile(Map<String, dynamic> assignment) {
    final member = assignment['members'] as Map<String, dynamic>?;
    final memberName = member != null
        ? '${member['first_name']} ${member['last_name']}'
        : context.tr('Member');
    final assignmentStatus = assignment['status']?.toString() ?? 'pending';
    final memberId = assignment['member_id']?.toString() ?? '';
    final statusColor = _getStatusColor(assignmentStatus);
    final initials = memberName.trim().isNotEmpty
        ? memberName.trim()[0].toUpperCase()
        : 'M';

    return Container(
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: InkWell(
          onTap: member?['id'] == null
              ? null
              : () {
                  Navigator.of(context).pushNamed(
                    RouteNames.memberDetail.replaceAll(
                      ':id',
                      member!['id'].toString(),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withValues(alpha: 0.18),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.mic.appBarForeground,
                        ),
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          assignmentStatus.replaceAll('_', ' ').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if ((member?['email']?.toString() ?? '').isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          member!['email'].toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (action) => _handleMobileAssignmentAction(
                    action: action,
                    member: member,
                    memberId: memberId,
                    memberName: memberName,
                  ),
                  itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      context.tr('Update status'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.mic.textTertiary,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status:pending',
                    child: Text(context.tr('Pending')),
                  ),
                  PopupMenuItem(
                    value: 'status:in_progress',
                    child: Text(context.tr('In progress')),
                  ),
                  PopupMenuItem(
                    value: 'status:completed',
                    child: Text(context.tr('Completed')),
                  ),
                  PopupMenuItem(
                    value: 'status:cancelled',
                    child: Text(context.tr('Cancelled')),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'remind',
                    child: Text(context.tr('Send reminder')),
                  ),
                  PopupMenuItem(
                    value: 'payment',
                    child: Text(context.tr('Record penalty payment')),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      context.tr('Remove'),
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _handleMobileAssignmentAction({
    required String action,
    required Map<String, dynamic>? member,
    required String memberId,
    required String memberName,
  }) async {
    if (action.startsWith('status:')) {
      final newStatus = action.split(':').last;
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await TaskService.updateAssignmentStatus(
          taskId: widget.taskId,
          memberId: memberId,
          status: newStatus,
        );
        if (mounted && messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(context.tr('Status updated')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTaskData();
        }
      } catch (e) {
        if (mounted && messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(context.tr('Error: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    if (action == 'remind') {
      await _showReminderDialog(
        member: member,
        memberId: memberId,
        memberName: memberName,
      );
      return;
    }

    if (action == 'payment') {
      await _showRecordPaymentDialog(memberId, memberName);
      return;
    }

    if (action == 'remove') {
      await _removeAssignment(memberId, memberName);
    }
  }

  Future<void> _showRecordPaymentDialog(
    String memberId,
    String memberName,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Record payment for $memberName')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Amount paid'),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: context.tr('Note (optional)'),
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Enter a valid amount')),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, amount);
            },
            child: Text(context.tr('Save payment')),
          ),
        ],
      ),
    );

    try {
      if (result == null) return;
      await TaskPenaltyService.recordPayment(
        memberId: memberId,
        amount: result,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Payment recorded')),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error recording payment: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      amountController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _archiveTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Archive Task')),
        content: Text(
          context.tr(
            'Archive this task? It will stop accumulating new penalties.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Archive')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TaskService.archiveTask(widget.taskId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Task archived')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTaskData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error archiving task: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Task')),
        content: Text(
          context.tr(
            'Are you sure you want to delete this task? This action cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await TaskService.deleteTask(widget.taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Task deleted successfully')),
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
              content: Text(context.tr('Error deleting task: $e')),
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
        title: Text(context.tr('Remove Assignment')),
        content: Text(context.tr('Remove $memberName from this task?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Remove')),
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
            SnackBar(
              content: Text(context.tr('Assignment removed successfully')),
              backgroundColor: AppColors.success,
            ),
          );
          _loadTaskData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error removing assignment: $e')),
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
        return context.mic.textSecondary;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.accent;
      case 'medium':
        return AppColors.primary;
      case 'low':
        return context.mic.textSecondary;
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
      return department['name']?.toString() ?? context.tr('Unknown Department');
    }
    final departmentId = _task!['department_id']?.toString();
    return departmentId ?? '—';
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLabel(context, context.tr('Description')),
              SizedBox(height: AppDimensions.spacingXS),
              Text(
                description.isEmpty
                    ? context.tr('No description provided.')
                    : description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        SizedBox(height: AppDimensions.spacingLG),
        Wrap(
          spacing: AppDimensions.spacingMD,
          runSpacing: AppDimensions.spacingMD,
          children: [
            _DesktopDetailTile(
              icon: Icons.check_circle_outline,
              label: context.tr('Status'),
              child: _statusPriorityChip(status, true),
            ),
            _DesktopDetailTile(
              icon: Icons.flag_outlined,
              label: context.tr('Priority'),
              child: _statusPriorityChip(priority, false),
            ),
            _DesktopDetailTile(
              icon: Icons.group_work_outlined,
              label: context.tr('Department'),
              value: departmentName,
            ),
            _DesktopDetailTile(
              icon: Icons.folder_outlined,
              label: context.tr('Project'),
              value: projectTitle ?? '—',
            ),
            _DesktopDetailTile(
              icon: Icons.event_outlined,
              label: context.tr('Due date'),
              value: dueDateStr != null
                  ? _formatDate(DateTime.parse(dueDateStr))
                  : '—',
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        _detailLabel(context, context.tr('Tags')),
        SizedBox(height: 4),
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
      padding: EdgeInsets.symmetric(
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
      if (name == null) return SizedBox.shrink();
      final color = TagColors.colorFromHex(
        tag is Map ? tag['color']?.toString() : null,
      );
      return Chip(
        label: Text(name, style: TextStyle(fontSize: 12)),
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
        taskTitle: _task!['title']?.toString() ?? context.tr('Task'),
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
          taskTitle: _task!['title']?.toString() ?? context.tr('Task'),
          taskDescription: _task!['description']?.toString() ?? '',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Phone number is required')),
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
      final formattedReceiver = PhoneNumberUtils.normalize(receiverPhone);
      if (formattedReceiver == null) {
        throw Exception('Invalid phone number format');
      }
      final message =
          'Reminder: $taskTitle\n\n${taskDescription.isNotEmpty ? taskDescription : context.tr('Please check your assigned task.')}';

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
                content: Text(context.tr('Opening $platform...')),
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
                  content: Text(context.tr('Opening $platform...')),
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
                content: Text(context.tr('Opening $platform...')),
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
            content: Text(
              context.tr('Failed to send reminder: ${e.toString()}'),
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _DesktopPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  _DesktopPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            child,
          ],
        ),
      ),
    );
  }
}

class _DesktopInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  _DesktopInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSM,
        vertical: AppDimensions.spacingXS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.mic.textSecondary),
          SizedBox(width: AppDimensions.spacingXS),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.mic.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  _DesktopDetailTile({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 205,
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              SizedBox(width: AppDimensions.spacingXS),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.mic.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingSM),
          child ??
              Text(
                value ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}

class _ReminderDialog extends StatefulWidget {
  final String? assignedMemberPhone;
  final String memberName;
  final String taskTitle;

  _ReminderDialog({
    required this.assignedMemberPhone,
    required this.memberName,
    required this.taskTitle,
  });

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _phoneInput = PhoneNumberInputController();
  final _formKey = GlobalKey<FormState>();
  String _selectedPlatform = 'whatsapp';

  @override
  void initState() {
    super.initState();
    _phoneInput.setFromStored(widget.assignedMemberPhone);
  }

  @override
  void dispose() {
    _phoneInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Send Reminder')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              context.tr('Task: {title}', {'title': widget.taskTitle}),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              context.tr('To: {name}', {'name': widget.memberName}),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: AppDimensions.spacingLG),
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: InputDecoration(
                labelText: context.tr('Platform'),
                prefixIcon: Icon(Icons.message),
              ),
              items: [
                DropdownMenuItem(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      Icon(Icons.chat, color: Colors.green),
                      SizedBox(width: 8),
                      Text(context.tr('WhatsApp')),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'telegram',
                  child: Row(
                    children: [
                      Icon(Icons.send, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(context.tr('Telegram')),
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
            SizedBox(height: AppDimensions.spacingMD),
            PhoneNumberField(
              controller: _phoneInput,
              optional: false,
              decoration: InputDecoration(
                labelText:
                    context.tr('${widget.memberName}\'s Phone Number *'),
                helperText: context.tr('The recipient\'s phone number'),
              ),
            ),
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final phone = _phoneInput.storedValue;
            if (phone == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('Please enter the phone number')),
                  backgroundColor: AppColors.error,
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'receiver': phone,
              'platform': _selectedPlatform,
            });
          },
          child: Text(context.tr('Send')),
        ),
      ],
    );
  }
}

/// Dialog for assigning task to a department member with search
class _AssignMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;

  _AssignMemberDialog({required this.members});

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
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                children: [
                  Text(
                    context.tr('Assign Task to Member'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Search bar
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('Search members...'),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
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
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: context.mic.textSecondary,
                          ),
                          SizedBox(height: AppDimensions.spacingSM),
                          Text(
                            _searchController.text.isEmpty
                                ? context.tr('No members available')
                                : context.tr('No members found'),
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
                        final isBlocked =
                            member['is_assignment_blocked'] == true;
                        final balance = member['penalty_balance'] as int? ?? 0;

                        return ListTile(
                          enabled: !isBlocked,
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
                                  style: TextStyle(fontSize: 12),
                                ),
                              if (memberPhone.isNotEmpty)
                                Text(
                                  memberPhone,
                                  style: TextStyle(fontSize: 12),
                                ),
                              if (isBlocked)
                                Text(
                                  context.tr(
                                    'Blocked: {balance}frs unpaid penalties',
                                    {'balance': balance},
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: isBlocked
                              ? Icon(Icons.lock_outline, color: AppColors.error)
                              : null,
                          onTap: isBlocked
                              ? null
                              : () => Navigator.pop(context, member),
                        );
                      },
                    ),
            ),
            Divider(height: 1),
            // Footer
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredMembers.length} ${_filteredMembers.length == 1 ? context.tr('Member') : context.tr('Members')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('Cancel')),
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
