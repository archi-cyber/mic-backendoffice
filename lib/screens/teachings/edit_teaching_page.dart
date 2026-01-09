import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/teaching_service.dart';

/// Edit teaching page with pre-filled form
class EditTeachingPage extends StatefulWidget {
  final String teachingId;

  const EditTeachingPage({super.key, required this.teachingId});

  @override
  State<EditTeachingPage> createState() => _EditTeachingPageState();
}

class _EditTeachingPageState extends State<EditTeachingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _speakerController = TextEditingController();
  DateTime? _teachingDate;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadTeachingData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachingData() async {
    setState(() => _isLoadingData = true);
    try {
      final teaching = await TeachingService.getTeachingById(widget.teachingId);
      setState(() {
        _titleController.text = teaching['title']?.toString() ?? '';
        _descriptionController.text = teaching['description']?.toString() ?? '';
        _speakerController.text = teaching['speaker']?.toString() ?? '';
        if (teaching['teaching_date'] != null) {
          _teachingDate = DateTime.parse(teaching['teaching_date']);
        } else {
          _teachingDate = DateTime.now();
        }
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading teaching: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _selectTeachingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _teachingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _teachingDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await TeachingService.updateTeaching(
        teachingId: widget.teachingId,
        updates: {
          'title': _titleController.text.trim(),
          'teaching_date': _teachingDate!.toIso8601String().split('T')[0],
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'speaker': _speakerController.text.trim().isEmpty
              ? null
              : _speakerController.text.trim(),
        },
      );

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.teachingUpdated ?? 'Teaching updated successfully',
            ),
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
    final localizations = AppLocalizations.of(context);
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '${localizations?.teachingTitle ?? 'Title'} *',
                  prefixIcon: const Icon(Icons.title),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations?.teachingTitleRequired ?? 'Please enter a title';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Teaching Date
              InkWell(
                onTap: _selectTeachingDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '${localizations?.teachingDate ?? 'Teaching Date'} *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    _teachingDate != null
                        ? '${_teachingDate!.year}-${_teachingDate!.month.toString().padLeft(2, '0')}-${_teachingDate!.day.toString().padLeft(2, '0')}'
                        : (localizations?.teachingDateRequired ?? 'Select date'),
                    style: TextStyle(
                      color: _teachingDate != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Speaker
              TextFormField(
                controller: _speakerController,
                decoration: InputDecoration(
                  labelText: '${localizations?.speaker ?? 'Speaker'} ${localizations?.optional ?? '(Optional)'}',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: '${localizations?.teachingDescription ?? 'Description'} ${localizations?.optional ?? '(Optional)'}',
                  prefixIcon: const Icon(Icons.description),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppDimensions.spacingXL),

              // Save Button
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
                    : Text(localizations?.updateTeaching ?? 'Update Teaching'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
