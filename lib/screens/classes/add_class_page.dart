import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/class_service.dart';
import '../../services/department_service.dart';
import '../../core/localization/app_localizations.dart';

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

  static const double _kDesktopBreakpoint = 700;
  static const double _kDesktopMaxWidth = 800;

  Widget _desktopIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            ),
            child: Icon(Icons.school_outlined, color: AppColors.primary),
          ),
          SizedBox(width: AppDimensions.spacingLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Add Training'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr(
                    'Create a training and optionally link it to a department.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeWithoutResult,
            icon: Icon(Icons.close),
            tooltip: context.tr('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return Center(
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
                _desktopFormCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      child: Container(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  child: Icon(
                    Icons.class_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Text(
                  context.tr('Training details'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('Class Name *'),
                prefixIcon: Icon(Icons.class_),
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
            Divider(),
            SizedBox(height: AppDimensions.spacingMD),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _closeWithoutResult,
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
                  label: Text(context.tr('Create Training')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;
    final useDesktopShell = widget.onClose != null && useDesktop;

    return Scaffold(
      appBar: useDesktopShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(context.tr('Add Training')),
              actions: useDesktop
                  ? [
                      TextButton(
                        onPressed: _closeWithoutResult,
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.add, size: 20),
                        label: Text(context.tr('Create Training')),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: useDesktop
          ? _buildDesktopBody(context)
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
