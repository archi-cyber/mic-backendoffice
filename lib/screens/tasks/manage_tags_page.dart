import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/tag_colors.dart';
import '../../services/tag_service.dart';
import '../../services/department_service.dart';

/// Manage tags page (tags are per department). Pass [departmentId] or select one.
class ManageTagsPage extends StatefulWidget {
  /// When set (e.g. from department context), tags are scoped to this department.
  final String? departmentId;

  final void Function(bool? result)? onClose;

  const ManageTagsPage({super.key, this.departmentId, this.onClose});

  @override
  State<ManageTagsPage> createState() => _ManageTagsPageState();
}

class _ManageTagsPageState extends State<ManageTagsPage> {
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _departments = [];
  String? _selectedDepartmentId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingDepts = true;

  @override
  void initState() {
    super.initState();
    _selectedDepartmentId = widget.departmentId;
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepts = true);
    try {
      final depts = await DepartmentService.getDepartments(limit: 200);
      if (!mounted) return;
      setState(() {
        _departments = depts;
        _isLoadingDepts = false;
        if (_selectedDepartmentId == null && depts.isNotEmpty) {
          _selectedDepartmentId = depts.first['id'].toString();
        }
      });
      if (_selectedDepartmentId != null) _loadTags();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDepts = false);
    }
  }

  Future<void> _loadTags() async {
    if (_selectedDepartmentId == null) return;
    setState(() => _isLoading = true);
    try {
      final tags = await TagService.getTags(departmentId: _selectedDepartmentId!, limit: 500);
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tags: $e')),
      );
    }
  }

  Future<void> _addTag() async {
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a department first')),
      );
      return;
    }
    final nameController = TextEditingController();
    String selectedColor = TagColors.presetHex.first;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New tag'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tag name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Color',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TagColors.presetHex.map((hex) {
                      final isSelected = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: TagColors.colorFromHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'color': selectedColor,
                  });
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final name = result['name']!;
    final color = result['color'];
    setState(() => _isSaving = true);
    try {
      await TagService.createTag(
        name: name,
        departmentId: _selectedDepartmentId!,
        color: color,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tag added'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text(
          'Remove tag "${tag['name']}"? Tasks will no longer have this tag.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await TagService.deleteTag(tag['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tag removed'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadTags();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: const Text('Manage tags'),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.paddingSM),
              child: FilledButton.icon(
                onPressed: _selectedDepartmentId == null || _isSaving
                    ? null
                    : _addTag,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add tag'),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _selectedDepartmentId == null || _isSaving
                  ? null
                  : _addTag,
              tooltip: 'Add tag',
            ),
        ],
      ),
      body: _isLoadingDepts
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, isDesktop),
    );
  }

  Widget _buildBody(BuildContext context, bool isDesktop) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedDepartmentId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Department',
              border: OutlineInputBorder(),
            ),
            items: _departments
                .map((d) => DropdownMenuItem<String>(
                      value: d['id'].toString(),
                      child: Text(d['name']?.toString() ?? ''),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedDepartmentId = v);
              _loadTags();
            },
          ),
        ),
        Expanded(
          child: _selectedDepartmentId == null
              ? const Center(child: Text('Select a department'))
              : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.label_off_outlined,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: AppDimensions.spacingMD),
                              Text(
                                'No tags in this department',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppDimensions.spacingSM),
                              FilledButton.icon(
                                onPressed: _addTag,
                                icon: const Icon(Icons.add),
                                label: const Text('Add tag'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadTags,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(
                                AppDimensions.paddingMD),
                            itemCount: _tags.length,
                            itemBuilder: (context, index) {
                              final tag = _tags[index];
                              final color = TagColors.colorFromHex(
                                  tag['color']?.toString());
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: color.computeLuminance() > 0.5
                                            ? Colors.black26
                                            : Colors.white24,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  title: Text(tag['name']?.toString() ?? ''),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTag(tag),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kDesktopMaxWidth),
          child: column,
        ),
      );
    }
    return column;
  }
}
