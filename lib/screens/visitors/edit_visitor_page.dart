import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/visitor_service.dart';
import '../../widgets/desktop/desktop_ui.dart';
import 'visitor_form_ui.dart';

/// Edit visitor page with pre-filled form
class EditVisitorPage extends StatefulWidget {
  final String visitorId;
  final void Function(bool? result)? onClose;

  EditVisitorPage({super.key, required this.visitorId, this.onClose});

  @override
  State<EditVisitorPage> createState() => _EditVisitorPageState();
}

class _EditVisitorPageState extends State<EditVisitorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _visitDate;
  String? _serviceType;
  String _attendanceType = 'onsite';
  String? _visitDateError;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadVisitorData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _useDesktop =>
      MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

  bool get _inShell => widget.onClose != null;

  Future<void> _loadVisitorData() async {
    setState(() => _isLoadingData = true);
    try {
      final visitor = await VisitorService.getVisitorById(widget.visitorId);
      if (!mounted) return;
      setState(() {
        _firstNameController.text = visitor['first_name']?.toString() ?? '';
        _lastNameController.text = visitor['last_name']?.toString() ?? '';
        _emailController.text = visitor['email']?.toString() ?? '';
        _phoneController.text = visitor['phone']?.toString() ?? '';
        _addressController.text = visitor['address']?.toString() ?? '';
        _notesController.text = visitor['notes']?.toString() ?? '';
        _visitDate =
            VisitorFormUi.parseVisitDate(visitor['visit_date']) ??
            DateTime.now();
        final st = visitor['service_type']?.toString();
        _serviceType = (st == 'sunday' || st == 'wednesday') ? st : null;
        final at = visitor['attendance_type']?.toString();
        if (at == 'onsite' || at == 'online' || at == 'absent') {
          _attendanceType = at!;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error loading visitor: $e')),
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

  Future<void> _selectVisitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
        _visitDateError = null;
      });
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'visit_date': VisitorFormUi.formatVisitDate(_visitDate!),
      'service_type': _serviceType,
      'attendance_type': _attendanceType,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    };
  }

  Future<void> _handleSave() async {
    if (_visitDate == null) {
      setState(() => _visitDateError = context.tr('Visit date is required'));
    } else {
      setState(() => _visitDateError = null);
    }

    if (!_formKey.currentState!.validate() || _visitDate == null) return;

    setState(() => _isLoading = true);

    try {
      var payload = _buildPayload();
      try {
        await VisitorService.updateVisitor(
          visitorId: widget.visitorId,
          updates: payload,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('service_type') || msg.contains('attendance_type')) {
          payload = Map<String, dynamic>.from(payload)
            ..remove('service_type')
            ..remove('attendance_type');
          await VisitorService.updateVisitor(
            visitorId: widget.visitorId,
            updates: payload,
          );
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.visitorUpdated ?? 'Visitor updated successfully',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      if (widget.onClose != null) {
        widget.onClose!(true);
      } else {
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

  void _handleCancel() {
    if (widget.onClose != null) {
      widget.onClose!(null);
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _buildDesktopBody(
    BuildContext context,
    AppLocalizations? localizations,
    String title,
    String displayName,
    bool inShell,
  ) {
    return DesktopPageShell(
      maxWidth: kDesktopFormMaxWidth,
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: displayName.isEmpty ? title : displayName,
        subtitle: _visitDate != null
            ? '${context.tr('Visit')}: ${VisitorFormUi.formatVisitDateDisplay(_visitDate!)}'
            : title,
        icon: Icons.edit_note,
        accent: AppColors.primary,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopFormColumns(
              sections: _desktopFormSections(context, localizations),
            ),
            if (inShell) ...[
              SizedBox(height: AppDimensions.spacingLG),
              DesktopFormActions(
                onCancel: _handleCancel,
                primaryLabel: localizations?.save ?? 'Save',
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

  List<Widget> _desktopFormSections(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    final optional = localizations?.optional ?? context.tr('(Optional)');

    return [
      DesktopSectionCard(
        title: context.tr('Personal information'),
        icon: Icons.person_outline,
        children: [
          TextFormField(
            controller: _firstNameController,
            decoration: VisitorFormUi.fieldDecoration(
              label:
                  '${localizations?.visitorFirstName ?? context.tr('First Name')} *',
              icon: Icons.person,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations?.visitorFirstNameRequired ??
                    context.tr('Please enter first name');
              }
              return null;
            },
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _lastNameController,
            decoration: VisitorFormUi.fieldDecoration(
              label:
                  '${localizations?.visitorLastName ?? context.tr('Last Name')} *',
              icon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations?.visitorLastNameRequired ??
                    context.tr('Please enter last name');
              }
              return null;
            },
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      DesktopSectionCard(
        title: context.tr('Contact'),
        icon: Icons.contact_mail_outlined,
        accent: AppColors.info,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: VisitorFormUi.fieldDecoration(
              label: '${localizations?.email ?? context.tr('Email')} $optional',
              icon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _phoneController,
            decoration: VisitorFormUi.fieldDecoration(
              label: '${localizations?.phone ?? context.tr('Phone')} $optional',
              icon: Icons.phone_outlined,
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _addressController,
            decoration: VisitorFormUi.fieldDecoration(
              label: '${context.tr('Address')} $optional',
              icon: Icons.location_on_outlined,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      DesktopSectionCard(
        title: context.tr('Visit details'),
        icon: Icons.event_available_outlined,
        accent: AppColors.accent,
        children: [
          VisitorFormUi.visitDateField(
            context: context,
            visitDate: _visitDate,
            onTap: _selectVisitDate,
            errorText: _visitDateError,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          VisitorFormUi.serviceTypeDropdown(
            context: context,
            value: _serviceType,
            onChanged: (value) => setState(() => _serviceType = value),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          VisitorFormUi.attendanceTypeDropdown(
            context: context,
            value: _attendanceType,
            onChanged: (value) {
              if (value != null) setState(() => _attendanceType = value);
            },
          ),
        ],
      ),
      DesktopSectionCard(
        title: localizations?.notes ?? context.tr('Notes'),
        icon: Icons.notes_outlined,
        accent: AppColors.secondary,
        children: [
          TextFormField(
            controller: _notesController,
            decoration: VisitorFormUi.fieldDecoration(
              label: '${localizations?.notes ?? context.tr('Notes')} $optional',
              icon: Icons.sticky_note_2_outlined,
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    ];
  }

  Widget _buildMobileBody(
    BuildContext context,
    AppLocalizations? localizations,
    String title,
    String displayName,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: VisitorFormUi.desktopMaxWidth,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VisitorFormUi.heroBanner(
                  context: context,
                  isEdit: true,
                  title: displayName.isEmpty ? title : displayName,
                  subtitle: _visitDate != null
                      ? '${context.tr('Visit')}: ${VisitorFormUi.formatVisitDateDisplay(_visitDate!)}'
                      : title,
                ),
                SizedBox(height: AppDimensions.spacingLG),
                _buildFormSections(context, localizations),
                SizedBox(height: AppDimensions.spacingXL),
                VisitorFormUi.mobileSaveButton(
                  context: context,
                  isLoading: _isLoading,
                  label: localizations?.updateVisitor ?? 'Update Visitor',
                  onPressed: _handleSave,
                ),
                SizedBox(height: AppDimensions.spacingLG),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final title = localizations?.editVisitor ?? 'Edit Visitor';
    final inShell = _inShell;
    final embedded = isDesktopEmbedded(context, inShell: inShell);

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: context.mic.background,
        appBar: embedded && inShell
            ? null
            : AppBar(title: Text(title)),
        body: _useDesktop
            ? DesktopPageShell(
                isLoading: true,
                maxWidth: kDesktopFormMaxWidth,
                child: const SizedBox.shrink(),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final displayName =
        '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: embedded && inShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _handleCancel,
                    )
                  : null,
              title: Text(title),
              actions: _useDesktop
                  ? [
                      TextButton(
                        onPressed: _handleCancel,
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: Text(localizations?.save ?? 'Save'),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: _useDesktop
          ? _buildDesktopBody(
              context,
              localizations,
              title,
              displayName,
              inShell,
            )
          : _buildMobileBody(context, localizations, title, displayName),
    );
  }

  Widget _buildFormSections(
    BuildContext context,
    AppLocalizations? localizations,
  ) {
    final optional = localizations?.optional ?? context.tr('(Optional)');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisitorFormUi.sectionCard(
          context: context,
          title: context.tr('Personal information'),
          icon: Icons.person_outline,
          accent: AppColors.primary,
          children: [
            TextFormField(
              controller: _firstNameController,
              decoration: VisitorFormUi.fieldDecoration(
                label:
                    '${localizations?.visitorFirstName ?? context.tr('First Name')} *',
                icon: Icons.person,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations?.visitorFirstNameRequired ??
                      context.tr('Please enter first name');
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _lastNameController,
              decoration: VisitorFormUi.fieldDecoration(
                label:
                    '${localizations?.visitorLastName ?? context.tr('Last Name')} *',
                icon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations?.visitorLastNameRequired ??
                      context.tr('Please enter last name');
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        VisitorFormUi.sectionCard(
          context: context,
          title: context.tr('Contact'),
          icon: Icons.contact_mail_outlined,
          accent: AppColors.info,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: VisitorFormUi.fieldDecoration(
                label: '${localizations?.email ?? context.tr('Email')} $optional',
                icon: Icons.email_outlined,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _phoneController,
              decoration: VisitorFormUi.fieldDecoration(
                label: '${localizations?.phone ?? context.tr('Phone')} $optional',
                icon: Icons.phone_outlined,
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            TextFormField(
              controller: _addressController,
              decoration: VisitorFormUi.fieldDecoration(
                label: '${context.tr('Address')} $optional',
                icon: Icons.location_on_outlined,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        VisitorFormUi.sectionCard(
          context: context,
          title: context.tr('Visit details'),
          icon: Icons.event_available_outlined,
          accent: AppColors.accent,
          children: [
            VisitorFormUi.visitDateField(
              context: context,
              visitDate: _visitDate,
              onTap: _selectVisitDate,
              errorText: _visitDateError,
            ),
            SizedBox(height: AppDimensions.spacingMD),
            VisitorFormUi.serviceTypeDropdown(
              context: context,
              value: _serviceType,
              onChanged: (value) => setState(() => _serviceType = value),
            ),
            SizedBox(height: AppDimensions.spacingMD),
            VisitorFormUi.attendanceTypeDropdown(
              context: context,
              value: _attendanceType,
              onChanged: (value) {
                if (value != null) setState(() => _attendanceType = value);
              },
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        VisitorFormUi.sectionCard(
          context: context,
          title: localizations?.notes ?? context.tr('Notes'),
          icon: Icons.notes_outlined,
          accent: AppColors.secondary,
          children: [
            TextFormField(
              controller: _notesController,
              decoration: VisitorFormUi.fieldDecoration(
                label: '${localizations?.notes ?? context.tr('Notes')} $optional',
                icon: Icons.sticky_note_2_outlined,
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ],
    );
  }
}
