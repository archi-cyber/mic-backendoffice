import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/teaching_service.dart';
import '../../widgets/desktop/desktop_ui.dart';

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

  List<Widget> _teachingFormFields(AppLocalizations? localizations) {
    return [
      TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          labelText: '${localizations?.teachingTitle ?? 'Title'} *',
          prefixIcon: const Icon(Icons.title),
          border: const OutlineInputBorder(),
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
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _speakerController,
        decoration: InputDecoration(
          labelText:
              '${localizations?.speaker ?? 'Speaker'} ${localizations?.optional ?? '(Optional)'}',
          prefixIcon: const Icon(Icons.person),
          border: const OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _descriptionController,
        decoration: InputDecoration(
          labelText:
              '${localizations?.teachingDescription ?? 'Description'} ${localizations?.optional ?? '(Optional)'}',
          prefixIcon: const Icon(Icons.description),
          border: const OutlineInputBorder(),
        ),
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
      ),
    ];
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AppLocalizations? localizations, {
    required bool embedded,
  }) {
    return DesktopPageShell(
      maxWidth: kDesktopFormMaxWidth,
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: localizations?.editTeaching ?? 'Edit Teaching',
        subtitle: context.tr(
          'Update the teaching details without leaving the current workspace.',
        ),
        icon: Icons.edit_note_outlined,
        trailing: embedded
            ? IconButton(
                onPressed: _closeWithoutResult,
                icon: const Icon(Icons.close),
                tooltip: localizations?.cancel ?? 'Cancel',
              )
            : null,
      ),
      child: Form(
        key: _formKey,
        child: DesktopSectionCard(
          title: localizations?.teachingDetails ?? 'Teaching details',
          icon: Icons.menu_book,
          children: [
            ..._teachingFormFields(localizations),
            SizedBox(height: AppDimensions.spacingLG),
            DesktopFormActions(
              onCancel: _closeWithoutResult,
              primaryLabel: localizations?.updateTeaching ?? 'Update Teaching',
              primaryIcon: Icons.save,
              onPrimary: _handleSave,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final embedded = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );
    final useDesktopLayout =
        embedded ||
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    if (_isLoadingData) {
      return Scaffold(
        appBar: embedded
            ? null
            : AppBar(
                leading: widget.onClose != null
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => widget.onClose!(null),
                      )
                    : null,
                title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
              ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
              actions: useDesktopLayout && !embedded
                  ? [
                      TextButton(
                        onPressed: _closeWithoutResult,
                        child: Text(localizations?.cancel ?? 'Cancel'),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: Text(
                          localizations?.updateTeaching ?? 'Update Teaching',
                        ),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: useDesktopLayout
          ? _buildDesktopBody(context, localizations, embedded: embedded)
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
