import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/department_service.dart';
import '../../services/storage_service.dart';

/// Edit department page
class EditDepartmentPage extends StatefulWidget {
  final String departmentId;

  const EditDepartmentPage({super.key, required this.departmentId});

  @override
  State<EditDepartmentPage> createState() => _EditDepartmentPageState();
}

class _EditDepartmentPageState extends State<EditDepartmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Existing document URLs and names
  String? _existingDoc1Url;
  String? _existingDoc1Name;
  String? _existingDoc2Url;
  String? _existingDoc2Name;
  String? _existingDoc3Url;
  String? _existingDoc3Name;

  // New document files to upload
  File? _newDocument1;
  File? _newDocument2;
  File? _newDocument3;

  // New document names
  String? _newDocument1Name;
  String? _newDocument2Name;
  String? _newDocument3Name;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final department = await DepartmentService.getDepartmentById(
        widget.departmentId,
      );

      setState(() {
        _nameController.text = department['name']?.toString() ?? '';
        _descriptionController.text =
            department['description']?.toString() ?? '';

        // Load existing documents
        _existingDoc1Url = department['document_1_url']?.toString();
        _existingDoc1Name = department['document_1_name']?.toString();
        _existingDoc2Url = department['document_2_url']?.toString();
        _existingDoc2Name = department['document_2_name']?.toString();
        _existingDoc3Url = department['document_3_url']?.toString();
        _existingDoc3Name = department['document_3_name']?.toString();

        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
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
              _newDocument1 = file;
              _newDocument1Name = fileName;
              break;
            case 2:
              _newDocument2 = file;
              _newDocument2Name = fileName;
              break;
            case 3:
              _newDocument3 = file;
              _newDocument3Name = fileName;
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
          if (_newDocument1 != null) {
            _newDocument1 = null;
            _newDocument1Name = null;
          } else {
            // Mark existing document for deletion
            _existingDoc1Url = null;
            _existingDoc1Name = null;
          }
          break;
        case 2:
          if (_newDocument2 != null) {
            _newDocument2 = null;
            _newDocument2Name = null;
          } else {
            _existingDoc2Url = null;
            _existingDoc2Name = null;
          }
          break;
        case 3:
          if (_newDocument3 != null) {
            _newDocument3 = null;
            _newDocument3Name = null;
          } else {
            _existingDoc3Url = null;
            _existingDoc3Name = null;
          }
          break;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final folder = 'departments/${widget.departmentId}';
      final Map<String, dynamic> documentUpdates = {};

      // Handle document 1
      if (_newDocument1 != null) {
        // Delete old document if exists
        if (_existingDoc1Url != null) {
          try {
            await StorageService.deleteFile(_existingDoc1Url!);
          } catch (e) {
            debugPrint('Error deleting old document 1: $e');
          }
        }
        // Upload new document
        try {
          final url = await StorageService.uploadFile(
            file: _newDocument1!,
            folder: folder,
            fileName: _newDocument1Name,
          );
          documentUpdates['document_1_url'] = url;
          documentUpdates['document_1_name'] = _newDocument1Name;
        } catch (e) {
          debugPrint('Error uploading document 1: $e');
        }
      } else if (_existingDoc1Url == null && _existingDoc1Name == null) {
        // Document was removed
        documentUpdates['document_1_url'] = null;
        documentUpdates['document_1_name'] = null;
      }

      // Handle document 2
      if (_newDocument2 != null) {
        if (_existingDoc2Url != null) {
          try {
            await StorageService.deleteFile(_existingDoc2Url!);
          } catch (e) {
            debugPrint('Error deleting old document 2: $e');
          }
        }
        try {
          final url = await StorageService.uploadFile(
            file: _newDocument2!,
            folder: folder,
            fileName: _newDocument2Name,
          );
          documentUpdates['document_2_url'] = url;
          documentUpdates['document_2_name'] = _newDocument2Name;
        } catch (e) {
          debugPrint('Error uploading document 2: $e');
        }
      } else if (_existingDoc2Url == null && _existingDoc2Name == null) {
        documentUpdates['document_2_url'] = null;
        documentUpdates['document_2_name'] = null;
      }

      // Handle document 3
      if (_newDocument3 != null) {
        if (_existingDoc3Url != null) {
          try {
            await StorageService.deleteFile(_existingDoc3Url!);
          } catch (e) {
            debugPrint('Error deleting old document 3: $e');
          }
        }
        try {
          final url = await StorageService.uploadFile(
            file: _newDocument3!,
            folder: folder,
            fileName: _newDocument3Name,
          );
          documentUpdates['document_3_url'] = url;
          documentUpdates['document_3_name'] = _newDocument3Name;
        } catch (e) {
          debugPrint('Error uploading document 3: $e');
        }
      } else if (_existingDoc3Url == null && _existingDoc3Name == null) {
        documentUpdates['document_3_url'] = null;
        documentUpdates['document_3_name'] = null;
      }

      // Update department
      await DepartmentService.updateDepartment(
        departmentId: widget.departmentId,
        updates: {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          ...documentUpdates,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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
    if (_isLoadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Department')),
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
              _buildDocumentPicker(
                1,
                _existingDoc1Name,
                _newDocument1Name,
                _existingDoc1Url,
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _buildDocumentPicker(
                2,
                _existingDoc2Name,
                _newDocument2Name,
                _existingDoc2Url,
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              _buildDocumentPicker(
                3,
                _existingDoc3Name,
                _newDocument3Name,
                _existingDoc3Url,
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
                    : const Text('Update Department'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPicker(
    int documentNumber,
    String? existingFileName,
    String? newFileName,
    String? existingFileUrl,
  ) {
    final displayName = newFileName ?? existingFileName;
    final hasFile = displayName != null;
    final isNew = newFileName != null;
    final hasExisting = existingFileName != null;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile
                        ? displayName
                        : 'Document $documentNumber (Optional)',
                    style: TextStyle(
                      color: hasFile
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: hasFile ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isNew)
                    Text(
                      'New file',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else if (hasExisting && existingFileUrl != null)
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.parse(existingFileUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                ],
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
