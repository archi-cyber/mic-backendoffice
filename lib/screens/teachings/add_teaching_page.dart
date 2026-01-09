import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/teaching_service.dart';

/// Add teaching page
class AddTeachingPage extends StatefulWidget {
  const AddTeachingPage({super.key});

  @override
  State<AddTeachingPage> createState() => _AddTeachingPageState();
}

class _AddTeachingPageState extends State<AddTeachingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _speakerController = TextEditingController();
  DateTime? _teachingDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _teachingDate = DateTime.now();
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
      await TeachingService.createTeaching(
        teachingData: {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teaching added successfully'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Teaching')),
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
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
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
                  decoration: const InputDecoration(
                    labelText: 'Teaching Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _teachingDate != null
                        ? '${_teachingDate!.year}-${_teachingDate!.month.toString().padLeft(2, '0')}-${_teachingDate!.day.toString().padLeft(2, '0')}'
                        : 'Select date',
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
                decoration: const InputDecoration(
                  labelText: 'Speaker (Optional)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
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
                    : const Text('Add Teaching'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
