import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/visitor_service.dart';
import '../../widgets/desktop/desktop_ui.dart';
import '../../widgets/phone_number_field.dart';
import 'visitor_form_ui.dart';

/// Add visitor page
class AddVisitorPage extends StatefulWidget {
  final void Function(bool? result)? onClose;

  AddVisitorPage({super.key, this.onClose});

  @override
  State<AddVisitorPage> createState() => _AddVisitorPageState();
}

class _AddVisitorPageState extends State<AddVisitorPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneInput = PhoneNumberInputController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _visitDate;
  String? _churchServiceId;
  String _attendanceType = 'onsite';
  String? _visitDateError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _visitDate = DateTime.now();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneInput.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _useDesktop =>
      MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

  bool get _inShell => widget.onClose != null;

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
        _churchServiceId = null;
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
      'phone': _phoneInput.storedValue,
      'address': _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      'visit_date': VisitorFormUi.formatVisitDate(_visitDate!),
      'church_service_id': _churchServiceId,
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
        await VisitorService.createVisitor(visitorData: payload);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('church_service_id') || msg.contains('attendance_type')) {
          payload = Map<String, dynamic>.from(payload)
            ..remove('church_service_id')
            ..remove('attendance_type');
          await VisitorService.createVisitor(visitorData: payload);
        } else {
          rethrow;
        }
      }

      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.visitorAdded ?? context.tr('Visitor added successfully'),
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
    bool inShell,
  ) {
    return DesktopPageShell(
      maxWidth: kDesktopFormMaxWidth,
      isLoading: _isLoading,
      banner: DesktopHeroBanner(
        title: title,
        subtitle: context.tr('Record someone who visited the church'),
        icon: Icons.person_add_alt_1,
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
                primaryLabel: title,
                onPrimary: _handleSave,
                primaryIcon: Icons.add,
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
          PhoneNumberField(
            controller: _phoneInput,
            optional: true,
            decoration: InputDecoration(
              labelText:
                  '${localizations?.phone ?? context.tr('Phone')} $optional',
            ),
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
          VisitorFormUi.churchServiceDropdown(
            context: context,
            visitDate: _visitDate,
            value: _churchServiceId,
            onChanged: (value) => setState(() => _churchServiceId = value),
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
                  isEdit: false,
                  title: title,
                  subtitle: context.tr(
                    'Record someone who visited the church',
                  ),
                ),
                SizedBox(height: AppDimensions.spacingLG),
                _buildFormSections(context, localizations),
                SizedBox(height: AppDimensions.spacingXL),
                VisitorFormUi.mobileSaveButton(
                  context: context,
                  isLoading: _isLoading,
                  label: title,
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
    final title = context.tr('Add Visitor');
    final inShell = _inShell;
    final embedded = isDesktopEmbedded(context, inShell: inShell);

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: embedded && inShell
          ? null
          : AppBar(
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
                            : const Icon(Icons.add, size: 20),
                        label: Text(title),
                      ),
                      SizedBox(width: AppDimensions.paddingMD),
                    ]
                  : null,
            ),
      body: _useDesktop
          ? _buildDesktopBody(context, localizations, title, inShell)
          : _buildMobileBody(context, localizations, title),
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
            PhoneNumberField(
              controller: _phoneInput,
              optional: true,
              decoration: InputDecoration(
                labelText:
                    '${localizations?.phone ?? context.tr('Phone')} $optional',
              ),
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
            VisitorFormUi.churchServiceDropdown(
              context: context,
              visitDate: _visitDate,
              value: _churchServiceId,
              onChanged: (value) => setState(() => _churchServiceId = value),
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
