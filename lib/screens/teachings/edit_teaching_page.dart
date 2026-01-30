import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
            content: Text('Error loading teaching: $e'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spacingSM),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final useDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
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
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(null),
              )
            : null,
        title: Text(localizations?.editTeaching ?? 'Edit Teaching'),
        actions: useDesktop
            ? [
                TextButton(
                  onPressed: () => widget.onClose != null
                      ? widget.onClose!(null)
                      : Navigator.of(context).pop(),
                  child: Text(localizations?.cancel ?? 'Cancel'),
                ),
                const SizedBox(width: AppDimensions.spacingSM),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: Text(
                    localizations?.updateTeaching ?? 'Update Teaching',
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingMD),
              ]
            : null,
      ),
      body: useDesktop
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLG),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _kDesktopMaxWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            const SizedBox(height: AppDimensions.spacingMD),
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
                            const SizedBox(height: AppDimensions.spacingMD),
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
                            const SizedBox(height: AppDimensions.spacingMD),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
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
                    const SizedBox(height: AppDimensions.spacingMD),
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
                    const SizedBox(height: AppDimensions.spacingMD),
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
                    const SizedBox(height: AppDimensions.spacingMD),
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
}
