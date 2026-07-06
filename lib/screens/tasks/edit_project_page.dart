import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/project_service.dart';
import '../../services/department_service.dart';
import '../../services/member_service.dart';
import '../../core/localization/app_localizations.dart';

/// Edit project page (from Manage projects → tap project).
class EditProjectPage extends StatefulWidget {
  final String projectId;

  final void Function(bool? result)? onClose;

  EditProjectPage({super.key, required this.projectId, this.onClose});

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personSearchController = TextEditingController();
  String? _selectedDepartmentId;
  String? _selectedPersonInChargeId;
  DateTime? _endDate;
  String _priority = 'medium';
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _personSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembersForDepartment(String? departmentId) async {
    setState(() => _isLoadingMembers = true);
    try {
      List<Map<String, dynamic>> members;
      if (departmentId != null && departmentId.isNotEmpty) {
        final dmList = await DepartmentService.getDepartmentMembers(
          departmentId,
        );
        members = dmList
            .map((dm) => dm['members'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>()
            .toList();
      } else {
        members = await MemberService.getMembers(limit: 200);
      }
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoadingMembers = false;
        if (_selectedPersonInChargeId != null) {
          final stillValid = members.any(
            (m) => m['id'].toString() == _selectedPersonInChargeId,
          );
          if (!stillValid) _selectedPersonInChargeId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMembers = false);
    }
  }

  String _getPersonName(String? memberId) {
    if (memberId == null) return '';
    final m = _members.cast<Map<String, dynamic>?>().firstWhere(
      (x) => x?['id'].toString() == memberId,
      orElse: () => null,
    );
    if (m == null) return 'Unknown';
    return '${m['first_name']} ${m['last_name']}';
  }

  Future<void> _showPersonInChargePicker() async {
    _personSearchController.clear();
    List<Map<String, dynamic>> filtered = List.from(_members);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(context.tr('Person in charge')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _personSearchController,
                    decoration: InputDecoration(
                      labelText: context.tr('Search'),
                      prefixIcon: Icon(Icons.search),
                      hintText: context.tr('Type to search...'),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value.trim().isEmpty) {
                          filtered = List.from(_members);
                        } else {
                          final q = value.toLowerCase();
                          filtered = _members.where((m) {
                            final first =
                                m['first_name']?.toString().toLowerCase() ?? '';
                            final last =
                                m['last_name']?.toString().toLowerCase() ?? '';
                            final email =
                                m['email']?.toString().toLowerCase() ?? '';
                            return first.contains(q) ||
                                last.contains(q) ||
                                email.contains(q) ||
                                '$first $last'.contains(q);
                          }).toList();
                        }
                      });
                    },
                  ),
                  SizedBox(height: 12),
                  Flexible(
                    child: _members.isEmpty
                        ? Center(
                            child: Text(
                              context.tr('Select a department first'),
                            ),
                          )
                        : filtered.isEmpty
                        ? Center(child: Text(context.tr('No members found')))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return ListTile(
                                  title: Text(context.tr('None')),
                                  onTap: () {
                                    setState(
                                      () => _selectedPersonInChargeId = null,
                                    );
                                    Navigator.pop(context);
                                  },
                                );
                              }
                              final m = filtered[index - 1];
                              final id = m['id'].toString();
                              final name =
                                  '${m['first_name']} ${m['last_name']}';
                              final email = m['email']?.toString() ?? '';
                              return ListTile(
                                title: Text(name),
                                subtitle: email.isNotEmpty ? Text(email) : null,
                                onTap: () {
                                  setState(
                                    () => _selectedPersonInChargeId = id,
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ProjectService.getProjectById(widget.projectId),
        DepartmentService.getDepartments(limit: 200),
      ]);

      final project = results[0] as Map<String, dynamic>;
      final departments = results[1] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _titleController.text = project['title']?.toString() ?? '';
        _descriptionController.text = project['description']?.toString() ?? '';
        _selectedDepartmentId = project['department_id']?.toString();
        _selectedPersonInChargeId = project['person_in_charge_id']?.toString();
        _priority = project['priority']?.toString() ?? 'medium';
        if (project['end_date'] != null) {
          _endDate = DateTime.parse(project['end_date']);
        }
        _departments = departments;
        _isLoadingData = false;
      });
      await _loadMembersForDepartment(_selectedDepartmentId);
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading project: $e'))),
        );
        if (widget.onClose != null) {
          widget.onClose!(null);
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select a department')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ProjectService.updateProject(
        projectId: widget.projectId,
        updates: {
          'title': _titleController.text.trim(),
          'department_id': _selectedDepartmentId,
          if (_selectedPersonInChargeId != null)
            'person_in_charge_id': _selectedPersonInChargeId
          else
            'person_in_charge_id': null,
          'end_date': _endDate?.toIso8601String().split('T')[0],
          'priority': _priority,
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Project updated successfully')),
          backgroundColor: AppColors.success,
        ),
      );
      if (widget.onClose != null) {
        widget.onClose!(true);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 680;

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
                  'Edit project',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  'Update the project owner, department, deadline, and priority.',
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
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: Icon(isDesktop ? Icons.close : Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: Text(context.tr('Edit Project')),
        actions: isDesktop
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
                  label: Text(context.tr('Update Project')),
                ),
                SizedBox(width: AppDimensions.paddingMD),
              ]
            : null,
      ),
      backgroundColor: isDesktop
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : null,
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator())
          : isDesktop
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingLG),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _kDesktopMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _desktopIntroCard(context),
                      SizedBox(height: AppDimensions.spacingLG),
                      Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusXL,
                          ),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingLG),
                          child: _buildForm(context, showButton: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: _buildForm(context, showButton: true),
            ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool showButton}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: context.tr('Project title *'),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          DropdownButtonFormField<String>(
            initialValue: _selectedDepartmentId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _isLoadingMembers
                  ? 'Department * (loading members…)'
                  : 'Department *',
              border: OutlineInputBorder(),
            ),
            items: _departments
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d['id'].toString(),
                    child: Text(
                      d['name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) async {
              setState(() => _selectedDepartmentId = v);
              await _loadMembersForDepartment(v);
            },
          ),
          SizedBox(height: AppDimensions.spacingMD),
          InkWell(
            onTap: _isLoadingMembers ? null : () => _showPersonInChargePicker(),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('Person in charge'),
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              child: Text(
                _selectedPersonInChargeId != null
                    ? _getPersonName(_selectedPersonInChargeId)
                    : 'Tap to search and select',
                style: TextStyle(
                  color: _selectedPersonInChargeId != null
                      ? null
                      : Theme.of(context).hintColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          InkWell(
            onTap: _selectEndDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('End date'),
                border: OutlineInputBorder(),
              ),
              child: Text(
                _endDate != null
                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                    : 'Select end date (optional)',
                style: TextStyle(
                  color: _endDate != null ? null : Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Priority'),
              border: OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: 'low', child: Text(context.tr('Low'))),
              DropdownMenuItem(
                value: 'medium',
                child: Text(context.tr('Medium')),
              ),
              DropdownMenuItem(value: 'high', child: Text(context.tr('High'))),
              DropdownMenuItem(
                value: 'urgent',
                child: Text(context.tr('Urgent')),
              ),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'medium'),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: context.tr('Description'),
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          if (showButton) ...[
            SizedBox(height: AppDimensions.spacingLG),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Update Project')),
            ),
          ],
        ],
      ),
    );
  }
}
