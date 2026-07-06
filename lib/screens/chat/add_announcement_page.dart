import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/chat_service.dart';
import '../../services/member_service.dart';
import '../../services/department_service.dart';
import '../../core/localization/app_localizations.dart';

/// Add announcement page
class AddAnnouncementPage extends StatefulWidget {
  AddAnnouncementPage({super.key});

  @override
  State<AddAnnouncementPage> createState() => _AddAnnouncementPageState();
}

class _AddAnnouncementPageState extends State<AddAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isGlobal = true;
  String? _selectedDepartmentId;
  List<String> _selectedMemberIds = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _allMembers = [];
  bool _isLoading = false;
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        DepartmentService.getDepartments(limit: 100),
        MemberService.getMembers(limit: 1000),
      ]);

      setState(() {
        _departments = results[0];
        _allMembers = results[1];
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDepartments = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading data: $e'))),
        );
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isGlobal && _selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one member for targeted announcement',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ChatService.createAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        isGlobal: _isGlobal,
        departmentId: _selectedDepartmentId,
        targetMemberIds: _isGlobal ? null : _selectedMemberIds,
      );

      // Notifications are automatically created in ChatService.createAnnouncement

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Announcement created successfully')),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error creating announcement: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error creating announcement: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showMemberSelection() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _MemberSelectionDialog(
        allMembers: _allMembers,
        selectedMemberIds: _selectedMemberIds.toSet(),
      ),
    );

    if (selected != null) {
      setState(() => _selectedMemberIds = selected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Create Announcement'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.tr('Title *'),
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter announcement title';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Message
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: context.tr('Message *'),
                  prefixIcon: Icon(Icons.message),
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter announcement message';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Is Global
              Card(
                child: SwitchListTile(
                  title: Text(context.tr('Global Announcement')),
                  subtitle: Text(
                    'Send to all members. If disabled, select specific members.',
                  ),
                  value: _isGlobal,
                  onChanged: (value) {
                    setState(() {
                      _isGlobal = value;
                      if (value) {
                        _selectedMemberIds.clear();
                        _selectedDepartmentId = null;
                      }
                    });
                  },
                  secondary: Icon(Icons.public),
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Department (optional, for filtering)
              if (!_isGlobal && _isLoadingDepartments)
                Center(child: CircularProgressIndicator())
              else if (!_isGlobal)
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartmentId,
                  decoration: InputDecoration(
                    labelText: context.tr('Department (Optional)'),
                    prefixIcon: Icon(Icons.group_work),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(context.tr('No Department')),
                    ),
                    ..._departments.map((dept) {
                      return DropdownMenuItem<String>(
                        value: dept['id'].toString(),
                        child: Text(dept['name']?.toString() ?? 'Unnamed'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedDepartmentId = value);
                  },
                ),
              SizedBox(height: AppDimensions.spacingMD),

              // Member Selection (for targeted announcements)
              if (!_isGlobal) ...[
                ElevatedButton.icon(
                  onPressed: _showMemberSelection,
                  icon: Icon(Icons.people),
                  label: Text(
                    _selectedMemberIds.isEmpty
                        ? 'Select Members'
                        : '${_selectedMemberIds.length} member(s) selected',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      AppDimensions.buttonHeightMD,
                    ),
                  ),
                ),
                if (_selectedMemberIds.isNotEmpty) ...[
                  SizedBox(height: AppDimensions.spacingSM),
                  Wrap(
                    spacing: AppDimensions.spacingXS,
                    runSpacing: AppDimensions.spacingXS,
                    children: _selectedMemberIds.map((memberId) {
                      final member = _allMembers.firstWhere(
                        (m) => m['id'].toString() == memberId,
                        orElse: () => <String, dynamic>{},
                      );
                      return Chip(
                        label: Text(
                          member.isNotEmpty
                              ? '${member['first_name']} ${member['last_name']}'
                              : 'Unknown',
                        ),
                        onDeleted: () {
                          setState(() => _selectedMemberIds.remove(memberId));
                        },
                      );
                    }).toList(),
                  ),
                ],
                SizedBox(height: AppDimensions.spacingMD),
              ],

              SizedBox(height: AppDimensions.spacingXL),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAnnouncement,
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
                    : Text(context.tr('Create Announcement')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Member selection dialog
class _MemberSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allMembers;
  final Set<String> selectedMemberIds;

  _MemberSelectionDialog({
    required this.allMembers,
    required this.selectedMemberIds,
  });

  @override
  State<_MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<_MemberSelectionDialog> {
  final _searchController = TextEditingController();
  late Set<String> _selectedMemberIds;

  @override
  void initState() {
    super.initState();
    _selectedMemberIds = Set.from(widget.selectedMemberIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return widget.allMembers;
    }
    return widget.allMembers
        .where(
          (member) =>
              (member['first_name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (member['last_name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (member['email']?.toString().toLowerCase().contains(query) ??
                  false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.tr('Search members...'),
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
            Divider(),
            // Members list
            Expanded(
              child: ListView.builder(
                itemCount: _filteredMembers.length,
                itemBuilder: (context, index) {
                  final member = _filteredMembers[index];
                  final memberId = member['id'].toString();
                  final isSelected = _selectedMemberIds.contains(memberId);

                  return CheckboxListTile(
                    title: Text(
                      '${member['first_name']} ${member['last_name']}',
                    ),
                    subtitle: Text(member['email']?.toString() ?? ''),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMemberIds.add(memberId);
                        } else {
                          _selectedMemberIds.remove(memberId);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Divider(),
            // Actions
            Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('${_selectedMemberIds.length} selected')),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Cancel')),
                      ),
                      SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedMemberIds),
                        child: Text(context.tr('Select')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
