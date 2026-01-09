import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/class_service.dart';
import '../../services/department_service.dart';

/// Add training page
class AddClassPage extends StatefulWidget {
  const AddClassPage({super.key});

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
          SnackBar(content: Text('Error loading departments: $e')),
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
          const SnackBar(
            content: Text('Training created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Training')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  prefixIcon: Icon(Icons.class_),
                  helperText: 'Enter the name of the class',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Training name is required';
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
                  helperText: 'Optional description for the class',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              if (_isLoadingDepartments)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.group_work),
                    helperText: 'Optional: Assign to a department',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Department'),
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
                    : const Text('Create Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
