import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../services/member_service.dart';

/// Add member page with email/phone validation
class AddMemberPage extends StatefulWidget {
  const AddMemberPage({super.key});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quarterController = TextEditingController();
  final _levelOfStudyController = TextEditingController();
  final _sectorOfStudiesController = TextEditingController();
  final _domainOfActivityController = TextEditingController();
  final _lastDiplomasController = TextEditingController();
  final _keySkillsList = <String>[];
  final _keySkillInputController = TextEditingController();
  String? _selectedProfession;
  String _selectedRole = 'member';
  DateTime? _selectedBirthday;
  bool _isNewComer = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _quarterController.dispose();
    _levelOfStudyController.dispose();
    _sectorOfStudiesController.dispose();
    _domainOfActivityController.dispose();
    _keySkillInputController.dispose();
    _lastDiplomasController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthday ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Birthday',
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate: Must have at least email or phone
    if (_emailController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Member must have at least email or phone for password reset capability. '
            'Email is strongly recommended.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await MemberService.createMember(
        memberData: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'birthday': _selectedBirthday != null
              ? _selectedBirthday!.toIso8601String().split('T')[0]
              : null,
          'quarter': _quarterController.text.trim().isNotEmpty
              ? _quarterController.text.trim()
              : null,
          'profession': _selectedProfession,
          'level_of_study': _levelOfStudyController.text.trim().isNotEmpty
              ? _levelOfStudyController.text.trim()
              : null,
          'sector_of_studies': _sectorOfStudiesController.text.trim().isNotEmpty
              ? _sectorOfStudiesController.text.trim()
              : null,
          'domain_of_activity':
              _domainOfActivityController.text.trim().isNotEmpty
              ? _domainOfActivityController.text.trim()
              : null,
          'key_skills': _keySkillsList.isNotEmpty ? _keySkillsList : null,
          'last_diplomas': _lastDiplomasController.text.trim().isNotEmpty
              ? _lastDiplomasController.text.trim()
              : null,
          'role': _selectedRole,
          'is_new_comer': _isNewComer,
          'is_active': false, // Inactive until activated
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
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
      appBar: AppBar(title: const Text('Add Member')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (recommended)',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'At least email or phone is required',
                ),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !value.contains('@')) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'At least email or phone is required',
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              InkWell(
                onTap: _selectBirthday,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Birthday',
                    prefixIcon: const Icon(Icons.cake),
                    suffixIcon: const Icon(Icons.calendar_today),
                    helperText: 'Tap to select date',
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
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              TextFormField(
                controller: _quarterController,
                decoration: const InputDecoration(
                  labelText: 'Quarter',
                  prefixIcon: Icon(Icons.calendar_view_month),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              DropdownButtonFormField<String>(
                value: _selectedProfession,
                decoration: const InputDecoration(
                  labelText: 'Profession',
                  prefixIcon: Icon(Icons.work),
                  helperText: 'Select your current profession/status',
                ),
                items: MemberConstants.getProfessionOptions().map((option) {
                  return DropdownMenuItem<String>(
                    value: option['value'],
                    child: Text(option['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProfession = value;
                    // Clear dependent fields when profession changes
                    if (!MemberConstants.requiresLevelOfStudy(value)) {
                      _levelOfStudyController.clear();
                    }
                    if (!MemberConstants.requiresLastDiplomas(value)) {
                      _lastDiplomasController.clear();
                    }
                    if (!MemberConstants.requiresSectorOfStudies(value)) {
                      _sectorOfStudiesController.clear();
                    }
                    if (!MemberConstants.requiresDomainOfActivity(value)) {
                      _domainOfActivityController.clear();
                    }
                  });
                },
              ),
              // Conditionally show level_of_study
              if (MemberConstants.requiresLevelOfStudy(
                _selectedProfession,
              )) ...[
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _levelOfStudyController,
                  decoration: const InputDecoration(
                    labelText: 'Level of Study *',
                    prefixIcon: Icon(Icons.school),
                    helperText: 'Required for students',
                  ),
                  validator: (value) {
                    if (MemberConstants.requiresLevelOfStudy(
                          _selectedProfession,
                        ) &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Level of study is required';
                    }
                    return null;
                  },
                ),
              ],
              // Conditionally show sector_of_studies
              if (MemberConstants.requiresSectorOfStudies(
                _selectedProfession,
              )) ...[
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _sectorOfStudiesController,
                  decoration: const InputDecoration(
                    labelText: 'Sector of Studies *',
                    prefixIcon: Icon(Icons.category),
                    helperText:
                        'Required for secondary and university students, job seeking, and workers',
                  ),
                  validator: (value) {
                    if (MemberConstants.requiresSectorOfStudies(
                          _selectedProfession,
                        ) &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Sector of studies is required';
                    }
                    return null;
                  },
                ),
              ],
              // Conditionally show domain_of_activity
              if (MemberConstants.requiresDomainOfActivity(
                _selectedProfession,
              )) ...[
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _domainOfActivityController,
                  decoration: const InputDecoration(
                    labelText: 'Domain of Activity *',
                    prefixIcon: Icon(Icons.business),
                    helperText: 'Required for job seeking and workers',
                  ),
                  validator: (value) {
                    if (MemberConstants.requiresDomainOfActivity(
                          _selectedProfession,
                        ) &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Domain of activity is required';
                    }
                    return null;
                  },
                ),
              ],
              // Conditionally show last_diplomas
              if (MemberConstants.requiresLastDiplomas(
                _selectedProfession,
              )) ...[
                const SizedBox(height: AppDimensions.spacingMD),
                TextFormField(
                  controller: _lastDiplomasController,
                  decoration: const InputDecoration(
                    labelText: 'Last Diplomas *',
                    prefixIcon: Icon(Icons.workspace_premium),
                    helperText:
                        'Required for secondary and university students, job seeking, and workers',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (MemberConstants.requiresLastDiplomas(
                          _selectedProfession,
                        ) &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Last diplomas is required';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppDimensions.spacingMD),
              _buildKeySkillsField(),
              const SizedBox(height: AppDimensions.spacingMD),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role *',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: 'Select member role',
                ),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'leader', child: Text('Leader')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              CheckboxListTile(
                title: const Text('New Comer'),
                subtitle: const Text(
                  'Check if this is a new comer. Status will automatically change to member after 9+ service attendances in 3 months.',
                ),
                value: _isNewComer,
                onChanged: (value) {
                  setState(() {
                    _isNewComer = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
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
                    : const Text('Create Member'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeySkillsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 20),
            const SizedBox(width: AppDimensions.spacingSM),
            const Text(
              'Key Skills',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingSM),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _keySkillInputController,
                decoration: const InputDecoration(
                  hintText: 'Enter a skill',
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
            const SizedBox(width: AppDimensions.spacingSM),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final skill = _keySkillInputController.text.trim();
                if (skill.isNotEmpty) {
                  setState(() {
                    _keySkillsList.add(skill);
                    _keySkillInputController.clear();
                  });
                }
              },
              tooltip: 'Add skill',
            ),
          ],
        ),
        if (_keySkillsList.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingSM),
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
                deleteIcon: const Icon(Icons.close, size: 18),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
