import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/task_service.dart';
import '../../services/department_service.dart';
import '../../services/project_service.dart';
import '../../services/tag_service.dart';
import '../../core/constants/tag_colors.dart';

/// Edit task page
class EditTaskPage extends StatefulWidget {
  final String taskId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  const EditTaskPage({super.key, required this.taskId, this.onClose});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
          const SnackBar(
            content: Text('Task has no department; cannot add tags'),
          ),
        );
      }
      return;
    }
    try {
      final created = await TagService.createTag(
        name: trimmed,
        departmentId: deptId,
        color: TagColors.defaultHex,
      );
      if (!mounted) return;
      final id = created['id'].toString();
      setState(() {
        _tags.add(created);
        if (!_selectedTagIds.contains(id)) _selectedTagIds.add(id);
      });
      _newTagController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add tag: $e')));
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
        _selectedDepartmentId = task['department_id']?.toString();
        _selectedProjectId = task['project_id']?.toString();
        _selectedTagIds.clear();
        _selectedTagIds.addAll(tagIds);
        _priority = task['priority']?.toString() ?? 'medium';
        _status = task['status']?.toString() ?? 'pending';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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
          const SnackBar(
            content: Text('Task updated successfully'),
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
  static const double _kDesktopMaxWidth = 800;

  Widget _desktopSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spacingSM),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            ...children,
          ],
        ),
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
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => widget.onClose!(null),
                )
              : null,
          title: const Text('Edit Task'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: const Text('Edit Task'),
        actions: useDesktop
            ? [
                TextButton(
                  onPressed: () => widget.onClose != null
                      ? widget.onClose!(null)
                      : Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppDimensions.spacingSM),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: const Text('Update Task'),
                ),
                const SizedBox(width: AppDimensions.paddingMD),
              ]
            : null,
      ),
      body: useDesktop
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLG),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kDesktopMaxWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _desktopSectionCard(
                          context,
                          'Task details',
                          Icons.task_alt,
                          [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Task Title *',
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Task title is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDepartmentId,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                prefixIcon: Icon(Icons.group_work),
                                border: OutlineInputBorder(),
                              ),
                              items: _departments.map((dept) {
                                return DropdownMenuItem<String>(
                                  value: dept['id'].toString(),
                                  child: Text(
                                    dept['name']?.toString() ?? 'Unnamed',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDepartmentId = value;
                                });
                                _loadTagsForDepartment();
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            InkWell(
                              onTap: _selectDueDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Due Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _dueDate != null
                                      ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                      : 'Select due date (optional)',
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
                            const SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.flag),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text('Low'),
                                ),
                                DropdownMenuItem(
                                  value: 'medium',
                                  child: Text('Medium'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text('High'),
                                ),
                                DropdownMenuItem(
                                  value: 'urgent',
                                  child: Text('Urgent'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _priority = value ?? 'medium');
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.check_circle),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending'),
                                ),
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
                                setState(() => _status = value ?? 'pending');
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            DropdownButtonFormField<String?>(
                              initialValue: _selectedProjectId,
                              decoration: const InputDecoration(
                                labelText: 'Project (optional)',
                                prefixIcon: Icon(Icons.folder_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                ..._projects.map(
                                  (p) => DropdownMenuItem<String?>(
                                    value: p['id'].toString(),
                                    child: Text(
                                      p['title']?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedProjectId = value);
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            const Text(
                              'Tags (optional)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newTagController,
                                    decoration: const InputDecoration(
                                      hintText: 'Type a tag and add',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    textCapitalization: TextCapitalization.none,
                                    onSubmitted: (v) => _addTagByName(v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: () =>
                                      _addTagByName(_newTagController.text),
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add tag',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title *',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Task title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartmentId,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.group_work),
                      ),
                      items: _departments.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept['id'].toString(),
                          child: Text(dept['name']?.toString() ?? 'Unnamed'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartmentId = value;
                        });
                        _loadTagsForDepartment();
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectDueDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _dueDate != null
                              ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                              : 'Select due date (optional)',
                          style: TextStyle(
                            color: _dueDate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _priority = value ?? 'medium';
                        });
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.check_circle),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
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
                        setState(() {
                          _status = value ?? 'pending';
                        });
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Project (optional)',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._projects.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p['id'].toString(),
                            child: Text(
                              p['title']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedProjectId = value);
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    const Text(
                      'Tags (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTagController,
                            decoration: const InputDecoration(
                              hintText: 'Type a tag and add',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.none,
                            onSubmitted: (v) => _addTagByName(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () =>
                              _addTagByName(_newTagController.text),
                          icon: const Icon(Icons.add),
                          tooltip: 'Add tag',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: AppDimensions.spacingXL),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update Task'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
