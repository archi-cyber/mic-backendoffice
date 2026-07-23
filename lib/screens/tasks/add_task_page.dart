import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/task_service.dart';
import '../../services/task_penalty_service.dart';
import '../../services/department_service.dart';
import '../../services/member_service.dart';
import '../../services/project_service.dart';
import '../../services/tag_service.dart';
import '../../core/constants/tag_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/tag_color_picker.dart';

/// Add task page
class AddTaskPage extends StatefulWidget {
  final String? departmentId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  AddTaskPage({super.key, this.departmentId, this.onClose});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyAmountController = TextEditingController();
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
  String _newTagColor = TagColors.presetHex.first;

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
    final deptId = _tagDepartmentId;
    if (deptId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Select a department to add tags')),
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
    _penaltyAmountController.dispose();
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
          SnackBar(content: Text(context.tr('Error loading departments: $e'))),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await MemberService.getMembers(limit: 100);
      final membersWithPenalties =
          await TaskPenaltyService.annotateMembersWithPenalties(members);
      setState(() {
        _members = membersWithPenalties;
        _isLoadingMembers = false;
      });
    } catch (e) {
      setState(() => _isLoadingMembers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading members: $e'))),
        );
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

    // Validate based on assignment type
    if (!_assignToIndividual && _selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a department')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_assignToIndividual && _selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a member')),
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
          if (_penaltyAmountController.text.trim().isNotEmpty)
            'penalty_amount_per_day': int.parse(
              _penaltyAmountController.text.trim(),
            ),
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
          SnackBar(
            content: Text(context.tr('Task created successfully')),
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
    if (member.isEmpty) return context.tr('Unknown');
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
            title: Text(context.tr('Select Member')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _memberSearchController,
                    decoration: InputDecoration(
                      labelText: context.tr('Search members'),
                      prefixIcon: Icon(Icons.search),
                      hintText: context.tr('Type to search...'),
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
                  SizedBox(height: AppDimensions.spacingMD),
                  Flexible(
                    child: filteredMembers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: Text(context.tr('No members found')),
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
                              final isBlocked =
                                  member['is_assignment_blocked'] == true;
                              final balance =
                                  member['penalty_balance'] as int? ?? 0;
                              return ListTile(
                                enabled: !isBlocked,
                                title: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (email.isNotEmpty)
                                      Text(
                                        email,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (isBlocked)
                                      Text(
                                        context.tr(
                                          'Blocked: {balance}frs unpaid penalties',
                                          {'balance': balance},
                                        ),
                                        style: TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: isBlocked
                                    ? Icon(
                                        Icons.lock_outline,
                                        color: AppColors.error,
                                      )
                                    : null,
                                onTap: isBlocked
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedMemberId = member['id']
                                              .toString();
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
                child: Text(context.tr('Cancel')),
              ),
            ],
          );
        },
      ),
    );
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
              Icons.add_task_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Create a new task'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr(
                    'Set the task details, delivery expectations, and assignment in one place.',
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
    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: Icon(useDesktop ? Icons.close : Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: Text(context.tr('Add Task')),
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
                      : Icon(Icons.add, size: 20),
                  label: Text(context.tr('Create Task')),
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
                              isExpanded: true,
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
                              isExpanded: true,
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
                              initialValue: _selectedProjectId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _isLoadingProjects
                                    ? context.tr('Project (loading…)')
                                    : context.tr('Project (optional)'),
                                prefixIcon: Icon(Icons.folder_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(context.tr('None')),
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
                            if (_isLoadingTags && _tags.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  context.tr('Tags (loading…)'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
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
                        if (widget.departmentId == null) ...[
                          SizedBox(height: AppDimensions.spacingMD),
                          _desktopSectionCard(
                            context,
                            context.tr('Assignment'),
                            Icons.group_work,
                            [
                              SwitchListTile(
                                title: Text(
                                  _assignToIndividual
                                      ? context.tr('Assign to Individual')
                                      : context.tr('Assign to Department'),
                                ),
                                subtitle: Text(
                                  _assignToIndividual
                                      ? context.tr(
                                          'Assign this task to a specific member',
                                        )
                                      : context.tr(
                                          'Assign this task to a department',
                                        ),
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
                                  Center(child: CircularProgressIndicator())
                                else
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedDepartmentId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: context.tr('Department *'),
                                      prefixIcon: Icon(Icons.group_work),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _departments.map((dept) {
                                      return DropdownMenuItem<String>(
                                        value: dept['id'].toString(),
                                        child: Text(
                                          dept['name']?.toString() ??
                                              context.tr('Unnamed'),
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
                                      labelText: context.tr('Member *'),
                                      prefixIcon: Icon(Icons.person),
                                      suffixIcon: Icon(Icons.arrow_drop_down),
                                      border: OutlineInputBorder(),
                                      errorText:
                                          _assignToIndividual &&
                                              _selectedMemberId == null
                                          ? context.tr('Member is required')
                                          : null,
                                    ),
                                    child: Text(
                                      _selectedMemberId != null
                                          ? _getMemberName(_selectedMemberId!)
                                          : context.tr('Select a member'),
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
                    // Switch between department and individual assignment - only show if not accessed from department detail page
                    if (widget.departmentId == null)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingMD),
                          child: Row(
                            children: [
                              Icon(Icons.group_work, color: AppColors.primary),
                              SizedBox(width: AppDimensions.spacingSM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _assignToIndividual
                                          ? context.tr('Assign to Individual')
                                          : context.tr('Assign to Department'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      _assignToIndividual
                                          ? context.tr(
                                              'Assign this task to a specific member',
                                            )
                                          : context.tr(
                                              'Assign this task to a department',
                                            ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: context.mic.textSecondary,
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
                      SizedBox(height: AppDimensions.spacingMD),
                    // Show department or member selection based on switch
                    // If departmentId is provided (from department detail page), don't show department dropdown
                    if (!_assignToIndividual &&
                        widget.departmentId == null) ...[
                      if (_isLoadingDepartments)
                        Center(child: CircularProgressIndicator())
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDepartmentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.tr('Department *'),
                            prefixIcon: Icon(Icons.group_work),
                          ),
                          items: _departments.map((dept) {
                            return DropdownMenuItem<String>(
                              value: dept['id'].toString(),
                              child: Text(
                                dept['name']?.toString() ??
                                    context.tr('Unnamed'),
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
                              return context.tr('Department is required');
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
                            labelText: context.tr('Member *'),
                            prefixIcon: Icon(Icons.person),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                            errorText:
                                _assignToIndividual && _selectedMemberId == null
                                ? context.tr('Member is required')
                                : null,
                          ),
                          child: Text(
                            _selectedMemberId != null
                                ? _getMemberName(_selectedMemberId!)
                                : context.tr('Select a member'),
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
                    SizedBox(height: AppDimensions.spacingMD),
                    // Due date
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
                    // Priority
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
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
                    // Status
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
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
                      initialValue: _selectedProjectId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _isLoadingProjects
                            ? context.tr('Project (loading…)')
                            : context.tr('Project (optional)'),
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(context.tr('None')),
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
                    if (_isLoadingTags && _tags.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          context.tr('Tags (loading…)'),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
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
                          : Text(context.tr('Create Task')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
