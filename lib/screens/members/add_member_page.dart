import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../services/member_service.dart';
import '../../services/new_comer_service.dart';
import '../../services/storage_service.dart';
import '../../services/visitor_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';
import 'member_form_ui.dart';

/// Add member page
class AddMemberPage extends StatefulWidget {
  /// When set (e.g. desktop stack overlay), close and result use this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  AddMemberPage({super.key, this.onClose});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _quarterController = TextEditingController();
  final _sectorOfStudiesController = TextEditingController();
  final _domainOfActivityController = TextEditingController();
  final _keySkillsList = <String>[];
  final _keySkillInputController = TextEditingController();
  String? _selectedProfession;
  String? _selectedLevelOfStudy;
  String? _selectedLastDiploma;
  String _selectedRole = 'member';
  String? _selectedGender;
  String? _selectedMaritalStatus;
  bool _isActive = true;
  bool _birthdayNotificationsOptOut = false;
  DateTime? _selectedBirthday;
  bool _isNewComer = false;
  DateTime? _newcomerJoinDate;
  String? _newcomerIntention;
  bool _isLoading = false;
  String? _birthdayError;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_refreshPhotoPreview);
    _lastNameController.addListener(_refreshPhotoPreview);
  }

  void _refreshPhotoPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _quarterController.dispose();
    _sectorOfStudiesController.dispose();
    _domainOfActivityController.dispose();
    _keySkillInputController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthday ??
          DateTime.now().subtract(Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Birthday',
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayError = null;
      });
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text(context.tr('Choose from gallery')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera_outlined),
                title: Text(context.tr('Take a photo')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              SizedBox(height: AppDimensions.spacingSM),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() => _selectedPhoto = photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not pick photo: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _uploadMemberPhoto(String memberId) async {
    if (_selectedPhoto == null) return;

    final photoUrl = await StorageService.uploadMemberPhoto(
      file: File(_selectedPhoto!.path),
      memberId: memberId,
    );

    await MemberService.updateMember(
      memberId: memberId,
      updates: {'photo_url': photoUrl},
    );
  }

  Map<String, dynamic> _buildMemberDataMap() {
    return {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
      'phone': _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      'birthday': _selectedBirthday!.toIso8601String().split('T')[0],
      'address': _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      'city': _cityController.text.trim().isNotEmpty
          ? _cityController.text.trim()
          : null,
      'state': _stateController.text.trim().isNotEmpty
          ? _stateController.text.trim()
          : null,
      'zip_code': _zipCodeController.text.trim().isNotEmpty
          ? _zipCodeController.text.trim()
          : null,
      'country': _countryController.text.trim().isNotEmpty
          ? _countryController.text.trim()
          : null,
      'quarter': _quarterController.text.trim().isNotEmpty
          ? _quarterController.text.trim()
          : null,
      'profession': _selectedProfession,
      'level_of_study': _selectedLevelOfStudy,
      'sector_of_studies': _sectorOfStudiesController.text.trim().isNotEmpty
          ? _sectorOfStudiesController.text.trim()
          : null,
      'domain_of_activity': _domainOfActivityController.text.trim().isNotEmpty
          ? _domainOfActivityController.text.trim()
          : null,
      'key_skills': _keySkillsList.isNotEmpty ? _keySkillsList : null,
      'last_diplomas': _selectedLastDiploma,
      'role': _selectedRole,
      'gender': _selectedGender,
      'marital_status': _selectedMaritalStatus,
      'is_new_comer': _isNewComer,
      'newcomer_join_date': _newcomerJoinDate != null
          ? _newcomerJoinDate!.toIso8601String().split('T')[0]
          : null,
      'newcomer_intention': _newcomerIntention,
      'is_active': _isActive,
      'birthday_notifications_opt_out': _birthdayNotificationsOptOut,
    };
  }

  Future<void> _selectNewcomerJoinDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _newcomerJoinDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select Join Date',
    );
    if (picked != null) {
      setState(() {
        _newcomerJoinDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedBirthday == null) {
      setState(() => _birthdayError = 'Birthday is required');
    } else {
      setState(() => _birthdayError = null);
    }

    if (!_formKey.currentState!.validate() || _selectedBirthday == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isJustPassingNewComer =
          _isNewComer && _newcomerIntention == 'just_passing';

      if (isJustPassingNewComer) {
        await VisitorService.createVisitor(
          visitorData: {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'email': _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null,
            'phone': _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null,
            'address': _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            'visit_date': (_newcomerJoinDate ?? DateTime.now())
                .toIso8601String()
                .split('T')[0],
            'notes': 'Converted from newcomer flow (intention: just passing).',
          },
        );
        await NewComerService.createNewComerRecord(
          memberId: null,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          newcomerJoinDate: _newcomerJoinDate ?? DateTime.now(),
          newcomerIntention: 'just_passing',
        );
      } else {
        final createdMember = await MemberService.createMember(
          memberData: _buildMemberDataMap(),
        );

        if (_selectedPhoto != null) {
          await _uploadMemberPhoto(createdMember['id'].toString());
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isJustPassingNewComer
                  ? 'Visitor created successfully'
                  : 'Member created successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!(true);
        } else {
          Navigator.of(context).pop(true); // Return true to indicate success
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

  @override
  Widget build(BuildContext context) {
    final useDesktopShell =
        widget.onClose != null &&
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: useDesktopShell
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => widget.onClose!(null),
                    )
                  : null,
              title: Text(context.tr('Add Member')),
            ),
      body: useDesktopShell
          ? _buildDesktopBody(context)
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Form(key: _formKey, child: _buildFormFields(context)),
            ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return DesktopPageShell(
      isLoading: _isLoading,
      maxWidth: kDesktopFormMaxWidth,
      banner: DesktopHeroBanner(
        title: context.tr('Add Member'),
        subtitle: context.tr('Create a new church member profile'),
        icon: Icons.person_add_alt_1,
        trailing: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => widget.onClose!(null),
          tooltip: context.tr('Cancel'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopFormColumns(
              sections: [
                DesktopSectionCard(
                  title: context.tr('Personal information'),
                  icon: Icons.person,
                  accent: AppColors.primary,
                  children: _buildPersonalSection(context),
                ),
                DesktopSectionCard(
                  title: context.tr('Contact'),
                  icon: Icons.contact_phone,
                  accent: AppColors.accent,
                  children: _buildContactSection(context),
                ),
                DesktopSectionCard(
                  title: context.tr('Address'),
                  icon: Icons.home,
                  accent: AppColors.secondary,
                  children: _buildAddressSection(context),
                ),
                DesktopSectionCard(
                  title: context.tr('Professional details'),
                  icon: Icons.work,
                  accent: AppColors.info,
                  children: _buildProfessionalSection(context),
                ),
                DesktopSectionCard(
                  title: context.tr('Role & status'),
                  icon: Icons.badge,
                  accent: AppColors.warning,
                  children: _buildRoleStatusSection(context),
                ),
                DesktopSectionCard(
                  title: context.tr('Newcomer'),
                  icon: Icons.person_add,
                  accent: AppColors.primary,
                  children: _buildNewcomerSection(context),
                ),
              ],
            ),
            SizedBox(height: AppDimensions.spacingLG),
            DesktopFormActions(
              onCancel: () => widget.onClose!(null),
              primaryLabel: context.tr('Create Member'),
              onPrimary: _handleSave,
              primaryIcon: Icons.save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPersonalSection(BuildContext context) {
    return [
      _buildPhotoSection(),
      SizedBox(height: AppDimensions.spacingLG),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: context.tr('First Name *'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'First name is required' : null,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: context.tr('Last Name *'),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Last name is required' : null,
            ),
          ),
        ],
      ),
      SizedBox(height: AppDimensions.spacingMD),
      _buildBirthdayField(context),
    ];
  }

  Widget _buildPhotoSection() {
    final initials = [
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).map((part) => part[0]).join();

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: _selectedPhoto != null
                    ? FileImage(File(_selectedPhoto!.path))
                    : null,
                child: _selectedPhoto == null
                    ? Text(
                        initials.isNotEmpty ? initials.toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              Material(
                color: AppColors.primary,
                shape: CircleBorder(),
                child: InkWell(
                  onTap: _showPhotoSourceSheet,
                  customBorder: CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingSM),
          Text(
            'Profile photo (optional)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.mic.textSecondary),
          ),
          if (_selectedPhoto != null) ...[
            SizedBox(height: AppDimensions.spacingXS),
            TextButton(
              onPressed: () => setState(() => _selectedPhoto = null),
              child: Text(context.tr('Remove photo')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBirthdayField(BuildContext context) {
    return InkWell(
      onTap: _selectBirthday,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr('Birthday *'),
          prefixIcon: Icon(Icons.cake),
          suffixIcon: Icon(Icons.calendar_today),
          helperText: context.tr('Required'),
          errorText: _birthdayError,
        ),
        child: Text(
          _selectedBirthday != null
              ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
              : 'Select birthday',
          style: TextStyle(
            color: _selectedBirthday != null
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContactSection(BuildContext context) {
    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: context.tr('Email'),
          prefixIcon: Icon(Icons.email),
        ),
        validator: (v) {
          if (v != null && v.isNotEmpty && !v.contains('@')) {
            return 'Invalid email format';
          }
          return null;
        },
      ),
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: context.tr('Phone'),
          prefixIcon: Icon(Icons.phone),
        ),
      ),
    ];
  }

  List<Widget> _buildAddressSection(BuildContext context) {
    return [
      TextFormField(
        controller: _addressController,
        decoration: InputDecoration(
          labelText: context.tr('Address'),
          prefixIcon: Icon(Icons.home),
        ),
      ),
      SizedBox(height: AppDimensions.spacingMD),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: context.tr('City'),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: TextFormField(
              controller: _stateController,
              decoration: InputDecoration(
                labelText: context.tr('State'),
                prefixIcon: Icon(Icons.map),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: AppDimensions.spacingMD),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _zipCodeController,
              decoration: InputDecoration(
                labelText: context.tr('Zip Code'),
                prefixIcon: Icon(Icons.pin),
              ),
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: TextFormField(
              controller: _countryController,
              decoration: InputDecoration(
                labelText: context.tr('Country'),
                prefixIcon: Icon(Icons.public),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: AppDimensions.spacingMD),
      TextFormField(
        controller: _quarterController,
        decoration: InputDecoration(
          labelText: context.tr('Quarter'),
          prefixIcon: Icon(Icons.calendar_view_month),
        ),
      ),
    ];
  }

  List<Widget> _buildProfessionalSection(BuildContext context) {
    final list = <Widget>[
      DropdownButtonFormField<String>(
        initialValue: _selectedProfession,
        decoration: InputDecoration(
          labelText: context.tr('Profession'),
          prefixIcon: Icon(Icons.work),
          helperText: context.tr('Select your current profession/status'),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(context.tr('Not specified')),
          ),
          ...MemberConstants.getProfessionOptions().map((option) {
            return DropdownMenuItem<String>(
              value: option['value'],
              child: Text(option['label']!),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedProfession = value;
            if (value == null || !MemberConstants.requiresLevelOfStudy(value)) {
              _selectedLevelOfStudy = null;
            } else {
              _selectedLevelOfStudy = null;
            }
            if (value == null || !MemberConstants.requiresLastDiplomas(value)) {
              _selectedLastDiploma = null;
            }
            if (value == null ||
                !MemberConstants.requiresSectorOfStudies(value)) {
              _sectorOfStudiesController.clear();
            }
            if (value == null ||
                !MemberConstants.requiresDomainOfActivity(value)) {
              _domainOfActivityController.clear();
            }
          });
        },
      ),
    ];
    if (MemberConstants.requiresLevelOfStudy(_selectedProfession)) {
      list.addAll([
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedLevelOfStudy,
          decoration: InputDecoration(
            labelText: context.tr('Level of Study'),
            prefixIcon: Icon(Icons.school),
          ),
          items: MemberConstants.getLevelsOfStudy(_selectedProfession)
              .map(
                (level) =>
                    DropdownMenuItem<String>(value: level, child: Text(level)),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedLevelOfStudy = value),
        ),
      ]);
    }
    if (MemberConstants.requiresSectorOfStudies(_selectedProfession)) {
      list.addAll([
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _sectorOfStudiesController,
          decoration: InputDecoration(
            labelText: context.tr('Sector of Studies'),
            prefixIcon: Icon(Icons.category),
          ),
        ),
      ]);
    }
    if (MemberConstants.requiresDomainOfActivity(_selectedProfession)) {
      list.addAll([
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _domainOfActivityController,
          decoration: InputDecoration(
            labelText: context.tr('Domain of Activity'),
            prefixIcon: Icon(Icons.business),
          ),
        ),
      ]);
    }
    if (MemberConstants.requiresLastDiplomas(_selectedProfession)) {
      list.addAll([
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedLastDiploma,
          decoration: InputDecoration(
            labelText: context.tr('Last Diplomas'),
            prefixIcon: Icon(Icons.workspace_premium),
          ),
          items: MemberConstants.getDiplomaOptions()
              .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
              .toList(),
          onChanged: (value) => setState(() => _selectedLastDiploma = value),
        ),
      ]);
    }
    list.addAll([
      SizedBox(height: AppDimensions.spacingMD),
      _buildKeySkillsField(),
    ]);
    return list;
  }

  List<Widget> _buildRoleStatusSection(BuildContext context) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: InputDecoration(
                labelText: context.tr('Role *'),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                DropdownMenuItem(
                  value: 'member',
                  child: Text(context.tr('Member')),
                ),
                DropdownMenuItem(
                  value: 'leader',
                  child: Text(context.tr('Leader')),
                ),
                DropdownMenuItem(
                  value: 'admin',
                  child: Text(context.tr('Admin')),
                ),
                DropdownMenuItem(
                  value: 'worker',
                  child: Text(context.tr('Worker')),
                ),
                DropdownMenuItem(
                  value: 'sympathiser',
                  child: Text(context.tr('Sympathiser')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedRole = value);
              },
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Role is required' : null,
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: InputDecoration(
                labelText: context.tr('Gender'),
                prefixIcon: Icon(Icons.person),
              ),
              items: [
                DropdownMenuItem(
                  value: 'male',
                  child: Text(context.tr('Male')),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text(context.tr('Female')),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(context.tr('Other')),
                ),
              ],
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedMaritalStatus,
              decoration: InputDecoration(
                labelText: context.tr('Marital Status'),
                prefixIcon: Icon(Icons.favorite),
              ),
              items: [
                DropdownMenuItem(
                  value: 'single',
                  child: Text(context.tr('Single')),
                ),
                DropdownMenuItem(
                  value: 'married',
                  child: Text(context.tr('Married')),
                ),
                DropdownMenuItem(
                  value: 'divorced',
                  child: Text(context.tr('Divorced')),
                ),
                DropdownMenuItem(
                  value: 'widowed',
                  child: Text(context.tr('Widowed')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedMaritalStatus = value),
            ),
          ),
        ],
      ),
      SizedBox(height: AppDimensions.spacingMD),
      SwitchListTile(
        title: Text(context.tr('Active')),
        subtitle: Text(context.tr('Is this member active?')),
        value: _isActive,
        onChanged: (value) => setState(() => _isActive = value),
      ),
      SwitchListTile(
        title: Text(context.tr('Opt out of birthday notifications')),
        subtitle: Text(
          context.tr('Disable birthday notifications for this member'),
        ),
        value: _birthdayNotificationsOptOut,
        onChanged: (value) =>
            setState(() => _birthdayNotificationsOptOut = value),
      ),
    ];
  }

  List<Widget> _buildNewcomerSection(BuildContext context) {
    final list = <Widget>[
      CheckboxListTile(
        title: Text(context.tr('New Comer')),
        subtitle: Text(
          'Status will change to member after 9+ service attendances in 3 months.',
        ),
        value: _isNewComer,
        onChanged: (value) {
          setState(() {
            _isNewComer = value ?? false;
            if (!(value ?? false)) {
              _newcomerJoinDate = null;
              _newcomerIntention = null;
            }
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ];
    if (_isNewComer) {
      list.addAll([
        SizedBox(height: AppDimensions.spacingMD),
        InkWell(
          onTap: _selectNewcomerJoinDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.tr('Newcomer Join Date'),
              prefixIcon: Icon(Icons.event_available),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _newcomerJoinDate != null
                  ? '${_newcomerJoinDate!.year}-${_newcomerJoinDate!.month.toString().padLeft(2, '0')}-${_newcomerJoinDate!.day.toString().padLeft(2, '0')}'
                  : 'Select join date',
              style: TextStyle(
                color: _newcomerJoinDate != null
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor,
              ),
            ),
          ),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _newcomerIntention,
          decoration: InputDecoration(
            labelText: context.tr('Newcomer Intention'),
            prefixIcon: Icon(Icons.help_outline),
            helperText: context.tr(
              'Selecting "Just passing" creates a Visitor, not a Member.',
            ),
          ),
          items: [
            DropdownMenuItem<String>(
              value: 'wants_to_stay',
              child: Text(context.tr('Wants to stay')),
            ),
            DropdownMenuItem<String>(
              value: 'does_not_know_yet',
              child: Text(context.tr('Does not know yet')),
            ),
            DropdownMenuItem<String>(
              value: 'just_passing',
              child: Text(context.tr('Just passing')),
            ),
          ],
          onChanged: (value) => setState(() => _newcomerIntention = value),
        ),
      ]);
    }
    return list;
  }

  Widget _buildFormFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemberFormUi.heroBanner(
          context: context,
          isEdit: false,
          title: context.tr('Add Member'),
          subtitle: context.tr('Create a new church member profile'),
        ),
        SizedBox(height: AppDimensions.spacingLG),
        _buildPhotoSection(),
        SizedBox(height: AppDimensions.spacingLG),
        TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: context.tr('First Name *'),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'First name is required';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: context.tr('Last Name *'),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Last name is required';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.tr('Email'),
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty && !value.contains('@')) {
              return 'Invalid email format';
            }
            return null;
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('Phone'),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        _buildBirthdayField(context),
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: context.tr('Address'),
            prefixIcon: Icon(Icons.home),
          ),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: context.tr('City'),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: TextFormField(
                controller: _stateController,
                decoration: InputDecoration(
                  labelText: context.tr('State'),
                  prefixIcon: Icon(Icons.map),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _zipCodeController,
                decoration: InputDecoration(
                  labelText: context.tr('Zip Code'),
                  prefixIcon: Icon(Icons.pin),
                ),
              ),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: TextFormField(
                controller: _countryController,
                decoration: InputDecoration(
                  labelText: context.tr('Country'),
                  prefixIcon: Icon(Icons.public),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingMD),
        TextFormField(
          controller: _quarterController,
          decoration: InputDecoration(
            labelText: context.tr('Quarter'),
            prefixIcon: Icon(Icons.calendar_view_month),
          ),
        ),
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedProfession,
          decoration: InputDecoration(
            labelText: context.tr('Profession'),
            prefixIcon: Icon(Icons.work),
            helperText: context.tr('Select your current profession/status'),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(context.tr('Not specified')),
            ),
            ...MemberConstants.getProfessionOptions().map((option) {
              return DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['label']!),
              );
            }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedProfession = value;
              // Clear dependent fields when profession changes or is set to null
              if (value == null ||
                  !MemberConstants.requiresLevelOfStudy(value)) {
                _selectedLevelOfStudy = null;
              } else {
                // Reset level of study when profession changes
                _selectedLevelOfStudy = null;
              }
              if (value == null ||
                  !MemberConstants.requiresLastDiplomas(value)) {
                _selectedLastDiploma = null;
              }
              if (value == null ||
                  !MemberConstants.requiresSectorOfStudies(value)) {
                _sectorOfStudiesController.clear();
              }
              if (value == null ||
                  !MemberConstants.requiresDomainOfActivity(value)) {
                _domainOfActivityController.clear();
              }
            });
          },
        ),
        // Conditionally show level_of_study
        if (MemberConstants.requiresLevelOfStudy(_selectedProfession)) ...[
          SizedBox(height: AppDimensions.spacingMD),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevelOfStudy,
            decoration: InputDecoration(
              labelText: context.tr('Level of Study'),
              prefixIcon: Icon(Icons.school),
            ),
            items: MemberConstants.getLevelsOfStudy(_selectedProfession).map((
              level,
            ) {
              return DropdownMenuItem<String>(value: level, child: Text(level));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLevelOfStudy = value;
              });
            },
          ),
        ],
        // Conditionally show sector_of_studies
        if (MemberConstants.requiresSectorOfStudies(_selectedProfession)) ...[
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _sectorOfStudiesController,
            decoration: InputDecoration(
              labelText: context.tr('Sector of Studies'),
              prefixIcon: Icon(Icons.category),
            ),
          ),
        ],
        // Conditionally show domain_of_activity
        if (MemberConstants.requiresDomainOfActivity(_selectedProfession)) ...[
          SizedBox(height: AppDimensions.spacingMD),
          TextFormField(
            controller: _domainOfActivityController,
            decoration: InputDecoration(
              labelText: context.tr('Domain of Activity'),
              prefixIcon: Icon(Icons.business),
            ),
          ),
        ],
        // Conditionally show last_diplomas
        if (MemberConstants.requiresLastDiplomas(_selectedProfession)) ...[
          SizedBox(height: AppDimensions.spacingMD),
          DropdownButtonFormField<String>(
            initialValue: _selectedLastDiploma,
            decoration: InputDecoration(
              labelText: context.tr('Last Diplomas'),
              prefixIcon: Icon(Icons.workspace_premium),
            ),
            items: MemberConstants.getDiplomaOptions().map((diploma) {
              return DropdownMenuItem<String>(
                value: diploma,
                child: Text(diploma),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLastDiploma = value;
              });
            },
          ),
        ],
        SizedBox(height: AppDimensions.spacingMD),
        _buildKeySkillsField(),
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedRole,
          decoration: InputDecoration(
            labelText: context.tr('Role *'),
            prefixIcon: Icon(Icons.person_outline),
            helperText: context.tr('Select member role'),
          ),
          items: [
            DropdownMenuItem(
              value: 'member',
              child: Text(context.tr('Member')),
            ),
            DropdownMenuItem(
              value: 'leader',
              child: Text(context.tr('Leader')),
            ),
            DropdownMenuItem(value: 'admin', child: Text(context.tr('Admin'))),
            DropdownMenuItem(
              value: 'worker',
              child: Text(context.tr('Worker')),
            ),
            DropdownMenuItem(
              value: 'sympathiser',
              child: Text(context.tr('Sympathiser')),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedRole = value;
              });
            }
          },
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Role is required' : null,
        ),
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: InputDecoration(
            labelText: context.tr('Gender'),
            prefixIcon: Icon(Icons.person),
          ),
          items: [
            DropdownMenuItem(value: 'male', child: Text(context.tr('Male'))),
            DropdownMenuItem(
              value: 'female',
              child: Text(context.tr('Female')),
            ),
            DropdownMenuItem(value: 'other', child: Text(context.tr('Other'))),
          ],
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        DropdownButtonFormField<String>(
          initialValue: _selectedMaritalStatus,
          decoration: InputDecoration(
            labelText: context.tr('Marital Status'),
            prefixIcon: Icon(Icons.favorite),
          ),
          items: [
            DropdownMenuItem(
              value: 'single',
              child: Text(context.tr('Single')),
            ),
            DropdownMenuItem(
              value: 'married',
              child: Text(context.tr('Married')),
            ),
            DropdownMenuItem(
              value: 'divorced',
              child: Text(context.tr('Divorced')),
            ),
            DropdownMenuItem(
              value: 'widowed',
              child: Text(context.tr('Widowed')),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedMaritalStatus = value;
            });
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        SwitchListTile(
          title: Text(context.tr('Active')),
          subtitle: Text(context.tr('Is this member active?')),
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
            });
          },
        ),
        SwitchListTile(
          title: Text(context.tr('Opt out of birthday notifications')),
          subtitle: Text(
            context.tr('Disable birthday notifications for this member'),
          ),
          value: _birthdayNotificationsOptOut,
          onChanged: (value) {
            setState(() {
              _birthdayNotificationsOptOut = value;
            });
          },
        ),
        SizedBox(height: AppDimensions.spacingMD),
        CheckboxListTile(
          title: Text(context.tr('New Comer')),
          subtitle: Text(
            'Check if this is a new comer. Status will automatically change to member after 9+ service attendances in 3 months.',
          ),
          value: _isNewComer,
          onChanged: (value) {
            setState(() {
              _isNewComer = value ?? false;
              // Clear join date and intention if unchecked
              if (!(value ?? false)) {
                _newcomerJoinDate = null;
                _newcomerIntention = null;
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        // Show join date field only when new comer is checked
        if (_isNewComer) ...[
          SizedBox(height: AppDimensions.spacingMD),
          InkWell(
            onTap: _selectNewcomerJoinDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr('Newcomer Join Date'),
                prefixIcon: Icon(Icons.event_available),
                suffixIcon: Icon(Icons.calendar_today),
                helperText: context.tr(
                  'Select the date when the newcomer joined',
                ),
              ),
              child: Text(
                _newcomerJoinDate != null
                    ? '${_newcomerJoinDate!.year}-${_newcomerJoinDate!.month.toString().padLeft(2, '0')}-${_newcomerJoinDate!.day.toString().padLeft(2, '0')}'
                    : 'Select join date',
                style: TextStyle(
                  color: _newcomerJoinDate != null
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          DropdownButtonFormField<String>(
            initialValue: _newcomerIntention,
            decoration: InputDecoration(
              labelText: context.tr('Newcomer Intention'),
              prefixIcon: Icon(Icons.help_outline),
              helperText: context.tr(
                'Selecting "Just passing" creates a Visitor, not a Member.',
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: 'wants_to_stay',
                child: Text(context.tr('Wants to stay')),
              ),
              DropdownMenuItem<String>(
                value: 'does_not_know_yet',
                child: Text(context.tr('Does not know yet')),
              ),
              DropdownMenuItem<String>(
                value: 'just_passing',
                child: Text(context.tr('Just passing')),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _newcomerIntention = value;
              });
            },
          ),
        ],
        SizedBox(height: AppDimensions.spacingXL),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, AppDimensions.buttonHeightLG),
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('Create Member')),
        ),
      ],
    );
  }

  Widget _buildKeySkillsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, size: 20),
            SizedBox(width: AppDimensions.spacingSM),
            Text(
              'Key Skills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: AppDimensions.spacingSM),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _keySkillInputController,
                decoration: InputDecoration(
                  hintText: context.tr('Enter a skill'),
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    setState(() {
                      _keySkillsList.add(value.trim());
                      _keySkillInputController.clear();
                    });
                  }
                },
              ),
            ),
            SizedBox(width: AppDimensions.spacingSM),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: () {
                final skill = _keySkillInputController.text.trim();
                if (skill.isNotEmpty) {
                  setState(() {
                    _keySkillsList.add(skill);
                    _keySkillInputController.clear();
                  });
                }
              },
              tooltip: context.tr('Add skill'),
            ),
          ],
        ),
        if (_keySkillsList.isNotEmpty) ...[
          SizedBox(height: AppDimensions.spacingSM),
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: AppDimensions.spacingSM,
            children: _keySkillsList.map((skill) {
              return Chip(
                label: Text(skill),
                onDeleted: () {
                  setState(() {
                    _keySkillsList.remove(skill);
                  });
                },
                deleteIcon: Icon(Icons.close, size: 18),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
