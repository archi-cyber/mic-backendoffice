import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/department_service.dart';
import '../../services/storage_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';
import 'department_form_ui.dart';

/// Add department page
class AddDepartmentPage extends StatefulWidget {
  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  AddDepartmentPage({super.key, this.onClose});

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
  File? _document4;

  // Document names
  String? _document1Name;
  String? _document2Name;
  String? _document3Name;
  String? _document4Name;

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
            case 4:
              _document4 = file;
              _document4Name = fileName;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error picking file: $e')),
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
        case 4:
          _document4 = null;
          _document4Name = null;
          break;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create department first
      debugPrint('[AddDepartmentPage] Creating department...');
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
      debugPrint(
        '[AddDepartmentPage] Department created successfully. ID: $departmentId',
      );
      final folder = 'departments/$departmentId';
      debugPrint('[AddDepartmentPage] Storage folder: $folder');

      // Upload documents if any
      final Map<String, dynamic> documentUpdates = {};
      final List<String> uploadErrors = [];

      if (_document1 != null) {
        try {
          debugPrint(
            '[AddDepartmentPage] Uploading document 1: $_document1Name',
          );
          final url = await StorageService.uploadFile(
            file: _document1!,
            folder: folder,
            fileName: _document1Name,
          );
          debugPrint(
            '[AddDepartmentPage] Document 1 uploaded successfully. URL: $url',
          );
          documentUpdates['document_1_url'] = url;
          documentUpdates['document_1_name'] = _document1Name;
        } catch (e) {
          debugPrint('[AddDepartmentPage] Error uploading document 1: $e');
          uploadErrors.add(
            'Failed to upload "$_document1Name": ${e.toString()}',
          );
        }
      }

      if (_document2 != null) {
        try {
          debugPrint(
            '[AddDepartmentPage] Uploading document 2: $_document2Name',
          );
          final url = await StorageService.uploadFile(
            file: _document2!,
            folder: folder,
            fileName: _document2Name,
          );
          debugPrint(
            '[AddDepartmentPage] Document 2 uploaded successfully. URL: $url',
          );
          documentUpdates['document_2_url'] = url;
          documentUpdates['document_2_name'] = _document2Name;
        } catch (e) {
          debugPrint('[AddDepartmentPage] Error uploading document 2: $e');
          uploadErrors.add(
            'Failed to upload "$_document2Name": ${e.toString()}',
          );
        }
      }

      if (_document3 != null) {
        try {
          debugPrint(
            '[AddDepartmentPage] Uploading document 3: $_document3Name',
          );
          final url = await StorageService.uploadFile(
            file: _document3!,
            folder: folder,
            fileName: _document3Name,
          );
          debugPrint(
            '[AddDepartmentPage] Document 3 uploaded successfully. URL: $url',
          );
          documentUpdates['document_3_url'] = url;
          documentUpdates['document_3_name'] = _document3Name;
        } catch (e) {
          debugPrint('[AddDepartmentPage] Error uploading document 3: $e');
          uploadErrors.add(
            'Failed to upload "$_document3Name": ${e.toString()}',
          );
        }
      }

      if (_document4 != null) {
        try {
          debugPrint(
            '[AddDepartmentPage] Uploading document 4: $_document4Name',
          );
          final url = await StorageService.uploadFile(
            file: _document4!,
            folder: folder,
            fileName: _document4Name,
          );
          debugPrint(
            '[AddDepartmentPage] Document 4 uploaded successfully. URL: $url',
          );
          documentUpdates['document_4_url'] = url;
          documentUpdates['document_4_name'] = _document4Name;
        } catch (e) {
          debugPrint('[AddDepartmentPage] Error uploading document 4: $e');
          uploadErrors.add(
            'Failed to upload "$_document4Name": ${e.toString()}',
          );
        }
      }

      // Update department with document URLs if any were uploaded
      if (documentUpdates.isNotEmpty) {
        debugPrint(
          '[AddDepartmentPage] Updating department with document data: $documentUpdates',
        );
        final updatedDepartment = await DepartmentService.updateDepartment(
          departmentId: departmentId,
          updates: documentUpdates,
        );
        debugPrint(
          '[AddDepartmentPage] Department updated successfully with documents.',
        );
        debugPrint('[AddDepartmentPage] Updated department data:');
        debugPrint(
          '  - document_1_url: ${updatedDepartment['document_1_url']}',
        );
        debugPrint(
          '  - document_1_name: ${updatedDepartment['document_1_name']}',
        );
        debugPrint(
          '  - document_2_url: ${updatedDepartment['document_2_url']}',
        );
        debugPrint(
          '  - document_2_name: ${updatedDepartment['document_2_name']}',
        );
        debugPrint(
          '  - document_3_url: ${updatedDepartment['document_3_url']}',
        );
        debugPrint(
          '  - document_3_name: ${updatedDepartment['document_3_name']}',
        );
        debugPrint(
          '  - document_4_url: ${updatedDepartment['document_4_url']}',
        );
        debugPrint(
          '  - document_4_name: ${updatedDepartment['document_4_name']}',
        );
      } else {
        debugPrint('[AddDepartmentPage] No documents to upload.');
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadErrors.isEmpty
                  ? 'Department created successfully'
                  : 'Department created, but some documents failed to upload',
            ),
            backgroundColor: uploadErrors.isEmpty
                ? AppColors.success
                : AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );

        // Show detailed error dialog if there were upload errors
        if (uploadErrors.isNotEmpty) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text(context.tr('Document Upload Errors')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The department was created, but the following documents failed to upload:',
                      ),
                      SizedBox(height: 16),
                      ...uploadErrors.map(
                        (error) => Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $error',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You can add these documents later by editing the department.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('OK')),
                  ),
                ],
              ),
            );
          }
        }

        debugPrint(
          '[AddDepartmentPage] Department creation completed successfully.',
        );
        debugPrint('[AddDepartmentPage] Summary:');
        debugPrint('  - Department ID: $departmentId');
        debugPrint('  - Documents uploaded: ${documentUpdates.length}');
        debugPrint('  - Upload errors: ${uploadErrors.length}');

        if (mounted) {
          if (widget.onClose != null) {
            widget.onClose!(true);
          } else {
            Navigator.of(context).pop(true);
          }
        }
      }
    } catch (e) {
      debugPrint('[AddDepartmentPage] Error creating department: $e');
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

  Widget _buildDesktopBody(BuildContext context) {
    return DesktopPageShell(
      isLoading: _isLoading,
      maxWidth: kDesktopFormMaxWidth,
      banner: DesktopHeroBanner(
        title: context.tr('Add Department'),
        subtitle: context.tr(
          'Create a department and attach reference documents',
        ),
        icon: Icons.add_business_outlined,
        accent: DepartmentFormUi.accent,
        trailing: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => widget.onClose!(null),
              )
            : null,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSectionCard(
              title: context.tr('Basic information'),
              icon: Icons.info_outline,
              accent: DepartmentFormUi.accent,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Department Name *'),
                    prefixIcon: const Icon(Icons.group_work),
                    helperText: context.tr(
                      'Enter the name of the department',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Department name is required';
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
                    helperText: context.tr(
                      'Optional description for the department',
                    ),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            DesktopSectionCard(
              title: context.tr('Documents (Optional)'),
              icon: Icons.folder_outlined,
              accent: DepartmentFormUi.accent,
              children: [
                _buildDocumentPicker(1, _document1Name),
                SizedBox(height: AppDimensions.spacingSM),
                _buildDocumentPicker(2, _document2Name),
                SizedBox(height: AppDimensions.spacingSM),
                _buildDocumentPicker(3, _document3Name),
                SizedBox(height: AppDimensions.spacingSM),
                _buildDocumentPicker(4, _document4Name),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            DesktopFormActions(
              onCancel: () => widget.onClose != null
                  ? widget.onClose!(null)
                  : Navigator.of(context).pop(),
              primaryLabel: context.tr('Create Department'),
              onPrimary: _handleSave,
              primaryIcon: Icons.save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: isDesktop
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(context.tr('Add Department')),
            ),
      body: isDesktop
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
                        labelText: context.tr('Department Name *'),
                        prefixIcon: Icon(Icons.group_work),
                        helperText: context.tr(
                          'Enter the name of the department',
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Department name is required';
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
                          'Optional description for the department',
                        ),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Divider(),
                    SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      'Documents (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    _buildDocumentPicker(1, _document1Name),
                    SizedBox(height: AppDimensions.spacingSM),
                    _buildDocumentPicker(2, _document2Name),
                    SizedBox(height: AppDimensions.spacingSM),
                    _buildDocumentPicker(3, _document3Name),
                    SizedBox(height: AppDimensions.spacingSM),
                    _buildDocumentPicker(4, _document4Name),
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
                          : Text(context.tr('Create Department')),
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
        padding: EdgeInsets.all(AppDimensions.paddingSM),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file,
              color: hasFile ? AppColors.primary : context.mic.textSecondary,
            ),
            SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Text(
                hasFile ? fileName : 'Document $documentNumber (Optional)',
                style: TextStyle(
                  color: hasFile
                      ? context.mic.textPrimary
                      : context.mic.textSecondary,
                  fontWeight: hasFile ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFile)
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => _removeDocument(documentNumber),
                tooltip: context.tr('Remove'),
              )
            else
              TextButton.icon(
                onPressed: () => _pickDocument(documentNumber),
                icon: Icon(Icons.upload_file, size: 18),
                label: Text(context.tr('Upload')),
              ),
          ],
        ),
      ),
    );
  }
}
