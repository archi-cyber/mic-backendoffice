import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/task_service.dart';
import '../../services/department_service.dart';
import '../../services/project_service.dart';
import '../../services/tag_service.dart';
import '../../core/constants/tag_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/tag_color_picker.dart';

/// Edit task page
class EditTaskPage extends StatefulWidget {
  final String taskId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  EditTaskPage({super.key, required this.taskId, this.onClose});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyAmountController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedProjectId;
  final List<String> _selectedTagIds = [];
  DateTime? _dueDate;
  String _priority = 'medium';
  String _status = 'pending';
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
  final TextEditingController _newTagController = TextEditingController();
  String _newTagColor = TagColors.presetHex.first;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _penaltyAmountController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  /// Add tag by name: select existing or create if not found.
  Future<void> _addTagByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    Map<String, dynamic>? existing;
    for (final t in _tags) {
      if ((t['name']?.toString().trim().toLowerCase() ?? '') ==
          trimmed.toLowerCase()) {
        existing = t;
        break;
      }
    }
    if (existing != null) {
      final id = existing['id'].toString();
      if (!_selectedTagIds.contains(id)) {
        setState(() => _selectedTagIds.add(id));
      }
      _newTagController.clear();
      return;
    }
    final deptId = _selectedDepartmentId;
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
      return;
    }
    try {
      final created = await TagService.createTag(
        name: trimmed,
        departmentId: deptId,
        color: _newTagColor,
      );
      if (!mounted) return;
      final id = created['id'].toString();
      setState(() {
        _tags.add(created);
        if (!_selectedTagIds.contains(id)) _selectedTagIds.add(id);
        _newTagColor = TagColors.presetHex.first;
      });
      _newTagController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Could not add tag: $e'))),
        );
      }
    }
  }

  Future<void> _loadTagsForDepartment() async {
    final deptId = _selectedDepartmentId;
    if (deptId == null) {
      setState(() => _tags = []);
      return;
    }
    try {
      final tags = await TagService.getTags(departmentId: deptId, limit: 200);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _selectedTagIds.removeWhere(
          (id) => !tags.any((t) => t['id'].toString() == id),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _tags = []);
    }
  }

  List<Map<String, dynamic>> get _filteredProjects {
    final deptId = _selectedDepartmentId;
    if (deptId == null) return [];
    return _projects
        .where((project) => project['department_id']?.toString() == deptId)
        .toList();
  }

  void _onDepartmentChanged(String? departmentId) {
    setState(() {
      _selectedDepartmentId = departmentId;
      if (_selectedProjectId != null) {
        final projectStillValid = _projects.any(
          (project) =>
              project['id']?.toString() == _selectedProjectId &&
              project['department_id']?.toString() == departmentId,
        );
        if (!projectStillValid) {
          _selectedProjectId = null;
        }
      }
    });
    _loadTagsForDepartment();
  }

  List<DropdownMenuItem<String>> _departmentDropdownItems() {
    final items = _departments
        .map(
          (dept) => DropdownMenuItem<String>(
            value: dept['id'].toString(),
            child: Text(dept['name']?.toString() ?? context.tr('Unnamed')),
          ),
        )
        .toList();

    final selectedId = _selectedDepartmentId;
    if (selectedId != null &&
        !items.any((item) => item.value == selectedId)) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: selectedId,
          child: Text(context.tr('Unknown department')),
        ),
      );
    }

    return items;
  }

  List<DropdownMenuItem<String?>> _projectDropdownItems() {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(context.tr('None')),
      ),
      ..._filteredProjects.map(
        (project) => DropdownMenuItem<String?>(
          value: project['id'].toString(),
          child: Text(
            project['title']?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    final selectedId = _selectedProjectId;
    if (selectedId != null &&
        !items.any((item) => item.value == selectedId)) {
      final project = _projects.cast<Map<String, dynamic>?>().firstWhere(
        (project) => project?['id']?.toString() == selectedId,
        orElse: () => null,
      );
      items.insert(
        1,
        DropdownMenuItem<String?>(
          value: selectedId,
          child: Text(
            project?['title']?.toString() ?? context.tr('Unknown project'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return items;
  }

  String? get _effectiveDepartmentDropdownValue {
    final selectedId = _selectedDepartmentId;
    if (selectedId == null) return null;
    return _departmentDropdownItems().any((item) => item.value == selectedId)
        ? selectedId
        : null;
  }

  String? get _effectiveProjectDropdownValue {
    final selectedId = _selectedProjectId;
    if (selectedId == null) return null;
    return _projectDropdownItems().any((item) => item.value == selectedId)
        ? selectedId
        : null;
  }

  static const Set<String> _allowedPriorities = {
    'low',
    'medium',
    'high',
    'urgent',
  };

  static const Set<String> _allowedStatuses = {
    'pending',
    'in_progress',
    'completed',
    'cancelled',
  };

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        TaskService.getTaskById(widget.taskId),
        DepartmentService.getDepartments(limit: 100),
        ProjectService.getProjects(limit: 200),
      ]);

      final task = results[0] as Map<String, dynamic>;
      final departments = results[1] as List<Map<String, dynamic>>;
      final projects = results[2] as List<Map<String, dynamic>>;

      List<Map<String, dynamic>> tags = [];
      final taskDeptId = task['department_id']?.toString();
      if (taskDeptId != null) {
        tags = await TagService.getTags(departmentId: taskDeptId, limit: 200);
      }

      final taskTags = task['task_tags'] as List?;
      final tagIds =
          taskTags
              ?.map(
                (e) => (e is Map && e['tags'] != null)
                    ? (e['tags'] as Map)['id']?.toString()
                    : null,
              )
              .whereType<String>()
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _titleController.text = task['title']?.toString() ?? '';
        _descriptionController.text = task['description']?.toString() ?? '';
        _penaltyAmountController.text =
            task['penalty_amount_per_day']?.toString() ?? '';
        _selectedDepartmentId = task['department_id']?.toString();
        _selectedProjectId = task['project_id']?.toString();
        _selectedTagIds.clear();
        _selectedTagIds.addAll(tagIds);
        _priority = _allowedPriorities.contains(task['priority']?.toString())
            ? task['priority'].toString()
            : 'medium';
        _status = _allowedStatuses.contains(task['status']?.toString())
            ? task['status'].toString()
            : 'pending';

        if (task['due_date'] != null) {
          _dueDate = DateTime.parse(task['due_date']);
        }

        _departments = departments;
        _projects = projects;
        _tags = tags;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading data: $e'))),
        );
        if (widget.onClose != null) {
          widget.onClose!(null);
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(Duration(days: 365)),
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await TaskService.updateTask(
        taskId: widget.taskId,
        updates: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'due_date': _dueDate?.toIso8601String().split('T')[0],
          'priority': _priority,
          'status': _status,
          'penalty_amount_per_day': _penaltyAmountController.text.trim().isEmpty
              ? null
              : int.parse(_penaltyAmountController.text.trim()),
          if (_selectedDepartmentId != null)
            'department_id': _selectedDepartmentId,
          'project_id': _selectedProjectId,
        },
      );

      await TaskService.setTaskTags(
        taskId: widget.taskId,
        tagIds: _selectedTagIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Task updated successfully')),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!(true);
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 1040;

  Widget _buildPenaltyAmountField({bool outlined = false}) {
    return TextFormField(
      controller: _penaltyAmountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: context.tr('Daily penalty amount'),
        prefixIcon: Icon(Icons.payments_outlined),
        helperText: context.tr(
          'Optional. Leave empty to use the department/global default.',
        ),
        border: outlined ? OutlineInputBorder() : null,
      ),
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) return null;
        final amount = int.tryParse(trimmed);
        if (amount == null || amount < 0) {
          return context.tr('Enter a valid amount');
        }
        return null;
      },
    );
  }

  Widget _desktopSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _desktopIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            theme.colorScheme.surface,
          ],
        ),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.edit_note_outlined,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Edit task'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr(
                    'Update the task details, schedule, status, and penalty settings.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onClose != null
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => widget.onClose!(null),
                )
              : null,
          title: Text(context.tr('Edit Task')),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: Icon(useDesktop ? Icons.close : Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: Text(context.tr('Edit Task')),
        actions: useDesktop
            ? [
                TextButton(
                  onPressed: () => widget.onClose != null
                      ? widget.onClose!(null)
                      : Navigator.of(context).pop(),
                  child: Text(context.tr('Cancel')),
                ),
                SizedBox(width: AppDimensions.spacingSM),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.save, size: 20),
                  label: Text(context.tr('Update Task')),
                ),
                SizedBox(width: AppDimensions.paddingMD),
              ]
            : null,
      ),
      backgroundColor: useDesktop
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : null,
      body: useDesktop
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingLG),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _kDesktopMaxWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _desktopIntroCard(context),
                        SizedBox(height: AppDimensions.spacingLG),
                        _desktopSectionCard(
                          context,
                          context.tr('Task details'),
                          Icons.task_alt,
                          [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: context.tr('Task Title *'),
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr('Task title is required');
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText: context.tr('Description'),
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _effectiveDepartmentDropdownValue,
                              decoration: InputDecoration(
                                labelText: context.tr('Department'),
                                prefixIcon: Icon(Icons.group_work),
                                border: OutlineInputBorder(),
                              ),
                              items: _departmentDropdownItems(),
                              onChanged: _onDepartmentChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr('Please select a department');
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            InkWell(
                              onTap: _selectDueDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: context.tr('Due Date'),
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _dueDate != null
                                      ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                      : context.tr('Select due date (optional)'),
                                  style: TextStyle(
                                    color: _dueDate != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(context).hintColor,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            _buildPenaltyAmountField(outlined: true),
                            SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _priority,
                              decoration: InputDecoration(
                                labelText: context.tr('Priority'),
                                prefixIcon: Icon(Icons.flag),
                                border: OutlineInputBorder(),
                              ),
                              items: [
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
                                setState(() => _priority = value ?? 'medium');
                              },
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: InputDecoration(
                                labelText: context.tr('Status'),
                                prefixIcon: Icon(Icons.check_circle),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text(context.tr('Pending')),
                                ),
                                DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text(context.tr('In Progress')),
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
                                setState(() => _status = value ?? 'pending');
                              },
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String?>(
                              initialValue: _effectiveProjectDropdownValue,
                              decoration: InputDecoration(
                                labelText: context.tr('Project (optional)'),
                                prefixIcon: Icon(Icons.folder_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: _projectDropdownItems(),
                              onChanged: (value) {
                                setState(() => _selectedProjectId = value);
                              },
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            Text(
                              context.tr('Tags (optional)'),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newTagController,
                                    decoration: InputDecoration(
                                      hintText: context.tr(
                                        'Type a tag and add',
                                      ),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    textCapitalization: TextCapitalization.none,
                                    onSubmitted: (v) => _addTagByName(v),
                                  ),
                                ),
                                SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: () =>
                                      _addTagByName(_newTagController.text),
                                  icon: Icon(Icons.add),
                                  tooltip: context.tr('Add tag'),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              context.tr('Color'),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            TagColorPicker(
                              selectedHex: _newTagColor,
                              onChanged: (hex) =>
                                  setState(() => _newTagColor = hex),
                              swatchSize: 26,
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _tags.map((tag) {
                                final id = tag['id'].toString();
                                final selected = _selectedTagIds.contains(id);
                                final color = TagColors.colorFromHex(
                                  tag['color']?.toString(),
                                );
                                return FilterChip(
                                  label: Text(tag['name']?.toString() ?? ''),
                                  selected: selected,
                                  backgroundColor: color.withValues(alpha: 0.2),
                                  selectedColor: color.withValues(alpha: 0.4),
                                  checkmarkColor: color,
                                  side: BorderSide(color: color),
                                  onSelected: (v) {
                                    setState(() {
                                      if (v) {
                                        _selectedTagIds.add(id);
                                      } else {
                                        _selectedTagIds.remove(id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: context.tr('Task Title *'),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('Task title is required');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context.tr('Description'),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _effectiveDepartmentDropdownValue,
                      decoration: InputDecoration(
                        labelText: context.tr('Department'),
                        prefixIcon: Icon(Icons.group_work),
                      ),
                      items: _departmentDropdownItems(),
                      onChanged: _onDepartmentChanged,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('Please select a department');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectDueDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.tr('Due Date'),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                              : context.tr('Select due date (optional)'),
                          style: TextStyle(
                            color: _dueDate != null
                                ? context.mic.textPrimary
                                : context.mic.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    _buildPenaltyAmountField(),
                    SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: InputDecoration(
                        labelText: context.tr('Priority'),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: [
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
                        setState(() {
                          _priority = value ?? 'medium';
                        });
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(
                        labelText: context.tr('Status'),
                        prefixIcon: Icon(Icons.check_circle),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(context.tr('Pending')),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text(context.tr('In Progress')),
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
                        setState(() {
                          _status = value ?? 'pending';
                        });
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String?>(
                      initialValue: _effectiveProjectDropdownValue,
                      decoration: InputDecoration(
                        labelText: context.tr('Project (optional)'),
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: _projectDropdownItems(),
                      onChanged: (value) {
                        setState(() => _selectedProjectId = value);
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Text(
                      context.tr('Tags (optional)'),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTagController,
                            decoration: InputDecoration(
                              hintText: context.tr('Type a tag and add'),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.none,
                            onSubmitted: (v) => _addTagByName(v),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () =>
                              _addTagByName(_newTagController.text),
                          icon: Icon(Icons.add),
                          tooltip: context.tr('Add tag'),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      context.tr('Color'),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    TagColorPicker(
                      selectedHex: _newTagColor,
                      onChanged: (hex) => setState(() => _newTagColor = hex),
                      swatchSize: 26,
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _tags.map((tag) {
                        final id = tag['id'].toString();
                        final selected = _selectedTagIds.contains(id);
                        final color = TagColors.colorFromHex(
                          tag['color']?.toString(),
                        );
                        return FilterChip(
                          label: Text(tag['name']?.toString() ?? ''),
                          selected: selected,
                          backgroundColor: color.withValues(alpha: 0.2),
                          selectedColor: color.withValues(alpha: 0.4),
                          checkmarkColor: color,
                          side: BorderSide(color: color),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedTagIds.add(id);
                              } else {
                                _selectedTagIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppDimensions.spacingXL),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('Update Task')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
