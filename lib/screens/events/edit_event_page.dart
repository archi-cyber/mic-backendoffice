import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/event_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Edit event page
class EditEventPage extends StatefulWidget {
  final String eventId;

  /// When set (e.g. desktop stack), close uses this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  EditEventPage({super.key, required this.eventId, this.onClose});

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isRepeated = false;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final event = await EventService.getEventById(widget.eventId);
      if (!mounted) return;
      setState(() {
        _titleController.text = event['title']?.toString() ?? '';
        _descriptionController.text = event['description']?.toString() ?? '';
        _locationController.text = event['location']?.toString() ?? '';
        _isRepeated = event['is_repeated'] == true;

        if (event['event_date'] != null) {
          _selectedDate = DateTime.parse(event['event_date']);
        }

        if (event['event_time'] != null) {
          final timeStr = event['event_time'].toString();
          final parts = timeStr.split(':');
          if (parts.length >= 2) {
            _selectedTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }

        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading event: $e'))),
        );
        if (widget.onClose != null) {
          widget.onClose!(null);
        } else {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Please select an event date')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await EventService.updateEvent(
        eventId: widget.eventId,
        updates: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'event_date': _selectedDate!.toIso8601String().split('T')[0],
          'event_time': _selectedTime != null
              ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00'
              : null,
          'location': _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          'is_repeated': _isRepeated,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Event updated successfully')),
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

  void _handleCancel() {
    if (widget.onClose != null) {
      widget.onClose!(null);
    } else {
      Navigator.of(context).pop();
    }
  }

  List<Widget> _eventDetailFields(BuildContext context) {
    return [
      TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          labelText: context.tr('Event Title *'),
          prefixIcon: Icon(Icons.event),
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return context.tr('Please enter event title');
          }
          return null;
        },
        textCapitalization: TextCapitalization.words,
      ),
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _descriptionController,
        decoration: InputDecoration(
          labelText: context.tr('Description'),
          prefixIcon: Icon(Icons.description),
          border: OutlineInputBorder(),
        ),
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
      ),
      SizedBox(height: AppDimensions.spacingMD),
      InkWell(
        onTap: _selectDate,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('Event Date *'),
            prefixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder(),
          ),
          child: Text(
            _selectedDate != null
                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                : 'Select date',
            style: TextStyle(
              color: _selectedDate != null
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
      SizedBox(height: AppDimensions.spacingMD),
      InkWell(
        onTap: _selectTime,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('Event Time (Optional)'),
            prefixIcon: Icon(Icons.access_time),
            border: OutlineInputBorder(),
          ),
          child: Text(
            _selectedTime != null
                ? _selectedTime!.format(context)
                : 'Select time (optional)',
            style: TextStyle(
              color: _selectedTime != null
                  ? Theme.of(context).textTheme.bodyLarge?.color
                  : Theme.of(context).hintColor,
            ),
          ),
        ),
      ),
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _locationController,
        decoration: InputDecoration(
          labelText: context.tr('Location (Optional)'),
          prefixIcon: Icon(Icons.location_on),
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      SizedBox(height: AppDimensions.spacingMD),
      SwitchListTile(
        title: Text(context.tr('Repeated Event')),
        subtitle: Text(
          'Enable if this event repeats (e.g., weekly meetings)',
        ),
        value: _isRepeated,
        onChanged: (value) {
          setState(() => _isRepeated = value);
        },
        secondary: Icon(Icons.repeat),
      ),
    ];
  }

  Widget _buildDesktopBody(BuildContext context, {required bool inShell}) {
    return DesktopPageShell(
      maxWidth: kDesktopFormMaxWidth,
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: context.tr('Edit Event'),
        subtitle: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        icon: Icons.edit_calendar_outlined,
        accent: AppColors.primary,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopSectionCard(
              title: context.tr('Event details'),
              icon: Icons.event,
              children: _eventDetailFields(context),
            ),
            if (inShell) ...[
              SizedBox(height: AppDimensions.spacingLG),
              DesktopFormActions(
                onCancel: _handleCancel,
                primaryLabel: context.tr('Update Event'),
                onPrimary: _handleSave,
                primaryIcon: Icons.save,
                isLoading: _isLoading,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inShell = widget.onClose != null;
    final embedded = isDesktopEmbedded(context, inShell: inShell);
    final useDesktop =
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    if (_isLoadingData) {
      return Scaffold(
        appBar: embedded && inShell
            ? null
            : AppBar(
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: () => widget.onClose!(null),
                      )
                    : null,
                title: Text(context.tr('Edit Event')),
              ),
        body: useDesktop
            ? DesktopPageShell(
                isLoading: true,
                maxWidth: kDesktopFormMaxWidth,
                child: const SizedBox.shrink(),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: embedded && inShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(context.tr('Edit Event')),
              actions: useDesktop
                  ? [
                      TextButton(
                        onPressed: _handleCancel,
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(Icons.save, size: 20),
                        label: Text(context.tr('Update Event')),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: useDesktop
          ? _buildDesktopBody(context, inShell: inShell)
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
                        labelText: context.tr('Event Title *'),
                        prefixIcon: Icon(Icons.event),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('Please enter event title');
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: context.tr('Description'),
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.tr('Event Date *'),
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select date',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: context.tr('Event Time (Optional)'),
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select time (optional)',
                          style: TextStyle(
                            color: _selectedTime != null
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: context.tr('Location (Optional)'),
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Card(
                      child: SwitchListTile(
                        title: Text(context.tr('Repeated Event')),
                        subtitle: Text(
                          'Enable if this event repeats (e.g., weekly meetings)',
                        ),
                        value: _isRepeated,
                        onChanged: (value) {
                          setState(() => _isRepeated = value);
                        },
                        secondary: Icon(Icons.repeat),
                      ),
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
                          : Text(context.tr('Update Event')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
