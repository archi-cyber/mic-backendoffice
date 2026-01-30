import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/task_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Tasks list (department-scoped)
class TasksListPage extends StatefulWidget {
  final String? departmentId;
  final bool hideAppBarAndBottomNav;

  const TasksListPage({
    super.key,
    this.departmentId,
    this.hideAppBarAndBottomNav = false,
  });

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

const double _kTasksDesktopBreakpoint = 700;
const double _kTasksDesktopMaxWidth = 1000;
const int _kTasksRowsPerPage = 10;

class _TasksListPageState extends State<TasksListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _selectedStatus;
  String? _selectedPriority;
  bool _canCreate = false;
  int _tasksPage = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadTasks();
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
        _tasksPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tasks: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    final query = _searchController.text.toLowerCase();
    var filtered = _tasks;

    if (query.isNotEmpty) {
      filtered = filtered
          .where(
            (task) =>
                (task['title']?.toString().toLowerCase().contains(query) ??
                    false) ||
                (task['description']?.toString().toLowerCase().contains(
                      query,
                    ) ??
                    false),
          )
          .toList();
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

    return filtered;
  }

  int get _totalTasksPages {
    if (_filteredTasks.isEmpty) return 1;
    return (_filteredTasks.length / _kTasksRowsPerPage).ceil();
  }

  List<Map<String, dynamic>> get _paginatedTasks {
    final start = _tasksPage * _kTasksRowsPerPage;
    final end = (start + _kTasksRowsPerPage).clamp(0, _filteredTasks.length);
    if (start >= _filteredTasks.length) return [];
    return _filteredTasks.sublist(start, end);
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
          title: const Text('Filter Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.check_circle),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('In Progress'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _selectedStatus = value;
                  });
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Priorities')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    _selectedPriority = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedStatus = null;
                  _selectedPriority = null;
                });
              },
              child: const Text('Clear Filters'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
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
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
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

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.hideAppBarAndBottomNav &&
        MediaQuery.sizeOf(context).width >= _kTasksDesktopBreakpoint;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: const Text('Tasks'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilters,
                  tooltip: 'Filter',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTasks,
                  tooltip: 'Refresh',
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
                if (!canCreate) return const SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: () async {
                    final scope = DesktopShellScope.maybeOf(context);
                    if (scope != null) {
                      scope.pushDetail(RouteNames.addTask, '');
                    } else {
                      final result = await Navigator.of(context).pushNamed(
                        RouteNames.addTask,
                        arguments: widget.departmentId,
                      );
                      if (result == true) _loadTasks();
                    }
                  },
                  child: const Icon(Icons.add),
                );
              },
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kTasksDesktopMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search tasks...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => setState(() => _tasksPage = 0),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMD),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showFilters,
                    tooltip: 'Filter',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _isLoading ? null : _loadTasks,
                    tooltip: 'Refresh',
                  ),
                  const Spacer(),
                  if (_canCreate)
                    FilledButton.icon(
                      onPressed: () {
                        final scope = DesktopShellScope.maybeOf(context);
                        if (scope != null) {
                          scope.pushDetail(RouteNames.addTask, '');
                        } else {
                          Navigator.of(context)
                              .pushNamed(
                                RouteNames.addTask,
                                arguments: widget.departmentId,
                              )
                              .then((result) {
                                if (result == true) _loadTasks();
                              });
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Task'),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.task_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              _searchController.text.isNotEmpty ||
                                      _selectedStatus != null ||
                                      _selectedPriority != null
                                  ? 'No tasks found'
                                  : 'No tasks yet',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme.surfaceContainerHighest,
                              ),
                              columns: const [
                                DataColumn(label: Text('Title')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Priority')),
                                DataColumn(label: Text('Due Date')),
                                DataColumn(label: Text('Department')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _paginatedTasks.map((task) {
                                final id = task['id']?.toString() ?? '';
                                final title =
                                    task['title']?.toString() ?? 'Task';
                                final status =
                                    task['status']?.toString() ?? '—';
                                final priority =
                                    task['priority']?.toString() ?? '—';
                                final dueStr = task['due_date'];
                                final dueFormatted = dueStr != null
                                    ? _formatDate(DateTime.parse(dueStr))
                                    : '—';
                                final deptName =
                                    _getDepartmentName(task) ?? '—';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      InkWell(
                                        onTap: () => _openTaskDetail(id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            title,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        priority,
                                        style: TextStyle(
                                          color: _getPriorityColor(priority),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(dueFormatted)),
                                    DataCell(
                                      Text(
                                        deptName,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _openTaskDetail(id),
                                            child: const Text('View'),
                                          ),
                                          const SizedBox(width: 4),
                                          TextButton(
                                            onPressed: () {
                                              final scope =
                                                  DesktopShellScope.maybeOf(
                                                    context,
                                                  );
                                              if (scope != null) {
                                                scope.pushDetail(
                                                  RouteNames.editTask,
                                                  id,
                                                );
                                              } else {
                                                Navigator.of(context)
                                                    .pushNamed(
                                                      RouteNames.editTask
                                                          .replaceAll(
                                                            ':id',
                                                            id,
                                                          ),
                                                    )
                                                    .then((result) {
                                                      if (result == true)
                                                        _loadTasks();
                                                    });
                                              }
                                            },
                                            child: const Text('Edit'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
              if (_filteredTasks.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rows per page: $_kTasksRowsPerPage',
                      style: theme.textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Text(
                          'Page ${_tasksPage + 1} of $_totalTasksPages',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: AppDimensions.spacingSM),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _tasksPage > 0
                              ? () =>
                                    setState(() => _tasksPage = _tasksPage - 1)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _tasksPage < _totalTasksPages - 1
                              ? () =>
                                    setState(() => _tasksPage = _tasksPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks...',
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
              : _filteredTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.task_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        _searchController.text.isNotEmpty ||
                                _selectedStatus != null ||
                                _selectedPriority != null
                            ? 'No tasks found'
                            : 'No tasks yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = _filteredTasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Unnamed Task';
    final description = task['description']?.toString();
    final status = task['status']?.toString() ?? 'pending';
    final priority = task['priority']?.toString() ?? 'medium';
    final dueDate = task['due_date'] != null
        ? DateTime.parse(task['due_date'])
        : null;
    final taskId = task['id'].toString();
    final departmentName = _getDepartmentName(task);

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
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getPriorityColor(priority).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(priority),
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
              const SizedBox(height: AppDimensions.spacingSM),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                  if (departmentName != null) ...[
                    const SizedBox(width: AppDimensions.spacingSM),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group_work,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            departmentName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (dueDate != null) ...[
                    const Spacer(),
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: dueDate.isBefore(DateTime.now())
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: dueDate.isBefore(DateTime.now())
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: dueDate.isBefore(DateTime.now())
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getDepartmentName(Map<String, dynamic> task) {
    // Check if department info is included in the response
    final department = task['departments'];
    if (department != null) {
      if (department is Map<String, dynamic>) {
        return department['name']?.toString();
      }
    }
    return null;
  }
}
