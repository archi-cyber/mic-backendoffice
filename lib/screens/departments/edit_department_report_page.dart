import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/department_report_service.dart';

/// Edit department report page
class EditDepartmentReportPage extends StatefulWidget {
  final String reportId;

  const EditDepartmentReportPage({super.key, required this.reportId});

  @override
  State<EditDepartmentReportPage> createState() =>
      _EditDepartmentReportPageState();
}

class _EditDepartmentReportPageState extends State<EditDepartmentReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _definedObjectivesController = TextEditingController();
  final _positivePointsController = TextEditingController();
  final _difficultiesController = TextEditingController();
  final _suggestionsController = TextEditingController();
  final _commentsController = TextEditingController();
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _definedObjectivesController.dispose();
    _positivePointsController.dispose();
    _difficultiesController.dispose();
    _suggestionsController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoadingData = true);
    try {
      final report = await DepartmentReportService.getReportById(
        widget.reportId,
      );
      setState(() {
        _report = report;
        _titleController.text = report['title'] ?? '';
        _definedObjectivesController.text = report['defined_objectives'] ?? '';
        _positivePointsController.text = report['positive_points'] ?? '';
        _difficultiesController.text = report['difficulties_encountered'] ?? '';
        _suggestionsController.text = report['suggestions'] ?? '';
        _commentsController.text = report['comments'] ?? '';
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DepartmentReportService.updateReport(
        reportId: widget.reportId,
        title: _titleController.text.trim(),
        definedObjectives: _definedObjectivesController.text.trim(),
        positivePoints: _positivePointsController.text.trim(),
        difficultiesEncountered: _difficultiesController.text.trim(),
        suggestions: _suggestionsController.text.trim(),
        comments: _commentsController.text.trim().isNotEmpty
            ? _commentsController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report updated successfully'),
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
            content: Text('Error updating report: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Report Title *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _definedObjectivesController,
                decoration: const InputDecoration(
                  labelText: 'Defined Objectives *',
                  prefixIcon: Icon(Icons.flag),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Defined objectives are required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _positivePointsController,
                decoration: const InputDecoration(
                  labelText: 'Positive Points *',
                  prefixIcon: Icon(Icons.check_circle),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Positive points are required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _difficultiesController,
                decoration: const InputDecoration(
                  labelText: 'Difficulties Encountered *',
                  prefixIcon: Icon(Icons.warning),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Difficulties encountered are required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _suggestionsController,
                decoration: const InputDecoration(
                  labelText: 'Suggestions *',
                  prefixIcon: Icon(Icons.lightbulb),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Suggestions are required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _commentsController,
                decoration: const InputDecoration(
                  labelText: 'Comments',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 4,
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
                    : const Text('Update Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
