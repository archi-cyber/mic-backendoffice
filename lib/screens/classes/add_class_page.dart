import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/class_service.dart';
import '../../services/department_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Add training page
class AddClassPage extends StatefulWidget {
  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  const AddClassPage({super.key, this.onClose});

  @override
  State<AddClassPage> createState() => _AddClassPageState();
}

class _AddClassPageState extends State<AddClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedDepartmentId;
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = false;
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ClassService.createClass(
        classData: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'department_id': _selectedDepartmentId,
          'is_active': true,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Training created successfully')),
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

  Widget _buildDesktopBody(BuildContext context, {required bool embedded}) {
    return DesktopPageShell(
      maxWidth: kDesktopFormMaxWidth,
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: context.tr('Add Training'),
        subtitle: context.tr(
          'Create a training and optionally link it to a department.',
        ),
        icon: Icons.school_outlined,
        trailing: embedded
            ? IconButton(
                onPressed: _closeWithoutResult,
                icon: const Icon(Icons.close),
                tooltip: context.tr('Cancel'),
              )
            : null,
      ),
      child: Form(
        key: _formKey,
        child: DesktopSectionCard(
          title: context.tr('Training details'),
          icon: Icons.class_outlined,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('Class Name *'),
                prefixIcon: const Icon(Icons.class_),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Training name is required';
                }
                return null;
              },
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.tr('Description'),
                prefixIcon: const Icon(Icons.description),
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            if (_isLoadingDepartments)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartmentId,
                decoration: InputDecoration(
                  labelText: context.tr('Department'),
                  prefixIcon: const Icon(Icons.group_work),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(context.tr('No Department')),
                  ),
                  ..._departments.map((dept) {
                    return DropdownMenuItem<String>(
                      value: dept['id'].toString(),
                      child: Text(dept['name']?.toString() ?? 'Unnamed'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDepartmentId = value;
                  });
                },
              ),
            SizedBox(height: AppDimensions.spacingLG),
            DesktopFormActions(
              onCancel: _closeWithoutResult,
              primaryLabel: context.tr('Create Training'),
              primaryIcon: Icons.add,
              onPrimary: _handleSave,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final embedded = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );
    final useDesktopLayout =
        embedded ||
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(context.tr('Add Training')),
              actions: useDesktopLayout && !embedded
                  ? [
                      TextButton(
                        onPressed: _closeWithoutResult,
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add, size: 20),
                        label: Text(context.tr('Create Training')),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: useDesktopLayout
          ? _buildDesktopBody(context, embedded: embedded)
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('Class Name *'),
                        prefixIcon: Icon(Icons.class_),
                        helperText: context.tr('Enter the name of the class'),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Training name is required';
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
                        helperText: context.tr(
                          'Optional description for the class',
                        ),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    if (_isLoadingDepartments)
                      Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartmentId,
                        decoration: InputDecoration(
                          labelText: context.tr('Department'),
                          prefixIcon: Icon(Icons.group_work),
                          helperText: context.tr(
                            'Optional: Assign to a department',
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(context.tr('No Department')),
                          ),
                          ..._departments.map((dept) {
                            return DropdownMenuItem<String>(
                              value: dept['id'].toString(),
                              child: Text(
                                dept['name']?.toString() ?? 'Unnamed',
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedDepartmentId = value;
                          });
                        },
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
                          : Text(context.tr('Create Class')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _closeWithoutResult() {
    if (widget.onClose != null) {
      widget.onClose!(null);
    } else {
      Navigator.of(context).pop();
    }
  }
}
