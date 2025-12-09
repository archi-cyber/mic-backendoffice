import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/chat_service.dart';
import '../../services/member_service.dart';
import '../../services/department_service.dart';

/// Edit announcement page
class EditAnnouncementPage extends StatefulWidget {
  final String announcementId;

  const EditAnnouncementPage({super.key, required this.announcementId});

  @override
  State<EditAnnouncementPage> createState() => _EditAnnouncementPageState();
}

class _EditAnnouncementPageState extends State<EditAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isGlobal = true;
  String? _selectedDepartmentId;
  List<String> _selectedMemberIds = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _allMembers = [];
  bool _isLoading = false;
  bool _isLoadingData = true;
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
        ChatService.getAnnouncementById(widget.announcementId),
        DepartmentService.getDepartments(limit: 100),
        MemberService.getMembers(limit: 1000),
      ]);

      final announcement = results[0] as Map<String, dynamic>;
      final departments = results[1] as List<Map<String, dynamic>>;
      final allMembers = results[2] as List<Map<String, dynamic>>;

      // Handle target_member_ids (UUID array)
      List<String> targetMemberIds = [];
      if (announcement['target_member_ids'] != null) {
        final targetIds = announcement['target_member_ids'];
        if (targetIds is List) {
          targetMemberIds = targetIds
              .map((id) => id?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();
        }
      }

      setState(() {
        _titleController.text = announcement['title']?.toString() ?? '';
        _messageController.text = announcement['message']?.toString() ?? '';
        _isGlobal = announcement['is_global'] == true;
        _selectedDepartmentId = announcement['department_id']?.toString();
        _selectedMemberIds = targetMemberIds;
        _departments = departments;
        _allMembers = allMembers;
        _isLoadingData = false;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _isLoadingDepartments = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading announcement: $e')),
        );
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isGlobal && _selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      await ChatService.updateAnnouncement(
        announcementId: widget.announcementId,
        updates: {
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'is_global': _isGlobal,
          'department_id': _selectedDepartmentId,
          'target_member_ids': _isGlobal ? null : _selectedMemberIds,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating announcement: $e'),
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
    if (_isLoadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Announcement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
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
              const SizedBox(height: AppDimensions.spacingMD),

              // Message
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message *',
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
              const SizedBox(height: AppDimensions.spacingMD),

              // Is Global
              Card(
                child: SwitchListTile(
                  title: const Text('Global Announcement'),
                  subtitle: const Text(
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
                  secondary: const Icon(Icons.public),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Department (optional, for filtering)
              if (!_isGlobal && _isLoadingDepartments)
                const Center(child: CircularProgressIndicator())
              else if (!_isGlobal)
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartmentId,
                  decoration: const InputDecoration(
                    labelText: 'Department (Optional)',
                    prefixIcon: Icon(Icons.group_work),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Department'),
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
              const SizedBox(height: AppDimensions.spacingMD),

              // Member Selection (for targeted announcements)
              if (!_isGlobal) ...[
                ElevatedButton.icon(
                  onPressed: _showMemberSelection,
                  icon: const Icon(Icons.people),
                  label: Text(
                    _selectedMemberIds.isEmpty
                        ? 'Select Members'
                        : '${_selectedMemberIds.length} member(s) selected',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      AppDimensions.buttonHeightMD,
                    ),
                  ),
                ),
                if (_selectedMemberIds.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSM),
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
                const SizedBox(height: AppDimensions.spacingMD),
              ],

              const SizedBox(height: AppDimensions.spacingXL),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAnnouncement,
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
                    : const Text('Update Announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Member selection dialog (reused from add_announcement_page)
class _MemberSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allMembers;
  final Set<String> selectedMemberIds;

  const _MemberSelectionDialog({
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
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
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
            const Divider(),
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
            const Divider(),
            // Actions
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_selectedMemberIds.length} selected'),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selectedMemberIds),
                        child: const Text('Select'),
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
