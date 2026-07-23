import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/error_message_helper.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/member_service.dart';
import '../../services/department_service.dart';
import '../../services/project_service.dart';
import '../../services/task_penalty_service.dart';
import '../../services/tag_service.dart';
import '../../services/task_service.dart';
import '../../core/constants/tag_colors.dart';
import 'add_task_page.dart';
import 'edit_task_page.dart';
import 'task_table_inline_cells.dart';
import 'task_assignee_picker.dart';
import 'task_tag_picker_panel.dart';
import 'task_table_anchored_popup.dart';
import 'task_member_analytics.dart';
import 'task_member_chart_views.dart';
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
const double _kTaskTableResizeHandleWidth = 8;
const double _kTaskTableMinColumnWidth = 72;
const double _kTaskTableMaxColumnWidth = 640;
const double _kTimelineLabelWidth = 280;
const double _kTimelineRowHeight = 56;
const double _kTimelineWeekHeaderHeight = 34;
const double _kTimelineMonthHeaderHeight = 30;
const double _kTimelineDayHeaderHeight = 44;
const double _kTimelineProjectHeaderHeight = 38;
const double _kTimelineMinDayWidth = 44;
const double _kTimelineMaxDayWidth = 72;
const double _kTimelineMinZoom = 0.6;
const double _kTimelineMaxZoom = 2.4;
const double _kTimelineZoomStep = 0.2;

class _TasksListPageState extends State<TasksListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _penaltyMembers = [];
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = true;
  bool _isLoadingDesktopMeta = true;
  String _workspaceView = 'projects';
  String? _selectedStatus;
  String? _selectedPriority;
  String? _selectedMemberId;
  String? _selectedProjectId;
  String? _selectedTagId;
  bool _canCreate = false;
  late List<double> _taskTableColumnWidths;
  final _timelineHeaderScrollController = ScrollController();
  final _timelineBodyScrollController = ScrollController();
  final _timelineBodyVerticalScrollController = ScrollController();
  final _timelineLabelsVerticalScrollController = ScrollController();
  bool _isSyncingTimelineScroll = false;
  bool _isSyncingTimelineVerticalScroll = false;
  double _timelineZoom = 1.0;
  int? _taskTableSortColumnIndex;
  bool _taskTableSortAscending = true;
  /// Project currently showing an inline new-task draft row (`''` = No project).
  String? _draftingProjectKey;
  bool _isSavingDraftTask = false;
  final _draftTitleController = TextEditingController();
  final _draftTitleFocusNode = FocusNode();

  static const Map<String, int> _taskStatusSortOrder = {
    'pending': 0,
    'in_progress': 1,
    'completed': 2,
    'cancelled': 3,
  };

  @override
  void initState() {
    super.initState();
    _taskTableColumnWidths = [300, 140, 200, 150, 160, 260, 128];
    _timelineHeaderScrollController.addListener(_syncTimelineBodyToHeader);
    _timelineBodyScrollController.addListener(_syncTimelineHeaderToBody);
    _timelineLabelsVerticalScrollController.addListener(
      _syncTimelineChartToLabels,
    );
    _timelineBodyVerticalScrollController.addListener(
      _syncTimelineLabelsToChart,
    );
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
    _timelineHeaderScrollController.removeListener(_syncTimelineBodyToHeader);
    _timelineBodyScrollController.removeListener(_syncTimelineHeaderToBody);
    _timelineLabelsVerticalScrollController.removeListener(
      _syncTimelineChartToLabels,
    );
    _timelineBodyVerticalScrollController.removeListener(
      _syncTimelineLabelsToChart,
    );
    _timelineHeaderScrollController.dispose();
    _timelineBodyScrollController.dispose();
    _timelineBodyVerticalScrollController.dispose();
    _timelineLabelsVerticalScrollController.dispose();
    _searchController.dispose();
    _draftTitleController.dispose();
    _draftTitleFocusNode.dispose();
    super.dispose();
  }

  void _syncTimelineBodyToHeader() {
    _syncTimelineScroll(
      source: _timelineHeaderScrollController,
      target: _timelineBodyScrollController,
    );
  }

  void _syncTimelineHeaderToBody() {
    _syncTimelineScroll(
      source: _timelineBodyScrollController,
      target: _timelineHeaderScrollController,
    );
  }

  void _syncTimelineScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_isSyncingTimelineScroll || !source.hasClients || !target.hasClients) {
      return;
    }
    _isSyncingTimelineScroll = true;
    target.jumpTo(source.offset);
    _isSyncingTimelineScroll = false;
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
        ErrorMessageHelper.showErrorSnackBar(
          context,
          e,
          title: context.tr('Error loading tasks'),
        );
      }
    }
  }

  Future<void> _loadDesktopMeta() async {
    setState(() => _isLoadingDesktopMeta = true);
    try {
      final deptId = widget.departmentId;
      final results = await Future.wait([
        ProjectService.getProjects(
          departmentId: widget.departmentId,
          limit: 500,
        ),
        MemberService.getMembers(limit: 500),
        if (deptId != null)
          TagService.getTags(departmentId: deptId, limit: 500)
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);
      final projects = results[0];
      final members = results[1];
      final tags = results[2];
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
        _tags = tags;
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
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Error sending reminders'),
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
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Error recording payment'),
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
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat('d MMMM y', locale).format(date);
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
                        child: Text(name.isEmpty ? context.tr('—') : name),
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
                      final title = p['title']?.toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(title ?? context.tr('—')),
                      );
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
                      final name = t['name']?.toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(name ?? context.tr('—')),
                      );
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
              Expanded(child: _buildWorkspaceContent(theme, filteredTasks)),
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
      ('timeline', Icons.view_timeline_outlined, 'Timeline'),
      ('avg_lateness', Icons.av_timer_outlined, 'Avg. lateness'),
      ('workload', Icons.work_outline, 'Workload'),
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
                onSelected: (_) => setState(() {
                  _workspaceView = view.$1;
                  if (view.$1 == 'projects' || view.$1 == 'all') {
                    _selectedProjectId = null;
                  }
                  if (view.$1 != 'projects') {
                    _draftingProjectKey = null;
                    _draftTitleController.clear();
                    _isSavingDraftTask = false;
                  }
                }),
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
    if (filteredTasks.isEmpty &&
        _workspaceView != 'timeline' &&
        _workspaceView != 'avg_lateness' &&
        _workspaceView != 'workload') {
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
      case 'timeline':
        return _buildTimelineView(theme, tasks, compact: compact);
      case 'avg_lateness':
        return _buildAvgLatenessView(theme, tasks, compact: compact);
      case 'workload':
        return _buildWorkloadView(theme, tasks, compact: compact);
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
    if (_isLoadingDesktopMeta) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = _collectTaskProjectGroups(tasks);
    if (groups.isEmpty) {
      return _buildDesktopEmptyState(theme);
    }

    if (compact) {
      return RefreshIndicator(
        onRefresh: _refreshTasksWorkspace,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              _buildProjectGroupCard(theme, groups[i]),
              if (i < groups.length - 1)
                SizedBox(height: AppDimensions.spacingMD),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            _buildProjectDropSection(theme, groups[i]),
            if (i < groups.length - 1)
              SizedBox(height: AppDimensions.spacingXL),
          ],
        ],
      ),
    );
  }

  String _projectGroupKey(_TaskProjectGroup group) =>
      group.projectId ?? '__no_project__';

  Widget _buildProjectDropSection(ThemeData theme, _TaskProjectGroup group) {
    final groupKey = _projectGroupKey(group);
    final isDrafting = _draftingProjectKey == groupKey;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        Map<String, dynamic>? task;
        for (final t in _tasks) {
          if (t['id']?.toString() == details.data) {
            task = t;
            break;
          }
        }
        if (task == null) return false;
        return _taskProjectId(task) != group.projectId;
      },
      onAcceptWithDetails: (details) {
        unawaited(_moveTaskToProject(details.data, group.projectId));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: isHovering
                ? Border.all(color: AppColors.primary, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
            color: isHovering
                ? AppColors.primary.withValues(alpha: 0.04)
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProjectSectionHeader(theme, group),
              _buildTasksTableContent(
                theme,
                group.tasks,
                enableDrag: true,
              ),
              if (isDrafting) _buildInlineDraftTaskRow(theme, group),
              if (_canCreate) ...[
                SizedBox(height: AppDimensions.spacingSM),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSavingDraftTask
                        ? null
                        : () => _startInlineDraft(groupKey),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('Add task')),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _startInlineDraft(String projectKey) {
    setState(() {
      _draftingProjectKey = projectKey;
      _draftTitleController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _draftTitleFocusNode.requestFocus();
    });
  }

  void _cancelInlineDraft() {
    setState(() {
      _draftingProjectKey = null;
      _draftTitleController.clear();
      _isSavingDraftTask = false;
    });
  }

  Future<void> _saveInlineDraftTask(_TaskProjectGroup group) async {
    final title = _draftTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Task title is required'))),
      );
      return;
    }
    if (_isSavingDraftTask) return;

    setState(() => _isSavingDraftTask = true);
    try {
      var departmentId = widget.departmentId;
      if (departmentId == null && group.projectId != null) {
        for (final project in _projects) {
          if (project['id']?.toString() == group.projectId) {
            departmentId = project['department_id']?.toString();
            break;
          }
        }
      }

      await TaskService.createTask(
        departmentId: departmentId,
        taskData: {
          'title': title,
          'status': 'pending',
          'priority': 'medium',
          if (group.projectId != null) 'project_id': group.projectId,
        },
      );
      if (!mounted) return;
      _cancelInlineDraft();
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingDraftTask = false);
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not create task'),
      );
    }
  }

  Future<void> _moveTaskToProject(String taskId, String? projectId) async {
    final taskIndex = _tasks.indexWhere((t) => t['id']?.toString() == taskId);
    if (taskIndex < 0) return;

    final task = _tasks[taskIndex];
    if (_taskProjectId(task) == projectId) return;

    final previousProjectId = task['project_id'];
    final previousProjects = task['projects'];

    setState(() {
      task['project_id'] = projectId;
      if (projectId == null) {
        task['projects'] = null;
      } else {
        Map<String, dynamic>? project;
        for (final p in _projects) {
          if (p['id']?.toString() == projectId) {
            project = p;
            break;
          }
        }
        if (project != null) {
          task['projects'] = {
            'id': project['id'],
            'title': project['title'],
          };
        }
      }
    });

    try {
      await TaskService.updateTask(
        taskId: taskId,
        updates: {'project_id': projectId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        task['project_id'] = previousProjectId;
        task['projects'] = previousProjects;
      });
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not move task'),
      );
    }
  }

  Widget _buildInlineDraftTaskRow(ThemeData theme, _TaskProjectGroup group) {
    final borderColor = _taskTableBorderColor(theme);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _taskTableTotalWidth,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[0],
                borderColor: borderColor,
                showLeftBorder: true,
                child: TextField(
                  controller: _draftTitleController,
                  focusNode: _draftTitleFocusNode,
                  enabled: !_isSavingDraftTask,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.tr('Task title'),
                    hintStyle: theme.textTheme.titleSmall?.copyWith(
                      color: context.mic.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveInlineDraftTask(group),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[1],
                borderColor: borderColor,
                child: Text(
                  context.l10n.statusLabel('pending'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[2],
                borderColor: borderColor,
                child: Text(
                  context.tr('—'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[3],
                borderColor: borderColor,
                child: Text(
                  context.tr('—'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[4],
                borderColor: borderColor,
                child: Text(
                  context.tr('—'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[5],
                borderColor: borderColor,
                child: Text(
                  context.tr('—'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ),
              _buildTasksTableGridCell(
                theme: theme,
                width: _taskTableColumnWidths[6],
                borderColor: borderColor,
                showRightBorder: true,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingSM,
                  vertical: AppDimensions.spacingSM,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSavingDraftTask)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else ...[
                      IconButton(
                        tooltip: context.tr('Save'),
                        iconSize: 24,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: () => _saveInlineDraftTask(group),
                        icon: Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Cancel'),
                        iconSize: 24,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: _cancelInlineDraft,
                        icon: Icon(
                          Icons.cancel_outlined,
                          color: context.mic.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
              if (group.endDateText != null)
                Text(
                  group.endDateText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mic.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              SizedBox(width: AppDimensions.spacingSM),
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

  List<_TaskProjectGroup> _collectTaskProjectGroups(
    List<Map<String, dynamic>> tasks,
  ) {
    final groups = <_TaskProjectGroup>[];
    final sortedProjects = [..._projects];
    sortedProjects.sort((a, b) {
      final aDate = DateTime.tryParse(a['end_date']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['end_date']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    for (final project in sortedProjects) {
      final id = project['id']?.toString();
      if (id == null) continue;
      final projectTasks =
          tasks.where((task) => _taskProjectId(task) == id).toList();

      final endDateStr = project['end_date']?.toString();
      String endDateText = '—';
      if (endDateStr != null && endDateStr.isNotEmpty) {
        final dt = DateTime.tryParse(endDateStr);
        if (dt != null) endDateText = _formatDate(dt);
      }

      groups.add(
        _TaskProjectGroup(
          projectId: id,
          title:
              project['title']?.toString() ?? context.tr('Untitled project'),
          endDateText: endDateText,
          tasks: projectTasks,
        ),
      );
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
          projectId: null,
          title: context.tr('No project'),
          tasks: noProjectTasks,
        ),
      );
    }

    return groups;
  }

  Widget _buildProjectSectionHeader(ThemeData theme, _TaskProjectGroup group) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingMD),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (group.endDateText != null)
            Text(
              group.endDateText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.mic.textSecondary,
                fontWeight: FontWeight.w800,
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
    if (compact) {
      return RefreshIndicator(
        onRefresh: _refreshTasksWorkspace,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: compact
              ? EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD)
              : null,
          itemCount: tasks.length,
          separatorBuilder: (_, __) =>
              SizedBox(height: AppDimensions.spacingSM),
          itemBuilder: (context, index) => _buildDesktopTaskCard(tasks[index]),
        ),
      );
    }

    return _buildDesktopResizableTasksTable(theme, tasks);
  }

  String? _analyticsDepartmentLabel(List<Map<String, dynamic>> tasks) {
    if (widget.departmentId != null) {
      return TaskMemberAnalytics.departmentLabel(tasks) ??
          context.tr('Current department');
    }
    return null;
  }

  Widget _buildAvgLatenessView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    final metrics = TaskMemberAnalytics.averageLatenessPerMember(tasks);
    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          compact ? AppDimensions.paddingMD : AppDimensions.paddingMD,
        ),
        children: [
          TaskMemberLatenessChartView(
            metrics: metrics,
            departmentName: _analyticsDepartmentLabel(tasks),
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkloadView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    final metrics = TaskMemberAnalytics.workloadPerMember(tasks);
    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(
          compact ? AppDimensions.paddingMD : AppDimensions.paddingMD,
        ),
        children: [
          TaskMemberWorkloadChartView(
            metrics: metrics,
            departmentName: _analyticsDepartmentLabel(tasks),
            compact: compact,
          ),
        ],
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
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMD,
              ),
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

  Widget _buildTimelineView(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool compact = false,
  }) {
    final timelineTasks = _timelineTasksWithDates(tasks);
    if (timelineTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: Text(
            tasks.isEmpty
                ? context.tr('No tasks yet')
                : context.tr(
                    'No scheduled tasks to display on the timeline.',
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ),
      );
    }

    final projectGroups = _collectTimelineProjectGroups(timelineTasks);
    final displayRows = _timelineRowsFromGroups(projectGroups);
    final range = _timelineRangeForTasks(timelineTasks);
    final totalDays = range.end.difference(range.start).inDays + 1;
    final monthBands = _timelineMonthBands(range.start, range.end);
    final weekBands = _timelineWeekBands(range.start, range.end);
    final labelWidth = compact ? 220.0 : _kTimelineLabelWidth;
    final todayOffset = _timelineDayOffset(DateTime.now(), range.start);
    final borderColor = theme.dividerColor.withValues(alpha: 0.45);
    final headerHeight = _kTimelineMonthHeaderHeight +
        _kTimelineWeekHeaderHeight +
        _kTimelineDayHeaderHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTimelineToolbar(theme, compact: compact),
        SizedBox(height: AppDimensions.spacingSM),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartAreaWidth = math.max(
                0.0,
                constraints.maxWidth - labelWidth,
              );
              final fitDayWidth = chartAreaWidth / totalDays;
              final dayWidth = (fitDayWidth * _timelineZoom).clamp(
                _kTimelineMinDayWidth,
                _kTimelineMaxDayWidth * _kTimelineMaxZoom,
              );
              final chartWidth = math.max(chartAreaWidth, totalDays * dayWidth);
              final needsHorizontalScroll = chartWidth > chartAreaWidth + 1;

              Widget buildChartHeader() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _kTimelineMonthHeaderHeight,
                      child: Row(
                        children: monthBands.map((band) {
                          return _buildTimelineMonthBandHeader(
                            theme,
                            band,
                            dayWidth,
                            borderColor,
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(
                      height: _kTimelineWeekHeaderHeight,
                      child: Row(
                        children: weekBands.map((band) {
                          return _buildTimelineWeekBandHeader(
                            theme,
                            band,
                            dayWidth,
                            borderColor,
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(
                      height: _kTimelineDayHeaderHeight,
                      child: _buildTimelineDayHeaderRow(
                        theme,
                        range,
                        totalDays,
                        dayWidth,
                        todayOffset,
                        borderColor,
                      ),
                    ),
                  ],
                );
              }

              Widget buildChartBody() {
                return Column(
                  children: displayRows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    if (row.isHeader) {
                      return SizedBox(
                        height: _kTimelineProjectHeaderHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildTimelineGrid(
                              theme,
                              range,
                              totalDays,
                              dayWidth: dayWidth,
                              todayOffset: todayOffset,
                            ),
                            if (todayOffset >= 0 && todayOffset < totalDays)
                              Positioned(
                                left:
                                    todayOffset * dayWidth + (dayWidth / 2) - 1,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 2,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    final task = row.task!;
                    return Container(
                      height: _kTimelineRowHeight,
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? theme.colorScheme.surface
                            : theme.colorScheme.surfaceContainerLowest
                                  .withValues(alpha: 0.55),
                        border: Border(
                          bottom: BorderSide(
                            color: borderColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildTimelineGrid(
                            theme,
                            range,
                            totalDays,
                            dayWidth: dayWidth,
                            todayOffset: todayOffset,
                          ),
                          if (todayOffset >= 0 && todayOffset < totalDays)
                            Positioned(
                              left:
                                  todayOffset * dayWidth + (dayWidth / 2) - 1,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: AppColors.primary.withValues(alpha: 0.55),
                              ),
                            ),
                          _buildTimelineBar(
                            theme,
                            task,
                            range.start,
                            dayWidth: dayWidth,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshTasksWorkspace,
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  clipBehavior: Clip.antiAlias,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusXL),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: headerHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: labelWidth,
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppDimensions.paddingMD,
                                ),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  border: Border(
                                    right: BorderSide(color: borderColor),
                                    bottom: BorderSide(color: borderColor),
                                  ),
                                ),
                                child: Text(
                                  context.tr('Projects'),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: context.mic.textSecondary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: borderColor),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    controller: _timelineHeaderScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: needsHorizontalScroll
                                        ? const ClampingScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: chartWidth,
                                      child: buildChartHeader(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: labelWidth,
                                child: ListView.builder(
                                  controller:
                                      _timelineLabelsVerticalScrollController,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: displayRows.length,
                                  itemBuilder: (context, index) {
                                    final row = displayRows[index];
                                    if (row.isHeader) {
                                      return _buildTimelineProjectHeaderLabel(
                                        theme,
                                        row.projectTitle!,
                                        row.taskCount!,
                                        borderColor,
                                      );
                                    }
                                    return _buildTimelineTaskLabel(
                                      theme,
                                      row.task!,
                                      index,
                                      borderColor,
                                    );
                                  },
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller:
                                      _timelineBodyVerticalScrollController,
                                  physics: const ClampingScrollPhysics(),
                                  child: SingleChildScrollView(
                                    controller: _timelineBodyScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: needsHorizontalScroll
                                        ? const ClampingScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    child: SizedBox(
                                      width: chartWidth,
                                      child: buildChartBody(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineToolbar(ThemeData theme, {bool compact = false}) {
    final zoomPercent = (_timelineZoom * 100).round();

    return Row(
      children: [
        Icon(
          Icons.view_timeline_outlined,
          size: 18,
          color: context.mic.textSecondary,
        ),
        SizedBox(width: AppDimensions.spacingSM),
        Text(
          context.tr('Timeline'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          '$zoomPercent%',
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.mic.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: AppDimensions.spacingSM),
        IconButton(
          tooltip: context.tr('Zoom out'),
          onPressed: _timelineZoom <= _kTimelineMinZoom
              ? null
              : () => setState(() {
                  _timelineZoom = math.max(
                    _kTimelineMinZoom,
                    _timelineZoom - _kTimelineZoomStep,
                  );
                }),
          icon: const Icon(Icons.zoom_out_map, size: 20),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: context.tr('Fit to width'),
          onPressed: () => setState(() => _timelineZoom = 1.0),
          icon: const Icon(Icons.fit_screen, size: 20),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: context.tr('Zoom in'),
          onPressed: _timelineZoom >= _kTimelineMaxZoom
              ? null
              : () => setState(() {
                  _timelineZoom = math.min(
                    _kTimelineMaxZoom,
                    _timelineZoom + _kTimelineZoomStep,
                  );
                }),
          icon: const Icon(Icons.zoom_in_map, size: 20),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  List<_TimelineProjectGroup> _collectTimelineProjectGroups(
    List<Map<String, dynamic>> tasks,
  ) {
    final groups = <_TimelineProjectGroup>[];
    final sortedProjects = [..._projects];
    sortedProjects.sort((a, b) {
      final aDate = DateTime.tryParse(a['end_date']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['end_date']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    for (final project in sortedProjects) {
      final id = project['id']?.toString();
      if (id == null) continue;
      final projectTasks =
          tasks.where((task) => _taskProjectId(task) == id).toList();
      if (projectTasks.isEmpty) continue;
      projectTasks.sort(
        (a, b) => _timelineTaskStart(a).compareTo(_timelineTaskStart(b)),
      );
      groups.add(
        _TimelineProjectGroup(
          title:
              project['title']?.toString() ?? context.tr('Untitled project'),
          tasks: projectTasks,
        ),
      );
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
      noProjectTasks.sort(
        (a, b) => _timelineTaskStart(a).compareTo(_timelineTaskStart(b)),
      );
      groups.add(
        _TimelineProjectGroup(
          title: context.tr('No project'),
          tasks: noProjectTasks,
        ),
      );
    }

    return groups;
  }

  List<_TimelineDisplayRow> _timelineRowsFromGroups(
    List<_TimelineProjectGroup> groups,
  ) {
    final rows = <_TimelineDisplayRow>[];
    for (final group in groups) {
      if (group.tasks.isEmpty) continue;
      rows.add(
        _TimelineDisplayRow.header(
          projectTitle: group.title,
          taskCount: group.tasks.length,
        ),
      );
      for (final task in group.tasks) {
        rows.add(_TimelineDisplayRow.task(task));
      }
    }
    return rows;
  }

  List<_TimelineMonthBand> _timelineMonthBands(DateTime start, DateTime end) {
    final bands = <_TimelineMonthBand>[];
    var cursor = start;
    var monthIndex = 0;

    while (!cursor.isAfter(end)) {
      final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
      final visibleEnd = monthEnd.isAfter(end) ? end : monthEnd;
      final dayCount = visibleEnd.difference(cursor).inDays + 1;
      bands.add(
        _TimelineMonthBand(
          start: cursor,
          end: visibleEnd,
          dayCount: dayCount,
          monthIndex: monthIndex,
        ),
      );
      cursor = visibleEnd.add(const Duration(days: 1));
      monthIndex++;
    }

    return bands;
  }

  Widget _buildTimelineMonthBandHeader(
    ThemeData theme,
    _TimelineMonthBand band,
    double dayWidth,
    Color borderColor,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final width = band.dayCount * dayWidth;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingSM),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: band.monthIndex.isEven
            ? AppColors.primary.withValues(alpha: 0.1)
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.35),
        border: Border(
          right: BorderSide(color: borderColor, width: 1.5),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        DateFormat.yMMMM(locale).format(band.start),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTimelineProjectHeaderLabel(
    ThemeData theme,
    String projectTitle,
    int taskCount,
    Color borderColor,
  ) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.07),
      child: Container(
        height: _kTimelineProjectHeaderHeight,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Text(
                projectTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingSM,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              child: Text(
                '$taskCount',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncTimelineLabelsToChart() {
    _syncTimelineVerticalScroll(
      source: _timelineBodyVerticalScrollController,
      target: _timelineLabelsVerticalScrollController,
    );
  }

  void _syncTimelineChartToLabels() {
    _syncTimelineVerticalScroll(
      source: _timelineLabelsVerticalScrollController,
      target: _timelineBodyVerticalScrollController,
    );
  }

  void _syncTimelineVerticalScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_isSyncingTimelineVerticalScroll ||
        !source.hasClients ||
        !target.hasClients) {
      return;
    }
    _isSyncingTimelineVerticalScroll = true;
    target.jumpTo(source.offset);
    _isSyncingTimelineVerticalScroll = false;
  }

  Widget _buildTimelineTaskLabel(
    ThemeData theme,
    Map<String, dynamic> task,
    int index,
    Color borderColor,
  ) {
    final taskId = task['id']?.toString() ?? '';
    final status = task['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final due = _taskDueDate(task);
    final dueText = due != null ? _formatDate(due) : '—';

    return SizedBox(
      height: _kTimelineRowHeight,
      child: Material(
        color: index.isEven
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.55),
        child: InkWell(
          onTap: taskId.isEmpty ? null : () => _openTaskDetail(taskId),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.spacingSM,
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor.withValues(alpha: 0.35)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task['title']?.toString() ??
                            context.tr('Untitled task'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_getAssignedMemberDisplay(task)} · $dueText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildTimelineWeekBandHeader(
    ThemeData theme,
    _TimelineWeekBand band,
    double dayWidth,
    Color borderColor,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final width = band.dayCount * dayWidth;
    final isEvenWeek = band.weekIndex.isEven;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingSM),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: isEvenWeek
            ? theme.colorScheme.primary.withValues(alpha: 0.06)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border(
          right: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: Text(
        '${DateFormat('d MMM', locale).format(band.start)} – ${DateFormat('d MMM', locale).format(band.end)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: context.mic.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTimelineDayHeaderRow(
    ThemeData theme,
    ({DateTime start, DateTime end}) range,
    int totalDays,
    double dayWidth,
    int todayOffset,
    Color borderColor,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final weekdayFormat = DateFormat('EEE', locale);

    return Row(
      children: List.generate(totalDays, (index) {
        final day = range.start.add(Duration(days: index));
        final isToday = index == todayOffset;
        final isWeekend =
            day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
        final isWeekStart = day.weekday == DateTime.monday;
        final weekIndex = _timelineWeekIndex(day, range.start);

        return Container(
          width: dayWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.12)
                : weekIndex.isEven
                ? theme.colorScheme.primary.withValues(alpha: 0.03)
                : isWeekend
                ? theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35)
                : null,
            border: Border(
              left: isWeekStart
                  ? BorderSide(color: borderColor, width: 1.5)
                  : BorderSide.none,
              right: BorderSide(color: borderColor.withValues(alpha: 0.35)),
              bottom: BorderSide(color: borderColor.withValues(alpha: 0.35)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayFormat.format(day),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isToday
                      ? AppColors.primary
                      : context.mic.textSecondary,
                ),
              ),
              Text(
                '${day.day}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isToday
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Map<String, dynamic>> _timelineTasksWithDates(
    List<Map<String, dynamic>> tasks,
  ) {
    final dated = tasks.where((task) {
      return _taskCreatedDate(task) != null || _taskDueDate(task) != null;
    }).toList();

    dated.sort((a, b) {
      final aStart = _timelineTaskStart(a);
      final bStart = _timelineTaskStart(b);
      return aStart.compareTo(bStart);
    });
    return dated;
  }

  ({DateTime start, DateTime end}) _timelineRangeForTasks(
    List<Map<String, dynamic>> tasks,
  ) {
    DateTime? minDate;
    DateTime? maxDate;

    for (final task in tasks) {
      final start = _timelineTaskStart(task);
      final end = _timelineTaskEnd(task);
      if (minDate == null || start.isBefore(minDate)) minDate = start;
      if (maxDate == null || end.isAfter(maxDate)) maxDate = end;
    }

    final start = _timelineWeekStart(minDate!);
    final end = _timelineWeekEnd(_dateOnly(maxDate!));
    return (start: start, end: end);
  }

  DateTime _timelineWeekStart(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

  DateTime _timelineWeekEnd(DateTime date) =>
      _timelineWeekStart(date).add(const Duration(days: 6));

  int _timelineWeekIndex(DateTime day, DateTime rangeStart) {
    return day.difference(_timelineWeekStart(rangeStart)).inDays ~/ 7;
  }

  List<_TimelineWeekBand> _timelineWeekBands(DateTime start, DateTime end) {
    final bands = <_TimelineWeekBand>[];
    var weekStart = _timelineWeekStart(start);
    var weekIndex = 0;

    while (!weekStart.isAfter(end)) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final visibleStart = weekStart.isBefore(start) ? start : weekStart;
      final visibleEnd = weekEnd.isAfter(end) ? end : weekEnd;
      final dayCount = visibleEnd.difference(visibleStart).inDays + 1;
      bands.add(
        _TimelineWeekBand(
          start: visibleStart,
          end: visibleEnd,
          dayCount: dayCount,
          weekIndex: weekIndex,
        ),
      );
      weekStart = weekStart.add(const Duration(days: 7));
      weekIndex++;
    }

    return bands;
  }

  DateTime _timelineTaskStart(Map<String, dynamic> task) {
    final created = _taskCreatedDate(task);
    final due = _taskDueDate(task);
    if (created != null) return _dateOnly(created);
    if (due != null) return _dateOnly(due.subtract(const Duration(days: 7)));
    return _dateOnly(DateTime.now());
  }

  DateTime _timelineTaskEnd(Map<String, dynamic> task) {
    final due = _taskDueDate(task);
    final created = _taskCreatedDate(task);
    if (due != null) return _dateOnly(due);
    if (created != null) return _dateOnly(created.add(const Duration(days: 7)));
    return _dateOnly(DateTime.now());
  }

  DateTime? _taskCreatedDate(Map<String, dynamic> task) {
    final value = task['created_at']?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int _timelineDayOffset(DateTime date, DateTime rangeStart) {
    return _dateOnly(date).difference(rangeStart).inDays;
  }

  Widget _buildTimelineGrid(
    ThemeData theme,
    ({DateTime start, DateTime end}) range,
    int totalDays, {
    required double dayWidth,
    required int todayOffset,
  }) {
    final borderColor = theme.dividerColor.withValues(alpha: 0.45);

    return Row(
      children: List.generate(totalDays, (index) {
        final day = range.start.add(Duration(days: index));
        final isToday = index == todayOffset;
        final isWeekend =
            day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
        final isWeekStart = day.weekday == DateTime.monday;
        final weekIndex = _timelineWeekIndex(day, range.start);

        return Container(
          width: dayWidth,
          decoration: BoxDecoration(
            border: Border(
              left: isWeekStart
                  ? BorderSide(color: borderColor, width: 1.5)
                  : BorderSide.none,
              right: BorderSide(color: borderColor.withValues(alpha: 0.25)),
            ),
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.1)
                : weekIndex.isEven
                ? theme.colorScheme.primary.withValues(alpha: 0.03)
                : isWeekend
                ? theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.25)
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildTimelineBar(
    ThemeData theme,
    Map<String, dynamic> task,
    DateTime rangeStart, {
    required double dayWidth,
  }) {
    final start = _timelineTaskStart(task);
    final end = _timelineTaskEnd(task);
    final normalizedEnd = end.isBefore(start) ? start : end;
    final left = _timelineDayOffset(start, rangeStart) * dayWidth + 6;
    final daySpan = normalizedEnd.difference(start).inDays + 1;
    final width = (daySpan * dayWidth - 12).clamp(20.0, double.infinity);
    final status = task['status']?.toString() ?? 'pending';
    final color = _getStatusColor(status);
    final taskId = task['id']?.toString() ?? '';
    final title = task['title']?.toString().trim().isEmpty == true
        ? context.tr('Untitled task')
        : task['title']?.toString().trim() ?? context.tr('Untitled task');
    final showTitle = width >= 72;

    return Positioned(
      left: left,
      top: 12,
      child: GestureDetector(
        onTap: taskId.isEmpty ? null : () => _openTaskDetail(taskId),
        child: Container(
          width: width,
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingSM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.9),
                color.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            showTitle ? title : context.l10n.statusLabel(status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
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
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not update task status'),
      );
    }
  }

  Future<void> _refreshTasksWorkspace() async {
    await Future.wait([_loadTasks(), _loadDesktopMeta()]);
  }

  Future<void> _updateTaskInlineField(
    Map<String, dynamic> task,
    Map<String, dynamic> updates, {
    void Function()? applyLocal,
    void Function()? revertLocal,
  }) async {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) return;

    applyLocal?.call();
    try {
      await TaskService.updateTask(taskId: taskId, updates: updates);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      revertLocal?.call();
      setState(() {});
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not update task'),
      );
    }
  }

  Future<void> _updateTaskTitleInline(Map<String, dynamic> task, String value) {
    final previous = task['title']?.toString() ?? '';
    return _updateTaskInlineField(
      task,
      {'title': value.isEmpty ? context.tr('Untitled task') : value},
      applyLocal: () => task['title'] = value,
      revertLocal: () => task['title'] = previous,
    );
  }

  Future<void> _updateTaskDescriptionInline(
    Map<String, dynamic> task,
    String value,
  ) {
    final previous = task['description']?.toString();
    return _updateTaskInlineField(
      task,
      {'description': value.isEmpty ? null : value},
      applyLocal: () => task['description'] = value.isEmpty ? null : value,
      revertLocal: () => task['description'] = previous,
    );
  }

  Future<void> _updateTaskStatusInline(
    Map<String, dynamic> task,
    String status,
  ) async {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) return;
    if (task['status']?.toString() == status) return;

    final previousStatus = task['status'];
    setState(() => task['status'] = status);
    try {
      await TaskService.updateTask(taskId: taskId, updates: {'status': status});
    } catch (e) {
      if (!mounted) return;
      setState(() => task['status'] = previousStatus);
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not update task status'),
      );
    }
  }

  Future<void> _updateTaskDueDateInline(
    Map<String, dynamic> task,
    DateTime? dueDate,
  ) {
    final previous = task['due_date']?.toString();
    final iso = dueDate?.toIso8601String().split('T').first;
    return _updateTaskInlineField(
      task,
      {'due_date': iso},
      applyLocal: () => task['due_date'] = iso,
      revertLocal: () => task['due_date'] = previous,
    );
  }

  Future<void> _updateTaskAssigneeInline(
    Map<String, dynamic> task,
    String? memberId,
  ) async {
    final taskId = task['id']?.toString();
    if (taskId == null || taskId.isEmpty) return;

    final currentMember = _getPrimaryAssignedMember(task);
    final currentId = currentMember?['id']?.toString();
    if (currentId == memberId) return;

    try {
      if (currentId != null) {
        await TaskService.removeAssignment(
          taskId: taskId,
          memberId: currentId,
        );
      }
      if (memberId != null && memberId.isNotEmpty) {
        await TaskService.assignTask(taskId: taskId, memberId: memberId);
      }
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not update assignment'),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _tagsForTask(
    Map<String, dynamic> task,
  ) async {
    final deptId =
        task['department_id']?.toString() ?? widget.departmentId;
    if (deptId == null) return _tags;
    if (widget.departmentId == deptId && _tags.isNotEmpty) return _tags;
    return TagService.getTags(departmentId: deptId, limit: 500);
  }

  Future<void> _updateTaskTagInline(
    Map<String, dynamic> task,
    String? tagId,
  ) async {
    final taskId = task['id']?.toString();
    if (taskId == null) return;

    try {
      await TaskService.setTaskTags(
        taskId: taskId,
        tagIds: tagId == null ? [] : [tagId],
      );
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Could not update tags'),
      );
    }
  }

  Future<String?> _createTagForTaskDepartment(
    Map<String, dynamic> task,
    String name, {
    String? color,
  }) async {
    final deptId =
        task['department_id']?.toString() ?? widget.departmentId;
    if (deptId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('Task has no department; cannot add tags'),
            ),
          ),
        );
      }
      return null;
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final tags = await _tagsForTask(task);
    final existing = tags.where(
      (tag) =>
          tag['name']?.toString().toLowerCase() == trimmed.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return existing.first['id']?.toString();
    }

    final created = await TagService.createTag(
      name: trimmed,
      departmentId: deptId,
      color: color ?? TagColors.defaultHex,
    );
    if (widget.departmentId == deptId) {
      setState(() => _tags = [..._tags, created]);
    }
    return created['id']?.toString();
  }

  Future<void> _showAnchoredMenu<T>(
    BuildContext anchorContext,
    List<PopupMenuEntry<T>> items,
    Future<void> Function(T value) onSelected,
  ) async {
    final renderBox = anchorContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final selected = await showMenu<T>(
      context: anchorContext,
      position: _popupPositionForCell(anchorContext, renderBox),
      items: items,
    );
    if (selected != null) await onSelected(selected);
  }

  RelativeRect _popupPositionForCell(
    BuildContext anchorContext,
    RenderBox renderBox,
  ) {
    final overlay =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + renderBox.size.height,
      offset.dx + renderBox.size.width,
      offset.dy + renderBox.size.height + 240,
    );
  }

  Future<void> _showStatusPicker(
    BuildContext anchorContext,
    Map<String, dynamic> task,
  ) {
    const statuses = ['pending', 'in_progress', 'completed', 'cancelled'];
    return _showAnchoredMenu<String>(
      anchorContext,
      statuses
          .map(
            (status) => PopupMenuItem<String>(
              value: status,
              child: Text(context.l10n.statusLabel(status)),
            ),
          )
          .toList(),
      (status) => _updateTaskStatusInline(task, status),
    );
  }

  Future<void> _showAssigneePicker(
    BuildContext anchorContext,
    Map<String, dynamic> task,
  ) async {
    final departmentId =
        task['department_id']?.toString() ?? widget.departmentId;
    if (departmentId == null || departmentId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Task must be assigned to a department first'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final departmentMembers = await DepartmentService.getDepartmentMembers(
        departmentId,
      );
      final members = departmentMembers
          .map((row) => row['members'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
      final membersWithPenalties =
          await TaskPenaltyService.annotateMembersWithPenalties(members);

      if (!mounted || !anchorContext.mounted) return;
      if (membersWithPenalties.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('No members found in this department'),
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final currentMember = _getPrimaryAssignedMember(task);
      final selectedMemberId = await showTaskTableAnchoredPopup<String>(
        anchorContext: anchorContext,
        child: TaskAssigneePickerPanel(
          members: membersWithPenalties,
          currentMemberId: currentMember?['id']?.toString(),
        ),
      );

      if (selectedMemberId == null) return;
      await _updateTaskAssigneeInline(
        task,
        selectedMemberId.isEmpty ? null : selectedMemberId,
      );
    } catch (e) {
      if (!mounted) return;
      ErrorMessageHelper.showErrorSnackBar(
        context,
        e,
        title: context.tr('Error loading members'),
      );
    }
  }

  Future<void> _pickTaskDueDate(
    BuildContext anchorContext,
    Map<String, dynamic> task,
  ) async {
    final current = _taskDueDate(task);
    final initial = current ?? DateTime.now();
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 2));
    final lastDate = DateTime.now().add(const Duration(days: 365 * 3));

    final picked = await showTaskTableAnchoredPopup<DateTime>(
      anchorContext: anchorContext,
      width: 328,
      child: Builder(
        builder: (popupContext) => SizedBox(
          height: 340,
          child: CalendarDatePicker(
            initialDate: initial.isBefore(firstDate)
                ? firstDate
                : initial.isAfter(lastDate)
                ? lastDate
                : initial,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: (date) => Navigator.of(popupContext).pop(date),
          ),
        ),
      ),
    );
    if (picked == null) return;
    await _updateTaskDueDateInline(task, picked);
  }

  Future<void> _showTagPicker(
    BuildContext anchorContext,
    Map<String, dynamic> task,
  ) async {
    final tags = await _tagsForTask(task);
    final firstTag = _getTaskFirstTag(task);
    final currentTagId = firstTag?['id']?.toString();

    if (!mounted || !anchorContext.mounted) return;
    final selected = await showTaskTableAnchoredPopup<TaskTagPickerResult>(
      anchorContext: anchorContext,
      child: TaskTagPickerPanel(
        tags: tags,
        currentTagId: currentTagId,
      ),
    );

    if (selected == null) return;
    if (selected.isCreate) {
      final tagId = await _createTagForTaskDepartment(
        task,
        selected.name ?? '',
        color: selected.color,
      );
      if (tagId != null) {
        await _updateTaskTagInline(task, tagId);
      }
      return;
    }
    await _updateTaskTagInline(
      task,
      (selected.tagId == null || selected.tagId!.isEmpty)
          ? null
          : selected.tagId,
    );
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
          child: _buildWorkspaceContent(theme, filteredTasks, compact: true),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(ThemeData theme, int openTasks, int overdueTasks) {
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
      (Icons.folder_outlined, context.tr('Projects'), _openManageProjects),
      (Icons.label_outlined, context.tr('Tags'), _openManageTags),
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
      addChip(project['title']?.toString() ?? context.tr('Project'), () {
        setState(() => _selectedProjectId = null);
        _loadTasks();
      });
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

  void _resizeTaskTableColumn(int columnIndex, double delta) {
    setState(() {
      final next = _taskTableColumnWidths[columnIndex] + delta;
      _taskTableColumnWidths[columnIndex] = next.clamp(
        _kTaskTableMinColumnWidth,
        _kTaskTableMaxColumnWidth,
      );
    });
  }

  double get _taskTableTotalWidth =>
      _taskTableColumnWidths.fold<double>(0, (sum, width) => sum + width);

  Color _taskTableBorderColor(ThemeData theme) =>
      theme.dividerColor.withValues(alpha: 0.75);

  void _toggleTaskTableSort(int columnIndex) {
    if (columnIndex >= 6) return;
    setState(() {
      if (_taskTableSortColumnIndex == columnIndex) {
        _taskTableSortAscending = !_taskTableSortAscending;
      } else {
        _taskTableSortColumnIndex = columnIndex;
        _taskTableSortAscending = true;
      }
    });
  }

  int _compareTaskTableValues(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    int columnIndex,
  ) {
    switch (columnIndex) {
      case 0:
        return _compareTaskTableStrings(
          a['title']?.toString().trim(),
          b['title']?.toString().trim(),
        );
      case 1:
        return _compareTaskTableStatus(
          a['status']?.toString(),
          b['status']?.toString(),
        );
      case 2:
        return _compareTaskTableStrings(
          _getAssignedMemberDisplay(a),
          _getAssignedMemberDisplay(b),
        );
      case 3:
        return _compareTaskTableDates(_taskDueDate(a), _taskDueDate(b));
      case 4:
        return _compareTaskTableStrings(
          _getTaskFirstTag(a)?['name']?.toString(),
          _getTaskFirstTag(b)?['name']?.toString(),
        );
      case 5:
        return _compareTaskTableStrings(
          a['description']?.toString().trim(),
          b['description']?.toString().trim(),
        );
      default:
        return 0;
    }
  }

  int _compareTaskTableStrings(String? a, String? b) {
    final left = (a == null || a.isEmpty || a == '—') ? '' : a.toLowerCase();
    final right = (b == null || b.isEmpty || b == '—') ? '' : b.toLowerCase();
    return left.compareTo(right);
  }

  int _compareTaskTableStatus(String? a, String? b) {
    final left = _taskStatusSortOrder[a ?? 'pending'] ?? 99;
    final right = _taskStatusSortOrder[b ?? 'pending'] ?? 99;
    return left.compareTo(right);
  }

  int _compareTaskTableDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  List<Map<String, dynamic>> _sortedTasksForTable(
    List<Map<String, dynamic>> tasks,
  ) {
    final columnIndex = _taskTableSortColumnIndex;
    if (columnIndex == null) return tasks;

    final sorted = [...tasks];
    sorted.sort((a, b) {
      final comparison = _compareTaskTableValues(a, b, columnIndex);
      return _taskTableSortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  Widget _buildTasksTableSortIcon(ThemeData theme, int columnIndex) {
    final isActive = _taskTableSortColumnIndex == columnIndex;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      tooltip: isActive
          ? (_taskTableSortAscending
              ? context.tr('Sort descending')
              : context.tr('Sort ascending'))
          : context.tr('Sort'),
      onPressed: () => _toggleTaskTableSort(columnIndex),
      icon: Icon(
        isActive
            ? (_taskTableSortAscending
                ? Icons.arrow_upward
                : Icons.arrow_downward)
            : Icons.unfold_more,
        size: 16,
        color: isActive ? AppColors.primary : context.mic.textSecondary,
      ),
    );
  }

  Widget _buildDesktopResizableTasksTable(
    ThemeData theme,
    List<Map<String, dynamic>> tasks,
  ) {
    return RefreshIndicator(
      onRefresh: _refreshTasksWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [_buildTasksTableContent(theme, tasks)],
      ),
    );
  }

  Widget _buildTasksTableContent(
    ThemeData theme,
    List<Map<String, dynamic>> tasks, {
    bool enableDrag = false,
  }) {
    final borderColor = _taskTableBorderColor(theme);
    final displayTasks = _sortedTasksForTable(tasks);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _taskTableTotalWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTasksTableHeaderRow(theme, borderColor),
            ...displayTasks.map((task) {
              final row = _buildTasksTableDataRow(theme, task, borderColor);
              if (!enableDrag) return row;
              final taskId = task['id']?.toString() ?? '';
              if (taskId.isEmpty) return row;
              final title = task['title']?.toString().trim();
              return Draggable<String>(
                data: taskId,
                feedback: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      (title == null || title.isEmpty)
                          ? context.tr('Untitled task')
                          : title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: row),
                child: row,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTableHeaderRow(ThemeData theme, Color borderColor) {
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: context.mic.textSecondary,
      fontWeight: FontWeight.w800,
    );

    final labels = [
      context.tr('Title'),
      context.tr('Status'),
      context.tr('Assigned'),
      context.tr('Due date'),
      context.tr('Tags'),
      context.tr('Description'),
      context.tr('Actions'),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < labels.length; i++)
            _buildTasksTableGridCell(
              theme: theme,
              width: _taskTableColumnWidths[i],
              borderColor: borderColor,
              isHeader: true,
              showLeftBorder: i == 0,
              showRightBorder: true,
              resizable: i < labels.length - 1,
              columnIndex: i,
              alignment: i == labels.length - 1
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: i == labels.length - 1
                  ? Text(
                      labels[i],
                      style: headerStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels[i],
                            style: headerStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildTasksTableSortIcon(theme, i),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksTableDataRow(
    ThemeData theme,
    Map<String, dynamic> task,
    Color borderColor,
  ) {
    final taskId = task['id']?.toString() ?? '';
    final rawTitle = task['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty ? '' : rawTitle;

    final status = task['status']?.toString() ?? 'pending';
    final statusColor = _getStatusColor(status);
    final statusLabel = context.l10n.statusLabel(status);

    final dueDate = _taskDueDate(task);
    final dueDateText = dueDate != null ? _formatDate(dueDate) : '—';
    final overdue = _isTaskOverdue(task);

    final primaryMember = _getPrimaryAssignedMember(task);
    final memberName = primaryMember == null
        ? '—'
        : '${primaryMember['first_name'] ?? ''} ${primaryMember['last_name'] ?? ''}'
              .trim();
    final initials = _getMemberInitials(primaryMember);

    final firstTag = _getTaskFirstTag(task);
    final tagName = firstTag?['name']?.toString();
    final tagColor = TagColors.colorFromHex(firstTag?['color']?.toString());

    final description = task['description']?.toString().trim() ?? '';
    final canEdit = taskId.isNotEmpty;
    final createdAt = _taskCreatedDate(task);
    final createdText = createdAt != null ? _formatDate(createdAt) : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[0],
            borderColor: borderColor,
            showLeftBorder: true,
            child: TaskTableInlineTextCell(
              text: title,
              hint: context.tr('Untitled task'),
              maxLines: 2,
              enabled: canEdit,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              onCommit: (value) => _updateTaskTitleInline(task, value),
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[1],
            borderColor: borderColor,
            child: Builder(
              builder: (cellContext) => TaskTableTappableCell(
                enabled: canEdit,
                onTap: canEdit
                    ? () => _showStatusPicker(cellContext, task)
                    : null,
                child: _buildDesktopStatusPill(statusLabel, statusColor),
              ),
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[2],
            borderColor: borderColor,
            child: Builder(
              builder: (cellContext) => TaskTableTappableCell(
                enabled: canEdit,
                onTap: canEdit
                    ? () => _showAssigneePicker(cellContext, task)
                    : null,
                child: _buildAssignedCell(theme, memberName, initials),
              ),
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[3],
            borderColor: borderColor,
            child: Builder(
              builder: (cellContext) => TaskTableTappableCell(
                enabled: canEdit,
                onTap: canEdit
                    ? () => _pickTaskDueDate(cellContext, task)
                    : null,
                child: Text(
                  dueDateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: overdue ? AppColors.error : context.mic.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[4],
            borderColor: borderColor,
            child: Builder(
              builder: (cellContext) => TaskTableTappableCell(
                enabled: canEdit,
                onTap: canEdit
                    ? () => _showTagPicker(cellContext, task)
                    : null,
                child: tagName == null || tagName.isEmpty
                    ? Text(
                        context.tr('—'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.mic.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : _buildDesktopTagPill(tagName, color: tagColor),
              ),
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[5],
            borderColor: borderColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TaskTableInlineTextCell(
                  text: description,
                  hint: context.tr('—'),
                  maxLines: 2,
                  enabled: canEdit,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  onCommit: (value) =>
                      _updateTaskDescriptionInline(task, value),
                ),
                if (createdText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.tr('Created {date}', {'date': createdText}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.mic.textSecondary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildTasksTableGridCell(
            theme: theme,
            width: _taskTableColumnWidths[6],
            borderColor: borderColor,
            showRightBorder: true,
            alignment: Alignment.center,
            child: IconButton(
              tooltip: context.tr('Details'),
              visualDensity: VisualDensity.compact,
              onPressed: canEdit ? () => _openTaskDetail(taskId) : null,
              icon: Icon(
                Icons.open_in_new,
                size: 18,
                color: canEdit
                    ? context.mic.textSecondary
                    : context.mic.textSecondary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTableGridCell({
    required ThemeData theme,
    required double width,
    required Color borderColor,
    required Widget child,
    bool isHeader = false,
    bool showLeftBorder = false,
    bool showRightBorder = false,
    bool resizable = false,
    int? columnIndex,
    VoidCallback? onTap,
    Alignment alignment = Alignment.centerLeft,
    EdgeInsetsGeometry? padding,
  }) {
    final cell = Container(
      width: width,
      constraints: BoxConstraints(minHeight: isHeader ? 44 : 52),
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.spacingSM,
          ),
      decoration: BoxDecoration(
        color: isHeader ? null : theme.colorScheme.surface,
        border: Border(
          left: showLeftBorder
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          right: showRightBorder || !isHeader
              ? BorderSide(color: borderColor)
              : BorderSide.none,
          bottom: isHeader ? BorderSide.none : BorderSide(color: borderColor),
        ),
      ),
      alignment: alignment,
      child: child,
    );

    Widget content = cell;
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: cell),
      );
    }

    if (!resizable || columnIndex == null) return content;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          top: 0,
          right: -_kTaskTableResizeHandleWidth / 2,
          bottom: 0,
          width: _kTaskTableResizeHandleWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              _resizeTaskTableColumn(columnIndex, details.delta.dx);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedCell(
    ThemeData theme,
    String memberName,
    String initials,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
        SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Text(
            memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatusPill(String label, Color color) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88, maxWidth: 130),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM,
          vertical: AppDimensions.spacingXS,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTagPill(String label, {required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSM,
        vertical: AppDimensions.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Map<String, dynamic>? _getPrimaryAssignedMember(Map<String, dynamic> task) {
    final assignments = task['task_assignments'];
    if (assignments is! List || assignments.isEmpty) return null;

    for (final a in assignments) {
      if (a is! Map) continue;
      final members = a['members'];
      if (members is Map<String, dynamic>) return members;
      if (members is Map) return Map<String, dynamic>.from(members);
    }
    return null;
  }

  Map<String, dynamic>? _getTaskFirstTag(Map<String, dynamic> task) {
    final taskTags = task['task_tags'];
    if (taskTags is! List || taskTags.isEmpty) return null;

    final first = taskTags.first;
    if (first is! Map) return null;

    final tags = first['tags'];
    if (tags is Map) return Map<String, dynamic>.from(tags);
    return null;
  }

  String _getMemberInitials(Map<String, dynamic>? member) {
    if (member == null) return '';
    final first = member['first_name']?.toString().trim() ?? '';
    final last = member['last_name']?.toString().trim() ?? '';
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    final initials = (a + b).trim();
    return initials.isEmpty ? '?' : initials;
  }
}

class _TimelineMonthBand {
  _TimelineMonthBand({
    required this.start,
    required this.end,
    required this.dayCount,
    required this.monthIndex,
  });

  final DateTime start;
  final DateTime end;
  final int dayCount;
  final int monthIndex;
}

class _TimelineWeekBand {
  _TimelineWeekBand({
    required this.start,
    required this.end,
    required this.dayCount,
    required this.weekIndex,
  });

  final DateTime start;
  final DateTime end;
  final int dayCount;
  final int weekIndex;
}

class _TimelineProjectGroup {
  _TimelineProjectGroup({required this.title, required this.tasks});

  final String title;
  final List<Map<String, dynamic>> tasks;
}

class _TimelineDisplayRow {
  const _TimelineDisplayRow.header({
    required this.projectTitle,
    required this.taskCount,
  })  : isHeader = true,
        task = null;

  const _TimelineDisplayRow.task(this.task)
      : isHeader = false,
        projectTitle = null,
        taskCount = null;

  final bool isHeader;
  final String? projectTitle;
  final int? taskCount;
  final Map<String, dynamic>? task;
}

class _TaskProjectGroup {
  _TaskProjectGroup({
    required this.title,
    required this.tasks,
    this.projectId,
    this.endDateText,
  });

  final String? projectId;
  final String title;
  final String? endDateText;
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
