import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/department_service.dart';
import '../../services/storage_service.dart';

/// Add department page
class AddDepartmentPage extends StatefulWidget {
  const AddDepartmentPage({super.key});

  @override
  State<AddDepartmentPage> createState() => _AddDepartmentPageState();
}

class _AddDepartmentPageState extends State<AddDepartmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  // Document files
  File? _document1;
  File? _document2;
  File? _document3;

  // Document names
  String? _document1Name;
  String? _document2Name;
  String? _document3Name;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(int documentNumber) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        setState(() {
          switch (documentNumber) {
            case 1:
              _document1 = file;
              _document1Name = fileName;
              break;
            case 2:
              _document2 = file;
              _document2Name = fileName;
              break;
            case 3:
              _document3 = file;
              _document3Name = fileName;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeDocument(int documentNumber) {
    setState(() {
      switch (documentNumber) {
        case 1:
          _document1 = null;
          _document1Name = null;
          break;
        case 2:
          _document2 = null;
          _document2Name = null;
          break;
        case 3:
          _document3 = null;
          _document3Name = null;
          break;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create department first
      final department = await DepartmentService.createDepartment(
        departmentData: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'is_active': true,
        },
      );

      final departmentId = department['id'].toString();
      final folder = 'departments/$departmentId';

      // Upload documents if any
      final Map<String, dynamic> documentUpdates = {};

      if (_document1 != null) {
        try {
          final url = await StorageService.uploadFile(
            file: _document1!,
            folder: folder,
            fileName: _document1Name,
          );
          documentUpdates['document_1_url'] = url;
          documentUpdates['document_1_name'] = _document1Name;
        } catch (e) {
          debugPrint('Error uploading document 1: $e');
        }
      }

      if (_document2 != null) {
        try {
          final url = await StorageService.uploadFile(
            file: _document2!,
            folder: folder,
            fileName: _document2Name,
          );
          documentUpdates['document_2_url'] = url;
          documentUpdates['document_2_name'] = _document2Name;
        } catch (e) {
          debugPrint('Error uploading document 2: $e');
        }
      }

      if (_document3 != null) {
        try {
          final url = await StorageService.uploadFile(
            file: _document3!,
            folder: folder,
            fileName: _document3Name,
          );
          documentUpdates['document_3_url'] = url;
          documentUpdates['document_3_name'] = _document3Name;
        } catch (e) {
          debugPrint('Error uploading document 3: $e');
        }
      }

      // Update department with document URLs if any were uploaded
      if (documentUpdates.isNotEmpty) {
        await DepartmentService.updateDepartment(
          departmentId: departmentId,
          updates: documentUpdates,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department created successfully'),
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
      appBar: AppBar(title: const Text('Add Department')),
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
                  labelText: 'Department Name *',
                  prefixIcon: Icon(Icons.group_work),
                  helperText: 'Enter the name of the department',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Department name is required';
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
                  helperText: 'Optional description for the department',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              // Documents section
              const Divider(),
              const SizedBox(height: AppDimensions.spacingSM),
              Text(
                'Documents (Optional)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _buildDocumentPicker(1, _document1Name),
              const SizedBox(height: AppDimensions.spacingSM),
              _buildDocumentPicker(2, _document2Name),
              const SizedBox(height: AppDimensions.spacingSM),
              _buildDocumentPicker(3, _document3Name),
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
                    : const Text('Create Department'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPicker(int documentNumber, String? fileName) {
    final hasFile = fileName != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingSM),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file,
              color: hasFile ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Text(
                hasFile ? fileName : 'Document $documentNumber (Optional)',
                style: TextStyle(
                  color: hasFile
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: hasFile ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeDocument(documentNumber),
                tooltip: 'Remove',
              )
            else
              TextButton.icon(
                onPressed: () => _pickDocument(documentNumber),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload'),
              ),
          ],
        ),
      ),
    );
  }
}
