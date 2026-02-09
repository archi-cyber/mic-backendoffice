import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/task_service.dart';
import '../../services/department_service.dart';
import '../../services/member_service.dart';
import '../../services/project_service.dart';
import '../../services/tag_service.dart';
import '../../core/constants/tag_colors.dart';

/// Add task page
class AddTaskPage extends StatefulWidget {
  final String? departmentId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  const AddTaskPage({super.key, this.departmentId, this.onClose});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedMemberId;
  DateTime? _dueDate;
  String _priority = 'medium';
  String _status = 'pending';
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _tags = [];
  String? _selectedProjectId;
  final List<String> _selectedTagIds = [];
  bool _assignToIndividual = false; // Default: assign to department
  bool _isLoading = false;
  bool _isLoadingDepartments = true;
  bool _isLoadingMembers = false;
  bool _isLoadingProjects = true;
  bool _isLoadingTags = true;
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();

  /// Add tag by name: select existing or create if not found.
  Future<void> _addTagByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    Map<String, dynamic>? existing;
    for (final t in _tags) {
      if ((t['name']?.toString().trim().toLowerCase() ?? '') == trimmed.toLowerCase()) {
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
    final deptId = _tagDepartmentId;
    if (deptId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a department to add tags')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add tag: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.departmentId != null) {
      _selectedDepartmentId = widget.departmentId;
    }
    _loadDepartments();
    _loadMembers();
    _loadProjects();
    _loadTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _memberSearchController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await DepartmentService.getDepartments(limit: 100);
      setState(() {
        _departments = departments;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() => _isLoadingDepartments = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading departments: $e')),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await MemberService.getMembers(limit: 100);
      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      setState(() => _isLoadingMembers = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await ProjectService.getProjects(limit: 200);
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingProjects = false);
    }
  }

  String? get _tagDepartmentId => _selectedDepartmentId ?? widget.departmentId;

  Future<void> _loadTags() async {
    final deptId = _tagDepartmentId;
    if (deptId == null) {
      setState(() {
        _tags = [];
        _isLoadingTags = false;
      });
      return;
    }
    try {
      final tags = await TagService.getTags(departmentId: deptId, limit: 200);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _isLoadingTags = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTags = false);
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
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

    // Validate based on assignment type
    if (!_assignToIndividual && _selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_assignToIndividual && _selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a member'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create task - use selected department or member_id if assigning to individual
      final task = await TaskService.createTask(
        departmentId: _assignToIndividual ? null : _selectedDepartmentId!,
        memberId: _assignToIndividual ? _selectedMemberId! : null,
        taskData: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'due_date': _dueDate?.toIso8601String().split('T')[0],
          'priority': _priority,
          'status': _status,
          if (_selectedProjectId != null) 'project_id': _selectedProjectId,
        },
      );

      if (_selectedTagIds.isNotEmpty) {
        await TaskService.setTaskTags(
          taskId: task['id'].toString(),
          tagIds: _selectedTagIds,
        );
      }

      // If assigning to individual, also create task assignment for notification
      if (_assignToIndividual && _selectedMemberId != null) {
        await TaskService.assignTask(
          taskId: task['id'].toString(),
          memberId: _selectedMemberId!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
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

  String _getMemberName(String memberId) {
    final member = _members.firstWhere(
      (m) => m['id'].toString() == memberId,
      orElse: () => {},
    );
    if (member.isEmpty) return 'Unknown';
    return '${member['first_name']} ${member['last_name']}';
  }

  Future<void> _showMemberSearchDialog() async {
    _memberSearchController.clear();
    List<Map<String, dynamic>> filteredMembers = _members;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Member'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _memberSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search members',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Type to search...',
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.isEmpty) {
                          filteredMembers = _members;
                        } else {
                          final query = value.toLowerCase();
                          filteredMembers = _members.where((member) {
                            final firstName =
                                member['first_name']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';
                            final lastName =
                                member['last_name']?.toString().toLowerCase() ??
                                '';
                            final email =
                                member['email']?.toString().toLowerCase() ?? '';
                            return firstName.contains(query) ||
                                lastName.contains(query) ||
                                email.contains(query) ||
                                '$firstName $lastName'.contains(query);
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  Flexible(
                    child: filteredMembers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: Text('No members found'),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member = filteredMembers[index];
                              final name =
                                  '${member['first_name']} ${member['last_name']}';
                              final email = member['email']?.toString() ?? '';
                              return ListTile(
                                title: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: email.isNotEmpty
                                    ? Text(
                                        email,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedMemberId = member['id'].toString();
                                  });
                                  Navigator.of(context).pop();
                                },
                              );
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
            ],
          );
        },
      ),
    );
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
    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: const Text('Add Task'),
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
                      : const Icon(Icons.add, size: 20),
                  label: const Text('Create Task'),
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
                              isExpanded: true,
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
                              isExpanded: true,
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
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _isLoadingProjects
                                    ? 'Project (loading…)'
                                    : 'Project (optional)',
                                prefixIcon: const Icon(Icons.folder_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                ..._projects.map((p) => DropdownMenuItem<String?>(
                                      value: p['id'].toString(),
                                      child: Text(
                                        p['title']?.toString() ?? '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedProjectId = value);
                              },
                            ),
                            if (_isLoadingTags && _tags.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text('Tags (loading…)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12)),
                              ),
                            const SizedBox(height: AppDimensions.spacingMD),
                            const Text('Tags (optional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12)),
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
                                final color = TagColors.colorFromHex(tag['color']?.toString());
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
                        if (widget.departmentId == null) ...[
                          const SizedBox(height: AppDimensions.spacingMD),
                          _desktopSectionCard(
                            context,
                            'Assignment',
                            Icons.group_work,
                            [
                              SwitchListTile(
                                title: Text(
                                  _assignToIndividual
                                      ? 'Assign to Individual'
                                      : 'Assign to Department',
                                ),
                                subtitle: Text(
                                  _assignToIndividual
                                      ? 'Assign this task to a specific member'
                                      : 'Assign this task to a department',
                                ),
                                value: _assignToIndividual,
                                onChanged: (value) {
                                  setState(() {
                                    _assignToIndividual = value;
                                    if (value) {
                                      _selectedDepartmentId = null;
                                    } else {
                                      _selectedMemberId = null;
                                    }
                                  });
                                },
                              ),
                              if (!_assignToIndividual) ...[
                                if (_isLoadingDepartments)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedDepartmentId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Department *',
                                      prefixIcon: Icon(Icons.group_work),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _departments.map((dept) {
                                      return DropdownMenuItem<String>(
                                        value: dept['id'].toString(),
                                        child: Text(
                                          dept['name']?.toString() ?? 'Unnamed',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(
                                        () => _selectedDepartmentId = value,
                                      );
                                      _loadTags();
                                    },
                                  ),
                              ] else if (_assignToIndividual) ...[
                                InkWell(
                                  onTap: _isLoadingMembers
                                      ? null
                                      : _showMemberSearchDialog,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Member *',
                                      prefixIcon: const Icon(Icons.person),
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                      ),
                                      border: const OutlineInputBorder(),
                                      errorText:
                                          _assignToIndividual &&
                                              _selectedMemberId == null
                                          ? 'Member is required'
                                          : null,
                                    ),
                                    child: Text(
                                      _selectedMemberId != null
                                          ? _getMemberName(_selectedMemberId!)
                                          : 'Select a member',
                                      style: TextStyle(
                                        color: _selectedMemberId != null
                                            ? Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.color
                                            : Theme.of(context).hintColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
                    // Switch between department and individual assignment - only show if not accessed from department detail page
                    if (widget.departmentId == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppDimensions.paddingMD,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.group_work,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppDimensions.spacingSM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _assignToIndividual
                                          ? 'Assign to Individual'
                                          : 'Assign to Department',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      _assignToIndividual
                                          ? 'Assign this task to a specific member'
                                          : 'Assign this task to a department',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _assignToIndividual,
                                onChanged: (value) {
                                  setState(() {
                                    _assignToIndividual = value;
                                    // Clear selections when switching
                                    if (value) {
                                      _selectedDepartmentId = null;
                                    } else {
                                      _selectedMemberId = null;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (widget.departmentId == null)
                      const SizedBox(height: AppDimensions.spacingMD),
                    // Show department or member selection based on switch
                    // If departmentId is provided (from department detail page), don't show department dropdown
                    if (!_assignToIndividual &&
                        widget.departmentId == null) ...[
                      if (_isLoadingDepartments)
                        const Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDepartmentId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Department *',
                            prefixIcon: Icon(Icons.group_work),
                          ),
                          items: _departments.map((dept) {
                            return DropdownMenuItem<String>(
                              value: dept['id'].toString(),
                              child: Text(
                                dept['name']?.toString() ?? 'Unnamed',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartmentId = value;
                            });
                            _loadTags();
                          },
                          validator: (value) {
                            if (!_assignToIndividual && value == null) {
                              return 'Department is required';
                            }
                            return null;
                          },
                        ),
                    ] else if (_assignToIndividual) ...[
                      InkWell(
                        onTap: _isLoadingMembers
                            ? null
                            : _showMemberSearchDialog,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Member *',
                            prefixIcon: const Icon(Icons.person),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                            errorText:
                                _assignToIndividual && _selectedMemberId == null
                                ? 'Member is required'
                                : null,
                          ),
                          child: Text(
                            _selectedMemberId != null
                                ? _getMemberName(_selectedMemberId!)
                                : 'Select a member',
                            style: TextStyle(
                              color: _selectedMemberId != null
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Theme.of(context).hintColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingMD),
                    // Due date
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
                    // Priority
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
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
                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
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
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _isLoadingProjects
                            ? 'Project (loading…)'
                            : 'Project (optional)',
                        prefixIcon: const Icon(Icons.folder_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._projects.map((p) => DropdownMenuItem<String?>(
                              value: p['id'].toString(),
                              child: Text(
                                p['title']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedProjectId = value);
                      },
                    ),
                    if (_isLoadingTags && _tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Tags (loading…)',
                            style: TextStyle(
                                fontWeight: FontWeight.w500, fontSize: 12)),
                      ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    const Text('Tags (optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 12)),
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
                        final color = TagColors.colorFromHex(tag['color']?.toString());
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
                          : const Text('Create Task'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
