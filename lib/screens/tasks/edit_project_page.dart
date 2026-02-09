import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/project_service.dart';
import '../../services/department_service.dart';
import '../../services/member_service.dart';

/// Edit project page (from Manage projects → tap project).
class EditProjectPage extends StatefulWidget {
  final String projectId;

  final void Function(bool? result)? onClose;

  const EditProjectPage({super.key, required this.projectId, this.onClose});

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
            title: const Text('Person in charge'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _personSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Type to search...',
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
                  const SizedBox(height: 12),
                  Flexible(
                    child: _members.isEmpty
                        ? const Center(child: Text('Select a department first'))
                        : filtered.isEmpty
                        ? const Center(child: Text('No members found'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return ListTile(
                                  title: const Text('None'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading project: $e')));
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
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department'),
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
        const SnackBar(
          content: Text('Project updated successfully'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: const Text('Edit Project'),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
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
                        labelText: 'Project title *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDepartmentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _isLoadingMembers
                            ? 'Department * (loading members…)'
                            : 'Department *',
                        border: const OutlineInputBorder(),
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
                    const SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _isLoadingMembers
                          ? null
                          : () => _showPersonInChargePicker(),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Person in charge',
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
                    const SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectEndDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                              : 'Select end date (optional)',
                          style: TextStyle(
                            color: _endDate != null
                                ? null
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
                        border: OutlineInputBorder(),
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
                      onChanged: (v) =>
                          setState(() => _priority = v ?? 'medium'),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppDimensions.spacingLG),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update Project'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
