import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/department_report_service.dart';
import '../../services/department_service.dart';
import '../../core/localization/app_localizations.dart';

/// Add department report page
class AddDepartmentReportPage extends StatefulWidget {
  final String departmentId;

  AddDepartmentReportPage({super.key, required this.departmentId});

  @override
  State<AddDepartmentReportPage> createState() =>
      _AddDepartmentReportPageState();
}

class _AddDepartmentReportPageState extends State<AddDepartmentReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _definedObjectivesController = TextEditingController();
  final _positivePointsController = TextEditingController();
  final _difficultiesController = TextEditingController();
  final _suggestionsController = TextEditingController();
  final _commentsController = TextEditingController();
  Map<String, dynamic>? _department;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadDepartment();
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

  Future<void> _loadDepartment() async {
    try {
      final department = await DepartmentService.getDepartmentById(
        widget.departmentId,
      );
      setState(() {
        _department = department;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading department: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await DepartmentReportService.createReport(
        departmentId: widget.departmentId,
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
          SnackBar(
            content: Text(context.tr('Report created successfully')),
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
            content: Text(context.tr('Error creating report: ${e.toString()}')),
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
        appBar: AppBar(title: Text(context.tr('Create Report'))),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Report - ${_department?['name'] ?? 'Department'}'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.tr('Report Title *'),
                  prefixIcon: Icon(Icons.title),
                  helperText: context.tr(
                    'Enter a descriptive title for this report',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _definedObjectivesController,
                decoration: InputDecoration(
                  labelText: context.tr('Defined Objectives *'),
                  prefixIcon: Icon(Icons.flag),
                  helperText: context.tr(
                    'List the objectives that were defined',
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Defined objectives are required';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _positivePointsController,
                decoration: InputDecoration(
                  labelText: context.tr('Positive Points *'),
                  prefixIcon: Icon(Icons.check_circle),
                  helperText: context.tr(
                    'List positive achievements or points',
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Positive points are required';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _difficultiesController,
                decoration: InputDecoration(
                  labelText: context.tr('Difficulties Encountered *'),
                  prefixIcon: Icon(Icons.warning),
                  helperText: context.tr(
                    'Describe any difficulties or challenges faced',
                  ),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Difficulties encountered are required';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _suggestionsController,
                decoration: InputDecoration(
                  labelText: context.tr('Suggestions *'),
                  prefixIcon: Icon(Icons.lightbulb),
                  helperText: context.tr('Provide suggestions for improvement'),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Suggestions are required';
                  }
                  return null;
                },
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _commentsController,
                decoration: InputDecoration(
                  labelText: context.tr('Comments'),
                  prefixIcon: Icon(Icons.comment),
                  helperText: context.tr(
                    'Additional comments or notes (optional)',
                  ),
                ),
                maxLines: 4,
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
                    : Text(context.tr('Create Report')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
