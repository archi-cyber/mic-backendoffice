import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/teaching_service.dart';

/// Edit teaching page with pre-filled form
class EditTeachingPage extends StatefulWidget {
  final String teachingId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  const EditTeachingPage({super.key, required this.teachingId, this.onClose});

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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error loading teaching: $e')),
            backgroundColor: AppColors.error,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!(null);
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _selectTeachingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _teachingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
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

  Widget _desktopSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingMD),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _desktopIntroCard(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
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
            child: Icon(Icons.edit_note_outlined, color: AppColors.primary),
          ),
          SizedBox(width: AppDimensions.spacingLG),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations?.editTeaching ?? 'Edit Teaching',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  context.tr(
                    'Update the teaching details without leaving the current workspace.',
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
            tooltip: localizations?.cancel ?? 'Cancel',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;
    final useDesktopShell = widget.onClose != null && useDesktop;

    if (_isLoadingData) {
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
                title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
              ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
              actions: useDesktop
                  ? [
                      TextButton(
                        onPressed: _closeWithoutResult,
                        child: Text(localizations?.cancel ?? 'Cancel'),
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
                            : Icon(Icons.save, size: 20),
                        label: Text(
                          localizations?.updateTeaching ?? 'Update Teaching',
                        ),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: useDesktop
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingLG),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _kDesktopMaxWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _desktopIntroCard(context, localizations),
                        SizedBox(height: AppDimensions.spacingLG),
                        _desktopSectionCard(
                          context,
                          localizations?.teachingDetails ?? 'Teaching details',
                          Icons.menu_book,
                          [
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText:
                                    '${localizations?.teachingTitle ?? 'Title'} *',
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return localizations?.teachingTitleRequired ??
                                      'Please enter a title';
                                }
                                return null;
                              },
                              textCapitalization: TextCapitalization.words,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            InkWell(
                              onTap: _selectTeachingDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText:
                                      '${localizations?.teachingDate ?? 'Teaching Date'} *',
                                  prefixIcon: Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _teachingDate != null
                                      ? '${_teachingDate!.year}-${_teachingDate!.month.toString().padLeft(2, '0')}-${_teachingDate!.day.toString().padLeft(2, '0')}'
                                      : (localizations?.teachingDateRequired ??
                                            'Select date'),
                                  style: TextStyle(
                                    color: _teachingDate != null
                                        ? Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color
                                        : Theme.of(context).hintColor,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            TextFormField(
                              controller: _speakerController,
                              decoration: InputDecoration(
                                labelText:
                                    '${localizations?.speaker ?? 'Speaker'} ${localizations?.optional ?? '(Optional)'}',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                            SizedBox(height: AppDimensions.spacingMD),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                labelText:
                                    '${localizations?.teachingDescription ?? 'Description'} ${localizations?.optional ?? '(Optional)'}',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            SizedBox(height: AppDimensions.spacingLG),
                            Divider(),
                            SizedBox(height: AppDimensions.spacingMD),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _closeWithoutResult,
                                  child: Text(
                                    localizations?.cancel ?? 'Cancel',
                                  ),
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
                                      : Icon(Icons.save, size: 20),
                                  label: Text(
                                    localizations?.updateTeaching ??
                                        'Update Teaching',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText:
                            '${localizations?.teachingTitle ?? 'Title'} *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations?.teachingTitleRequired ??
                              'Please enter a title';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectTeachingDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              '${localizations?.teachingDate ?? 'Teaching Date'} *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _teachingDate != null
                              ? '${_teachingDate!.year}-${_teachingDate!.month.toString().padLeft(2, '0')}-${_teachingDate!.day.toString().padLeft(2, '0')}'
                              : (localizations?.teachingDateRequired ??
                                    'Select date'),
                          style: TextStyle(
                            color: _teachingDate != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _speakerController,
                      decoration: InputDecoration(
                        labelText:
                            '${localizations?.speaker ?? 'Speaker'} ${localizations?.optional ?? '(Optional)'}',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText:
                            '${localizations?.teachingDescription ?? 'Description'} ${localizations?.optional ?? '(Optional)'}',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
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
                          : Text(
                              localizations?.updateTeaching ??
                                  'Update Teaching',
                            ),
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
