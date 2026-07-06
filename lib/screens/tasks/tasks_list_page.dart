import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/member_service.dart';
import '../../services/project_service.dart';
import '../../services/task_penalty_service.dart';
import '../../services/task_service.dart';
import 'add_task_page.dart';
import 'edit_task_page.dart';
import '../desktop/desktop_shell_scope.dart';

/// Tasks list (department-scoped)
class TasksListPage extends StatefulWidget {
  final String? departmentId;
  final bool hideAppBarAndBottomNav;

  TasksListPage({
    super.key,
    this.departmentId,
    this.hideAppBarAndBottomNav = false,
  });

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

const double _kTasksDesktopBreakpoint = 700;
const double _kTasksDesktopMaxWidth = 1280;

class _TasksListPageState extends State<TasksListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _penaltyMembers = [];
  bool _isLoading = true;
  bool _isLoadingDesktopMeta = true;
  String _workspaceView = 'projects';
  String? _selectedStatus;
  String? _selectedPriority;
  String? _selectedMemberId;
  String? _selectedProjectId;
  String? _selectedTagId;
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTasks();
    _loadDesktopMeta();
  }

  Future<void> _checkPermissions() async {
    final canCreate = await PermissionHelper.canCreate('tasks');
    if (!mounted) return;
    setState(() => _canCreate = canCreate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> tasks;
      if (widget.departmentId != null) {
        tasks = await TaskService.getDepartmentTasks(
          departmentId: widget.departmentId!,
          limit: 100,
        );
      } else {
        tasks = await TaskService.getAllTasks(
          status: _selectedStatus,
          priority: _selectedPriority,
          limit: 100,
        );
      }
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Error loading tasks: {error}', {'error': e}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadDesktopMeta() async {
    setState(() => _isLoadingDesktopMeta = true);
    try {
      final results = await Future.wait([
        ProjectService.getProjects(
          departmentId: widget.departmentId,
          limit: 500,
        ),
        MemberService.getMembers(limit: 500),
      ]);
      final projects = results[0];
      final members = results[1];
      final annotatedMembers =
          await TaskPenaltyService.annotateMembersWithPenalties(members);
      annotatedMembers.sort((a, b) {
        final balanceA = a['penalty_balance'] as int? ?? 0;
        final balanceB = b['penalty_balance'] as int? ?? 0;
        return balanceB.compareTo(balanceA);
      });
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _penaltyMembers = annotatedMembers;
        _isLoadingDesktopMeta = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDesktopMeta = false);
    }
  }

  Future<void> _sendGeneralTaskReminder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Send general task reminder?')),
        content: Text(
          context.tr(
            'This will notify all members who currently have pending or in-progress tasks.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Send reminder')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final count = await TaskService.remindAllPendingTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Reminder sent for {count} task assignment(s)', {
              'count': count,
            }),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Error sending reminders: {error}', {'error': e}),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openAddTask(BuildContext context) async {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kTasksDesktopBreakpoint;

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
              child: AddTaskPage(
                departmentId: widget.departmentId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true && mounted) _loadTasks();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.addTask, arguments: widget.departmentId);
    if (result == true && mounted) _loadTasks();
  }

  Future<void> _showRecordPenaltyPaymentDialog(
    Map<String, dynamic> member,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final memberName =
        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          memberName.isEmpty
              ? context.tr('Record payment')
              : context.tr('Record payment for {name}', {'name': memberName}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Amount'),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: context.tr('Note (optional)'),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Record')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    amountController.dispose();
    final note = noteController.text.trim();
    noteController.dispose();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Enter a valid amount')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await TaskPenaltyService.recordPayment(
        memberId: member['id'].toString(),
        amount: amount,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Payment recorded')),
          backgroundColor: AppColors.success,
        ),
      );
      _loadDesktopMeta();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Error recording payment: {error}', {'error': e}),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openEditTask(BuildContext context, String taskId) async {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kTasksDesktopBreakpoint;

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
                taskId: taskId,
                onClose: (result) => Navigator.of(dialogContext).pop(result),
              ),
            ),
          );
        },
      );
      if (result == true && mounted) _loadTasks();
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(RouteNames.editTask.replaceAll(':id', taskId));
    if (result == true && mounted) _loadTasks();
  }

  List<Map<String, dynamic>> get _filteredTasks {
    final query = _searchController.text.toLowerCase();
    var filtered = _tasks;

    if (query.isNotEmpty) {
      filtered = filtered.where((task) {
        final title = task['title']?.toString().toLowerCase() ?? '';
        final description = task['description']?.toString().toLowerCase() ?? '';
        final project = _getProjectTitle(task).toLowerCase();
        final assigned = _getAssignedMemberDisplay(task).toLowerCase();
        return title.contains(query) ||
            description.contains(query) ||
            project.contains(query) ||
            assigned.contains(query);
      }).toList();
    }

    if (_selectedStatus != null) {
      filtered = filtered
          .where((task) => task['status'] == _selectedStatus)
          .toList();
    }

    if (_selectedPriority != null) {
      filtered = filtered
          .where((task) => task['priority'] == _selectedPriority)
          .toList();
    }

    if (_selectedMemberId != null) {
      filtered = filtered.where((task) {
        final assignments = task['task_assignments'];
        if (assignments is! List || assignments.isEmpty) return false;
        return assignments.any(
          (a) => a is Map && a['member_id']?.toString() == _selectedMemberId,
        );
      }).toList();
    }

    if (_selectedProjectId != null) {
      filtered = filtered
          .where(
            (task) =>
                task['project_id']?.toString() == _selectedProjectId ||
                (task['projects'] is Map &&
                    (task['projects'] as Map)['id']?.toString() ==
                        _selectedProjectId),
          )
          .toList();
    }

    if (_selectedTagId != null) {
      filtered = filtered.where((task) {
        final taskTags = task['task_tags'];
        if (taskTags is! List || taskTags.isEmpty) return false;
        return taskTags.any(
          (tt) =>
              tt is Map &&
              tt['tags'] is Map &&
              (tt['tags'] as Map)['id']?.toString() == _selectedTagId,
        );
      }).toList();
    }

    return filtered;
  }

  /// Unique members assigned across tasks (for filter dropdown)
  List<Map<String, dynamic>> get _filterMemberOptions {
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final task in _tasks) {
      final assignments = task['task_assignments'];
      if (assignments is! List) continue;
      for (final a in assignments) {
        if (a is! Map) continue;
        final members = a['members'];
        if (members is! Map) continue;
        final id = members['id']?.toString();
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        list.add(Map<String, dynamic>.from(members));
      }
    }
    list.sort((a, b) {
      final na = '${a['first_name']} ${a['last_name']}'.toLowerCase();
      final nb = '${b['first_name']} ${b['last_name']}'.toLowerCase();
      return na.compareTo(nb);
    });
    return list;
  }

  /// Unique projects across tasks (for filter dropdown)
  List<Map<String, dynamic>> get _filterProjectOptions {
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final task in _tasks) {
      final proj = task['projects'];
      if (proj is! Map) continue;
      final id = proj['id']?.toString();
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      list.add(Map<String, dynamic>.from(proj));
    }
    list.sort(
      (a, b) => (a['title']?.toString() ?? '').toLowerCase().compareTo(
        (b['title']?.toString() ?? '').toLowerCase(),
      ),
    );
    return list;
  }

  /// Unique tags across tasks (for filter dropdown)
  List<Map<String, dynamic>> get _filterTagOptions {
    final seen = <String>{};
    final list = <Map<String, dynamic>>[];
    for (final task in _tasks) {
      final taskTags = task['task_tags'];
      if (taskTags is! List) continue;
      for (final tt in taskTags) {
        if (tt is! Map) continue;
        final tag = tt['tags'];
        if (tag is! Map) continue;
        final id = tag['id']?.toString();
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        list.add(Map<String, dynamic>.from(tag));
      }
    }
    list.sort(
      (a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo(
        (b['name']?.toString() ?? '').toLowerCase(),
      ),
    );
    return list;
  }

  String _getAssignedMemberDisplay(Map<String, dynamic> task) {
    final assignments = task['task_assignments'];
    if (assignments is! List || assignments.isEmpty) return '—';
    final names = <String>[];
    for (final a in assignments) {
      if (a is! Map) continue;
      final m = a['members'];
      if (m is Map) {
        final n = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
        if (n.isNotEmpty) names.add(n);
      }
    }
    return names.isEmpty ? '—' : names.join(', ');
  }

  String _getProjectTitle(Map<String, dynamic> task) {
    final proj = task['projects'];
    if (proj is Map) return proj['title']?.toString() ?? '—';
    return '—';
  }

  void _openTaskDetail(String taskId) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.taskDetail, taskId);
    } else {
      Navigator.of(context)
          .pushNamed(RouteNames.taskDetail.replaceAll(':id', taskId))
          .then((result) {
            if (result == true) _loadTasks();
          });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showFilters() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Filter Tasks')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: context.tr('Status'),
                    prefixIcon: Icon(Icons.check_circle),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.tr('All Statuses')),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text(context.tr('Pending')),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text(context.tr('In progress')),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text(context.tr('Completed')),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(context.tr('Cancelled')),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedStatus = value);
                  },
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedPriority,
                  decoration: InputDecoration(
                    labelText: context.tr('Priority'),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.tr('All Priorities')),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text(context.tr('Low')),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text(context.tr('Medium')),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text(context.tr('High')),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text(context.tr('Urgent')),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedPriority = value);
                  },
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedMemberId,
                  decoration: InputDecoration(
                    labelText: context.tr('Assigned member'),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.tr('All members')),
                    ),
                    ..._filterMemberOptions.map((m) {
                      final id = m['id']?.toString();
                      final name = '${m['first_name']} ${m['last_name']}'
                          .trim();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name.isEmpty ? '—' : name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedMemberId = value);
                  },
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedProjectId,
                  decoration: InputDecoration(
                    labelText: context.tr('Project'),
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.tr('All projects')),
                    ),
                    ..._filterProjectOptions.map((p) {
                      final id = p['id']?.toString();
                      final title = p['title']?.toString() ?? '—';
                      return DropdownMenuItem(value: id, child: Text(title));
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedProjectId = value);
                  },
                ),
                SizedBox(height: AppDimensions.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedTagId,
                  decoration: InputDecoration(
                    labelText: context.tr('Tag'),
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.tr('All tags')),
                    ),
                    ..._filterTagOptions.map((t) {
                      final id = t['id']?.toString();
                      final name = t['name']?.toString() ?? '—';
                      return DropdownMenuItem(value: id, child: Text(name));
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() => _selectedTagId = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedStatus = null;
                  _selectedPriority = null;
                  _selectedMemberId = null;
                  _selectedProjectId = null;
                  _selectedTagId = null;
                });
              },
              child: Text(context.tr('Clear filters')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Close')),
            ),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
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
        return context.mic.textSecondary;
      default:
        return context.mic.textSecondary;
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

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kTasksDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Tasks')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilters,
                  tooltip: context.tr('Filter'),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshTasksWorkspace,
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
      floatingActionButton: isDesktop
          ? null
          : FutureBuilder<bool>(
              future: PermissionHelper.canCreate('tasks'),
              builder: (context, snapshot) {
                final canCreate = snapshot.data ?? false;
                if (!canCreate) return SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: () async {
                    await _openAddTask(context);
                  },
                  child: Icon(Icons.add),
                );
              },
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTasks = _filteredTasks;

    return Padding(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _kTasksDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDesktopToolbar(theme),
              SizedBox(height: AppDimensions.spacingMD),
              _buildViewSwitcher(theme),
              SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _buildWorkspaceContent(
                  theme,
                  filteredTasks,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      child: Container(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                  ),
                  child: Icon(
                    Icons.view_week_outlined,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Tasks workspace'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        context.tr('{visible} visible of {total} tasks', {
                          'visible': _filteredTasks.length,
                          'total': _tasks.length,
                        }),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.mic.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _sendGeneralTaskReminder,
                  icon: Icon(Icons.notifications_active_outlined),
                  label: Text(context.tr('Reminder')),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                OutlinedButton.icon(
                  onPressed: _openManageProjects,
                  icon: Icon(Icons.folder_outlined),
                  label: Text(context.tr('Projects')),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                OutlinedButton.icon(
                  onPressed: _openManageTags,
                  icon: Icon(Icons.label_outlined),
                  label: Text(context.tr('Tags')),
                ),
                if (_canCreate) ...[
                  SizedBox(width: AppDimensions.spacingSM),
                  FilledButton.icon(
                    onPressed: () => _openAddTask(context),
                    icon: Icon(Icons.add),
                    label: Text(context.tr('Add Task')),
                  ),
                ],
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'Search tasks, projects, assignees...',
                      ),
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusLG,
                        ),
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                OutlinedButton.icon(
                  onPressed: _showFilters,
                  icon: Icon(Icons.tune),
                  label: Text(
                    _hasActiveFilters
                        ? context.tr('Filters on')
                        : context.tr('Filters'),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                IconButton.outlined(
                  onPressed: _isLoading ? null : _refreshTasksWorkspace,
                  icon: Icon(Icons.refresh),
                  tooltip: context.tr('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher(ThemeData theme) {
    const views = [
      ('projects', Icons.folder_copy_outlined, 'Projects'),
      ('board', Icons.view_kanban_outlined, 'Board'),
      ('all', Icons.table_rows_outlined, 'All tasks'),
      ('charts', Icons.insert_chart_outlined, 'Charts'),
      ('penalties', Icons.account_balance_wallet_outlined, 'Penalties'),
    ];

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        child: Row(
          children: views.map((view) {
            final selected = _workspaceView == view.$1;
            return Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingSM),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(
                  view.$2,
                  size: 16,
                  color: selected ? theme.colorScheme.onPrimary : null,
                ),
                label: Text(context.tr(view.$3)),
                onSelected: (_) => setState(() => _workspaceView = view.$1),
                selectedColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: TextStyle(
                  color: selected ? theme.colorScheme.onPrimary : null,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWorkspaceContent(
    ThemeData theme,
    List<Map<String, dynamic>> filteredTasks, {
    bool compact = false,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_workspaceView == 'penalties') {
      return _buildPenaltiesView(theme, compact: compact);
    }
    if (filteredTasks.isEmpty && _workspaceView != 'charts') {
      return _buildDesktopEmptyState(theme);
    }
    return _buildSelectedView(theme, filteredTasks, compact: compact);
  }

  Widget _buildSelectedView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    switch (_workspaceView) {
      case 'board':
        return _buildBoardView(theme, tasks, compact: compact);
      case 'all':
        return _buildAllTasksView(theme, tasks, compact: compact);
      case 'charts':
        return _buildChartsView(theme, tasks, compact: compact);
      case 'penalties':
        return _buildPenaltiesView(theme, compact: compact);
      case 'projects':
      default:
        return _buildProjectsView(theme, tasks, compact: compact);
    }
  }

  Widget _buildDesktopEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 72,
            color: context.mic.textSecondary,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Text(
            _hasActiveFilters || _searchController.text.isNotEmpty
                ? context.tr('No tasks match this view')
                : context.tr('No tasks yet'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXS),
          Text(
            context.tr('Try another filter or create a new task.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    final groups = <_TaskProjectGroup>[];
    for (final project in _projects) {
      final id = project['id']?.toString();
      if (id == null) continue;
      final projectTasks = tasks
          .where((task) => _taskProjectId(task) == id)
          .toList();
      if (projectTasks.isNotEmpty) {
        groups.add(
          _TaskProjectGroup(
            title:
                project['title']?.toString() ?? context.tr('Untitled project'),
            tasks: projectTasks,
          ),
        );
      }
    }
    final knownProjectIds = _projects
        .map((project) => project['id']?.toString())
        .whereType<String>()
        .toSet();
    final noProjectTasks = tasks.where((task) {
      final id = _taskProjectId(task);
      return id == null || !knownProjectIds.contains(id);
    }).toList();
    if (noProjectTasks.isNotEmpty) {
      groups.add(
        _TaskProjectGroup(
          title: context.tr('No project'),
          tasks: noProjectTasks,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact
            ? EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD)
            : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 900
                ? (constraints.maxWidth - AppDimensions.spacingMD) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: AppDimensions.spacingMD,
              runSpacing: AppDimensions.spacingMD,
              children: groups
                  .map(
                    (group) => SizedBox(
                      width: cardWidth,
                      child: _buildProjectGroupCard(theme, group),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProjectGroupCard(ThemeData theme, _TaskProjectGroup group) {
    final completed = group.tasks
        .where((task) => task['status']?.toString() == 'completed')
        .length;
    return _DesktopTaskSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildDesktopChip(
                context.tr('{completed}/{total} done', {
                  'completed': completed,
                  'total': group.tasks.length,
                }),
                AppColors.success,
                Icons.check_circle_outline,
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          ...group.tasks
              .take(5)
              .map(
                (task) => Padding(
                  padding: EdgeInsets.only(bottom: AppDimensions.spacingSM),
                  child: _buildDesktopTaskCard(task, compact: true),
                ),
              ),
          if (group.tasks.length > 5)
            Text(
              context.tr('+{count} more tasks', {
                'count': group.tasks.length - 5,
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.mic.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllTasksView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact
            ? EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD)
            : null,
        itemCount: tasks.length,
        separatorBuilder: (_, __) => SizedBox(height: AppDimensions.spacingSM),
        itemBuilder: (context, index) => _buildDesktopTaskCard(tasks[index]),
      ),
    );
  }

  Widget _buildBoardView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    const statuses = [
      ('pending', 'Pending'),
      ('in_progress', 'In progress'),
      ('completed', 'Completed'),
      ('cancelled', 'Cancelled'),
    ];

    if (compact) {
      final boardHeight = MediaQuery.sizeOf(context).height * 0.58;
      return RefreshIndicator(
        onRefresh: _refreshTasksWorkspace,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: boardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
              itemCount: statuses.length,
              separatorBuilder: (_, __) =>
                  SizedBox(width: AppDimensions.spacingSM),
              itemBuilder: (context, index) {
                final status = statuses[index];
                final columnTasks = tasks
                    .where(
                      (task) =>
                          (task['status']?.toString() ?? 'pending') ==
                          status.$1,
                    )
                    .toList();
                return SizedBox(
                  width: 288,
                  child: _buildKanbanColumn(
                    theme,
                    status.$1,
                    status.$2,
                    columnTasks,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: statuses.map((status) {
              final columnTasks = tasks
                  .where(
                    (task) =>
                        (task['status']?.toString() ?? 'pending') == status.$1,
                  )
                  .toList();
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                  child: _buildKanbanColumn(
                    theme,
                    status.$1,
                    status.$2,
                    columnTasks,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    ThemeData theme,
    String status,
    String label,
    List<Map<String, dynamic>> tasks,
  ) {
    final color = _getStatusColor(status);
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) =>
          details.data['status']?.toString() != status,
      onAcceptWithDetails: (details) => _moveTaskToStatus(details.data, status),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: Duration(milliseconds: 160),
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          decoration: BoxDecoration(
            color: isHovering
                ? color.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            border: Border.all(
              color: isHovering ? color : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr(label),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _buildDesktopChip('${tasks.length}', color, Icons.circle),
                ],
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          context.tr('Drop tasks here'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: AppDimensions.spacingSM),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Draggable<Map<String, dynamic>>(
                            data: task,
                            feedback: SizedBox(
                              width: 260,
                              child: Material(
                                color: Colors.transparent,
                                child: _buildDesktopTaskCard(
                                  task,
                                  compact: true,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _buildDesktopTaskCard(task, compact: true),
                            ),
                            child: _buildDesktopTaskCard(task, compact: true),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartsView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    final statusCounts = _countBy(tasks, 'status');
    final priorityCounts = _countBy(tasks, 'priority');
    final projectCounts = <String, int>{};
    for (final task in tasks) {
      final project = _getProjectTitle(task);
      final projectLabel = project == '—' ? context.tr('No project') : project;
      projectCounts[projectLabel] = (projectCounts[projectLabel] ?? 0) + 1;
    }
    final overdue = tasks.where(_isTaskOverdue).length;
    final open = tasks
        .where((task) => task['status']?.toString() != 'completed')
        .length;

    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact
            ? EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppDimensions.spacingMD,
              runSpacing: AppDimensions.spacingMD,
              children: [
                _buildMetricCard(
                  theme,
                  context.tr('Open tasks'),
                  '$open',
                  Icons.task_outlined,
                  compact: compact,
                ),
                _buildMetricCard(
                  theme,
                  context.tr('Overdue'),
                  '$overdue',
                  Icons.warning_amber_outlined,
                  color: overdue > 0 ? AppColors.error : AppColors.success,
                  compact: compact,
                ),
                _buildMetricCard(
                  theme,
                  context.tr('Projects'),
                  '${projectCounts.length}',
                  Icons.folder_outlined,
                  compact: compact,
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            if (compact) ...[
              _buildBarChartCard(theme, 'Status', statusCounts),
              SizedBox(height: AppDimensions.spacingMD),
              _buildBarChartCard(theme, 'Priority', priorityCounts),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildBarChartCard(theme, 'Status', statusCounts),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: _buildBarChartCard(theme, 'Priority', priorityCounts),
                  ),
                ],
              ),
            SizedBox(height: AppDimensions.spacingMD),
            _buildBarChartCard(theme, 'Project workload', projectCounts),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltiesView(ThemeData theme, {bool compact = false}) {
    if (_isLoadingDesktopMeta) {
      return Center(child: CircularProgressIndicator());
    }

    final members = _penaltyMembers
        .where((member) => (member['penalty_balance'] as int? ?? 0) > 0)
        .toList();

    if (members.isEmpty) {
      return Center(
        child: Text(
          context.tr('No unpaid penalties'),
          style: theme.textTheme.titleMedium?.copyWith(
            color: context.mic.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDesktopMeta,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: compact
            ? EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD)
            : null,
        itemCount: members.length,
        separatorBuilder: (_, __) => SizedBox(height: AppDimensions.spacingSM),
        itemBuilder: (context, index) =>
            _buildPenaltyMemberCard(theme, members[index], compact: compact),
      ),
    );
  }

  Widget _buildPenaltyMemberCard(
    ThemeData theme,
    Map<String, dynamic> member, {
    bool compact = false,
  }) {
    final balance = member['penalty_balance'] as int? ?? 0;
    final blocked = member['is_assignment_blocked'] == true;
    final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
        .trim();

    if (compact) {
      return _DesktopTaskSurface(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: blocked
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.14),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: blocked ? AppColors.error : AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? context.tr('Unnamed member') : name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        blocked
                            ? context.tr('Blocked from new task assignments')
                            : context.tr('Penalty balance pending'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: blocked ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDesktopChip(
                  '${balance}frs',
                  blocked ? AppColors.error : AppColors.warning,
                  Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            FilledButton.icon(
              onPressed: () => _showRecordPenaltyPaymentDialog(member),
              icon: const Icon(Icons.payments_outlined),
              label: Text(context.tr('Record payment')),
            ),
          ],
        ),
      );
    }

    return _DesktopTaskSurface(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: blocked
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.14),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                color: blocked ? AppColors.error : AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.tr('Unnamed member') : name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  blocked
                      ? context.tr('Blocked from new task assignments')
                      : context.tr('Penalty balance pending'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: blocked ? AppColors.error : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          _buildDesktopChip(
            '${balance}frs',
            blocked ? AppColors.error : AppColors.warning,
            Icons.account_balance_wallet_outlined,
          ),
          SizedBox(width: AppDimensions.spacingMD),
          OutlinedButton.icon(
            onPressed: () => _showRecordPenaltyPaymentDialog(member),
            icon: const Icon(Icons.payments_outlined),
            label: Text(context.tr('Record payment')),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTaskCard(
    Map<String, dynamic> task, {
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final taskId = task['id']?.toString() ?? '';
    final title = task['title']?.toString() ?? context.tr('Untitled task');
    final description = task['description']?.toString();
    final status = task['status']?.toString() ?? 'pending';
    final priority = task['priority']?.toString() ?? 'medium';
    final dueDate = _taskDueDate(task);
    final assigned = _getAssignedMemberDisplay(task);
    final project = _getProjectTitle(task);

    return _DesktopTaskSurface(
      padding: compact
          ? EdgeInsets.all(AppDimensions.paddingMD)
          : EdgeInsets.all(AppDimensions.paddingLG),
      child: InkWell(
        onTap: taskId.isEmpty ? null : () => _openTaskDetail(taskId),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                _buildDesktopChip(
                  context.l10n.statusLabel(status),
                  _getStatusColor(status),
                  Icons.circle,
                ),
              ],
            ),
            if (!compact && description != null && description.isNotEmpty) ...[
              SizedBox(height: AppDimensions.spacingXS),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.mic.textSecondary,
                ),
              ),
            ],
            SizedBox(height: AppDimensions.spacingSM),
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingXS,
              children: [
                _buildDesktopChip(
                  context.l10n.priorityLabel(priority),
                  _getPriorityColor(priority),
                  Icons.flag_outlined,
                ),
                if (dueDate != null)
                  _buildDesktopChip(
                    _formatDate(dueDate),
                    _isTaskOverdue(task) ? AppColors.error : AppColors.primary,
                    Icons.calendar_today_outlined,
                  ),
                if (project != '—')
                  _buildDesktopChip(
                    project,
                    AppColors.primary,
                    Icons.folder_outlined,
                  ),
                if (assigned != '—')
                  _buildDesktopChip(
                    assigned,
                    context.mic.textSecondary,
                    Icons.person_outline,
                  ),
              ],
            ),
            if (!compact) ...[
              SizedBox(height: AppDimensions.spacingMD),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: taskId.isEmpty
                        ? null
                        : () => _openTaskDetail(taskId),
                    icon: Icon(Icons.open_in_new, size: 18),
                    label: Text(context.tr('Open')),
                  ),
                  SizedBox(width: AppDimensions.spacingSM),
                  TextButton.icon(
                    onPressed: taskId.isEmpty
                        ? null
                        : () => _openEditTask(context, taskId),
                    icon: Icon(Icons.edit_outlined, size: 18),
                    label: Text(context.tr('Edit')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopChip(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon, {
    Color color = AppColors.primary,
    bool compact = false,
  }) {
    return SizedBox(
      width: compact ? double.infinity : 240,
      child: _DesktopTaskSurface(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(
    ThemeData theme,
    String title,
    Map<String, int> counts,
  ) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.fold<int>(
      1,
      (current, entry) => entry.value > current ? entry.value : current,
    );

    return _DesktopTaskSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(title),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          if (entries.isEmpty)
            Text(
              context.tr('No data yet'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.mic.textSecondary,
              ),
            )
          else
            ...entries.take(8).map((entry) {
              final color = title == 'Status'
                  ? _getStatusColor(entry.key)
                  : title == 'Priority'
                  ? _getPriorityColor(entry.key)
                  : AppColors.primary;
              return Padding(
                padding: EdgeInsets.only(bottom: AppDimensions.spacingSM),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        title == 'Status'
                            ? context.l10n.statusLabel(entry.key)
                            : title == 'Priority'
                            ? context.l10n.priorityLabel(entry.key)
                            : context.tr(entry.key.replaceAll('_', ' ')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSM,
                        ),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: entry.value / maxValue,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
                    Text(
                      entry.value.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Map<String, int> _countBy(List<Map<String, dynamic>> tasks, String field) {
    final counts = <String, int>{};
    for (final task in tasks) {
      final value = task[field]?.toString();
      final label = value == null || value.isEmpty ? 'unknown' : value;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _moveTaskToStatus(
    Map<String, dynamic> task,
    String status,
  ) async {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) return;
    final previousStatus = task['status'];
    setState(() => task['status'] = status);
    try {
      await TaskService.updateTask(taskId: taskId, updates: {'status': status});
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() => task['status'] = previousStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Could not update task status: {error}', {'error': e}),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _refreshTasksWorkspace() async {
    await Future.wait([_loadTasks(), _loadDesktopMeta()]);
  }

  Future<void> _openManageProjects() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.manageProjects, widget.departmentId ?? '');
      return;
    }
    await Navigator.of(context).pushNamed(RouteNames.manageProjects);
    await _refreshTasksWorkspace();
  }

  Future<void> _openManageTags() async {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null) {
      scope.pushDetail(RouteNames.manageTags, widget.departmentId ?? '');
      return;
    }
    await Navigator.of(context).pushNamed(RouteNames.manageTags);
    await _refreshTasksWorkspace();
  }

  bool get _hasActiveFilters =>
      _selectedStatus != null ||
      _selectedPriority != null ||
      _selectedMemberId != null ||
      _selectedProjectId != null ||
      _selectedTagId != null;

  String? _taskProjectId(Map<String, dynamic> task) {
    final directId = task['project_id']?.toString();
    if (directId != null && directId.isNotEmpty) return directId;
    final project = task['projects'];
    if (project is Map) return project['id']?.toString();
    return null;
  }

  DateTime? _taskDueDate(Map<String, dynamic> task) {
    final value = task['due_date']?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  bool _isTaskOverdue(Map<String, dynamic> task) {
    final dueDate = _taskDueDate(task);
    if (dueDate == null) return false;
    if (task['status']?.toString() == 'completed') return false;
    final today = DateTime.now();
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return dueDay.isBefore(todayDay);
  }

  Widget _buildMobileBody(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTasks = _filteredTasks;
    final openTasks = _tasks
        .where((task) => task['status']?.toString() != 'completed')
        .length;
    final overdueTasks = _tasks.where(_isTaskOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileHeader(theme, openTasks, overdueTasks),
        SizedBox(height: AppDimensions.spacingSM),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search tasks, projects, assignees...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(height: AppDimensions.spacingSM),
        _buildViewSwitcher(theme),
        SizedBox(height: AppDimensions.spacingSM),
        _buildMobileActionsRow(theme),
        if (_hasActiveFilters) ...[
          SizedBox(height: AppDimensions.spacingSM),
          _buildActiveFilterChips(theme),
        ],
        SizedBox(height: AppDimensions.spacingSM),
        Expanded(
          child: _buildWorkspaceContent(
            theme,
            filteredTasks,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(
    ThemeData theme,
    int openTasks,
    int overdueTasks,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: context.mic.brandGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
                ),
                child: const Icon(
                  Icons.view_week_outlined,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Tasks workspace'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      context.tr('{visible} visible of {total} tasks', {
                        'visible': _filteredTasks.length,
                        'total': _tasks.length,
                      }),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Row(
            children: [
              Expanded(
                child: _buildMobileStatChip(
                  icon: Icons.task_alt_outlined,
                  label: context.tr('Open tasks'),
                  value: '$openTasks',
                ),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: _buildMobileStatChip(
                  icon: Icons.warning_amber_outlined,
                  label: context.tr('Overdue'),
                  value: '$overdueTasks',
                  highlight: overdueTasks > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatChip({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMD,
        vertical: AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? Colors.white.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          SizedBox(width: AppDimensions.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionsRow(ThemeData theme) {
    final actions = [
      (
        Icons.notifications_active_outlined,
        context.tr('Reminder'),
        _sendGeneralTaskReminder,
      ),
      (
        Icons.folder_outlined,
        context.tr('Projects'),
        _openManageProjects,
      ),
      (
        Icons.label_outlined,
        context.tr('Tags'),
        _openManageTags,
      ),
    ];

    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        child: Row(
          children: actions.map((action) {
            return Padding(
              padding: EdgeInsets.only(right: AppDimensions.spacingSM),
              child: OutlinedButton.icon(
                onPressed: action.$3,
                icon: Icon(action.$1, size: 16),
                label: Text(action.$2),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingMD,
                    vertical: AppDimensions.spacingXS,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(ThemeData theme) {
    final chips = <Widget>[];

    void addChip(String label, VoidCallback onClear) {
      chips.add(
        InputChip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          onDeleted: onClear,
          deleteIcon: const Icon(Icons.close, size: 16),
        ),
      );
    }

    if (_selectedStatus != null) {
      addChip(context.l10n.statusLabel(_selectedStatus!), () {
        setState(() => _selectedStatus = null);
        _loadTasks();
      });
    }
    if (_selectedPriority != null) {
      addChip(context.l10n.priorityLabel(_selectedPriority!), () {
        setState(() => _selectedPriority = null);
        _loadTasks();
      });
    }
    if (_selectedProjectId != null) {
      final project = _projects.firstWhere(
        (item) => item['id']?.toString() == _selectedProjectId,
        orElse: () => {},
      );
      addChip(
        project['title']?.toString() ?? context.tr('Project'),
        () {
          setState(() => _selectedProjectId = null);
          _loadTasks();
        },
      );
    }
    if (_selectedTagId != null) {
      addChip(context.tr('Tag filter'), () {
        setState(() => _selectedTagId = null);
        _loadTasks();
      });
    }
    if (_selectedMemberId != null) {
      addChip(context.tr('Assignee filter'), () {
        setState(() => _selectedMemberId = null);
        _loadTasks();
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
      child: Row(children: chips),
    );
  }
}

class _TaskProjectGroup {
  _TaskProjectGroup({required this.title, required this.tasks});

  final String title;
  final List<Map<String, dynamic>> tasks;
}

class _DesktopTaskSurface extends StatelessWidget {
  _DesktopTaskSurface({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingLG),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
