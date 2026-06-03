import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/church_attendance_service.dart';
import '../../services/member_service.dart';
import '../../services/visitor_service.dart';
import '../../utils/member_utils.dart';

/// Page for marking church attendance (Wednesday and Sunday services)
class ChurchAttendancePage extends StatefulWidget {
  final String? serviceDate;
  final String? serviceType;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const ChurchAttendancePage({
    super.key,
    this.serviceDate,
    this.serviceType,
    this.onClose,
  });

  @override
  State<ChurchAttendancePage> createState() => _ChurchAttendancePageState();
}

class _ChurchAttendancePageState extends State<ChurchAttendancePage> {
  late DateTime _selectedDate;
  late String _selectedServiceType;
  List<Map<String, dynamic>> _members = [];
  Map<String, String?> _memberAttendanceTypes =
      {}; // memberId -> attendanceType (null = absent)
  Map<String, String?> _visitorAttendanceTypes =
      {}; // visitorId -> attendanceType (null = absent)
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isViewMode = false;
  final TextEditingController _searchController = TextEditingController();
  /// null = all, 'onsite', 'online', 'absent', 'child' (members age 0–12)
  String? _selectedAttendanceFilter;
  /// Visitors logged for the selected service date (`visit_date`).
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    // Initialize from arguments if provided
    if (widget.serviceDate != null && widget.serviceType != null) {
      _selectedDate = DateTime.parse(widget.serviceDate!);
      _selectedServiceType = widget.serviceType!;
      _isViewMode = true;
    } else {
      _selectedDate = DateTime.now();
      _selectedServiceType = 'sunday';
    }
    _searchController.addListener(() {
      setState(() {}); // Rebuild when search text changes
    });
    // Must load members before attendance: _loadExistingAttendance() merges API
    // rows with _members. If both run in parallel, attendance often finishes first
    // and builds an empty list — service details then show no records intermittently.
    _bootstrapData();
  }

  Future<void> _bootstrapData() async {
    await _loadMembers();
    if (!mounted) return;
    await Future.wait([
      _loadVisitorsFromTable(),
      _loadExistingAttendance(),
    ]);
  }

  Map<String, Map<String, dynamic>> get _membersById {
    final map = <String, Map<String, dynamic>>{};
    for (final member in _members) {
      final id = member['id']?.toString();
      if (id != null && id.isNotEmpty) {
        map[id] = member;
      }
    }
    return map;
  }

  void _enrichAttendanceRecordMember(Map<String, dynamic> record) {
    final memberId = record['member_id']?.toString();
    if (memberId == null) return;

    final fromMembers = _membersById[memberId];
    final existing = record['member'] as Map<String, dynamic>?;
    final member = Map<String, dynamic>.from(existing ?? {});

    if (fromMembers != null) {
      member['id'] = memberId;
      member['first_name'] ??= fromMembers['first_name'];
      member['last_name'] ??= fromMembers['last_name'];
      member['email'] ??= fromMembers['email'];
      member['is_new_comer'] = fromMembers['is_new_comer'] == true;
      member['birthday'] ??= fromMembers['birthday'];
    }

    record['member'] = member;
  }

  String _formatDateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String? _visitorVisitDateKey(Map<String, dynamic> visitor) {
    final raw = visitor['visit_date'];
    if (raw == null) return null;
    return raw.toString().split('T').first;
  }

  bool _visitorMatchesSelectedService(Map<String, dynamic> visitor) {
    final serviceType = visitor['service_type']?.toString();
    if (serviceType == null || serviceType.isEmpty) {
      return true;
    }
    return serviceType == _selectedServiceType;
  }

  /// Visitors logged for the currently selected service date (and type).
  bool _visitorLoggedForSelectedService(Map<String, dynamic> visitor) {
    if (_visitorVisitDateKey(visitor) != _formatDateOnly(_selectedDate)) {
      return false;
    }
    return _visitorMatchesSelectedService(visitor);
  }

  List<Map<String, dynamic>> get _visitorsForSelectedService {
    return _visitors.where(_visitorLoggedForSelectedService).toList();
  }

  String? _visitorAttendanceFromDb(Map<String, dynamic> visitor) {
    final at = visitor['attendance_type']?.toString();
    if (at == 'onsite' || at == 'online') return at;
    return null;
  }

  bool _visitorAttended(Map<String, dynamic> visitor) {
    final at = visitor['attendance_type']?.toString();
    return at == 'onsite' || at == 'online';
  }

  void _syncVisitorAttendanceTypes() {
    final updated = <String, String?>{};
    for (final visitor in _visitors) {
      if (!_visitorLoggedForSelectedService(visitor)) continue;
      final id = visitor['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      updated[id] = _visitorAttendanceFromDb(visitor);
    }
    _visitorAttendanceTypes = updated;
  }

  Future<void> _saveVisitorsAttendance() async {
    final savedIds = <String>{};

    for (final entry in _visitorAttendanceTypes.entries) {
      final visitorId = entry.key;
      if (visitorId.isEmpty) continue;
      final effectiveType = entry.value ?? 'absent';
      await VisitorService.updateVisitor(
        visitorId: visitorId,
        updates: {
          'attendance_type': effectiveType,
          'visit_date': _formatDateOnly(_selectedDate),
          'service_type': _selectedServiceType,
        },
      );
      savedIds.add(visitorId);
    }

    for (final visitor in _visitorsForSelectedService) {
      final visitorId = visitor['id']?.toString() ?? '';
      if (visitorId.isEmpty || savedIds.contains(visitorId)) continue;
      await VisitorService.updateVisitor(
        visitorId: visitorId,
        updates: {
          'attendance_type': 'absent',
          'visit_date': _formatDateOnly(_selectedDate),
          'service_type': _selectedServiceType,
        },
      );
    }
  }

  /// All rows from the `visitors` table (same source as the Visitors screen).
  Future<void> _loadVisitorsFromTable() async {
    try {
      final fromTable = await VisitorService.getVisitors(limit: 500);
      _sortVisitors(fromTable);
      if (mounted) {
        setState(() {
          _visitors = fromTable;
          _syncVisitorAttendanceTypes();
        });
      }
    } catch (e) {
      debugPrint('Error loading visitors from table: $e');
      if (mounted) {
        setState(() => _visitors = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load visitors: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final allMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'first_name',
        ascending: true,
      );

      setState(() {
        _members = allMembers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadExistingAttendance() async {
    try {
      final attendance = await ChurchAttendanceService.getServiceAttendance(
        serviceDate: _selectedDate,
        serviceType: _selectedServiceType,
      );

      // Create a map of member IDs to attendance records
      final attendanceMap = <String, Map<String, dynamic>>{};
      for (var record in attendance) {
        final memberId = record['member_id']?.toString();
        if (memberId != null) {
          attendanceMap[memberId] = record;
        }
      }

      // Ensure all active members have attendance records
      // If a member doesn't have a record, create an absent record for display
      final allAttendanceRecords = <Map<String, dynamic>>[];
      final memberAttendanceTypesMap = <String, String?>{};
      final processedMemberIds = <String>{};

      for (var member in _members) {
        final memberId = member['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        if (attendanceMap.containsKey(memberId)) {
          // Member has an attendance record
          final record = attendanceMap[memberId]!;
          allAttendanceRecords.add(record);
          processedMemberIds.add(memberId);
          final attendanceType = record['attendance_type']?.toString();
          // Store attendance type (null for absent in edit mode)
          memberAttendanceTypesMap[memberId] = attendanceType == 'absent'
              ? null
              : attendanceType;
        } else {
          // Member doesn't have a record - create absent record for display
          final absentRecord = {
            'id': null, // No database ID since it's not saved yet
            'member_id': memberId,
            'service_date': _selectedDate.toIso8601String().split('T')[0],
            'service_type': _selectedServiceType,
            'attendance_type': 'absent',
            'member': {
              'id': memberId,
              'first_name': member['first_name'] ?? '',
              'last_name': member['last_name'] ?? '',
              'email': member['email'] ?? '',
              'is_new_comer': member['is_new_comer'] == true,
              'birthday': member['birthday'],
            },
            'created_at': null,
          };
          allAttendanceRecords.add(absentRecord);
          memberAttendanceTypesMap[memberId] =
              null; // null means absent in edit mode
        }
      }

      // Preserve historical records for members that are no longer active so
      // service details still show complete past data.
      for (final record in attendance) {
        final memberId = record['member_id']?.toString();
        if (memberId != null && !processedMemberIds.contains(memberId)) {
          allAttendanceRecords.add(record);
        }
      }

      for (final record in allAttendanceRecords) {
        _enrichAttendanceRecordMember(record);
      }

      setState(() {
        _attendanceRecords = allAttendanceRecords;
        _memberAttendanceTypes = memberAttendanceTypesMap;
      });
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
    }
  }

  void _sortVisitors(List<Map<String, dynamic>> visitors) {
    visitors.sort((a, b) {
      final nameA =
          '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.toLowerCase();
      final nameB =
          '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  bool _isVisitorDisplayRecord(Map<String, dynamic> record) {
    return record['is_visitor'] == true;
  }

  Map<String, dynamic> _visitorDisplayRecord(Map<String, dynamic> visitor) {
    final raw = visitor['attendance_type']?.toString();
    final attendanceType =
        raw == 'onsite' || raw == 'online' || raw == 'absent' ? raw! : 'absent';
    return {
      'is_visitor': true,
      'visitor_id': visitor['id'],
      'attendance_type': attendanceType,
      'member': {
        'first_name': visitor['first_name'] ?? '',
        'last_name': visitor['last_name'] ?? '',
        'email': visitor['email'],
        'phone': visitor['phone'],
      },
      'created_at': visitor['created_at'],
    };
  }

  Widget _buildVisitorTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Visitor',
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredVisitors {
    final base = _isViewMode ? _visitorsForSelectedService : _visitors;
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      return base;
    }
    return base.where((visitor) {
      final firstName = (visitor['first_name'] ?? '').toString().toLowerCase();
      final lastName = (visitor['last_name'] ?? '').toString().toLowerCase();
      final email = (visitor['email'] ?? '').toString().toLowerCase();
      final phone = (visitor['phone'] ?? '').toString().toLowerCase();
      return firstName.contains(searchQuery) ||
          lastName.contains(searchQuery) ||
          '$firstName $lastName'.contains(searchQuery) ||
          email.contains(searchQuery) ||
          phone.contains(searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredViewListItems {
    if (_selectedAttendanceFilter == 'visitor') {
      return _filteredVisitors.map(_visitorDisplayRecord).toList();
    }
    final memberRecords = _filteredAttendanceRecords;
    final visitorRecords = _filteredVisitors.map(_visitorDisplayRecord).where(
      (record) {
        if (_selectedAttendanceFilter == null) return true;
        final at = record['attendance_type']?.toString();
        return at == _selectedAttendanceFilter;
      },
    ).toList();

    if (_selectedAttendanceFilter != null) {
      return [...memberRecords, ...visitorRecords];
    }
    return [...memberRecords, ...visitorRecords];
  }

  Future<void> _showAddVisitorDialog() async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    final dateLabel = DateFormat('MMM d, yyyy').format(_selectedDate);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Visitor'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Visit date: $dateLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final visitorData = {
                          'first_name': firstNameController.text.trim(),
                          'last_name': lastNameController.text.trim(),
                          'phone': phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          'visit_date': _formatDateOnly(_selectedDate),
                          'service_type': _selectedServiceType,
                          'attendance_type': 'onsite',
                          'notes': notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        };
                        try {
                          await VisitorService.createVisitor(
                            visitorData: visitorData,
                          );
                        } catch (e) {
                          final msg = e.toString();
                          if (msg.contains('service_type') ||
                              msg.contains('attendance_type')) {
                            final withoutOptional = Map<String, dynamic>.from(
                              visitorData,
                            )
                              ..remove('service_type')
                              ..remove('attendance_type');
                            await VisitorService.createVisitor(
                              visitorData: withoutOptional,
                            );
                          } else {
                            rethrow;
                          }
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );

    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    notesController.dispose();

    if (saved == true && mounted) {
      await _loadVisitorsFromTable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor added'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _removeVisitor(String visitorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Visitor'),
        content: const Text(
          'Remove this visitor from today\'s visit log?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await VisitorService.deleteVisitor(visitorId);
      await _loadVisitorsFromTable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing visitor: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Select Service Date',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _memberAttendanceTypes.clear();
        _visitorAttendanceTypes.clear();
      });
      await Future.wait([
        _loadVisitorsFromTable(),
        _loadExistingAttendance(),
      ]);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      // Keep historical rows intact: update existing records in-place and only
      // insert missing ones for this service. Do not soft-delete/recreate rows.
      final existingRecordByMemberId = <String, Map<String, dynamic>>{};
      for (final record in _attendanceRecords) {
        final memberId = record['member_id']?.toString();
        final attendanceId = record['id']?.toString();
        if (memberId != null && memberId.isNotEmpty && attendanceId != null) {
          existingRecordByMemberId[memberId] = record;
        }
      }

      // Group members by attendance type
      // Members with null or no selection are automatically marked as absent
      final onsiteMembers = <String>[];
      final onlineMembers = <String>[];
      final absentMembers = <String>[];
      final updates = <Map<String, String>>[];

      // Process ALL active members - ensure every member is accounted for
      for (var member in _members) {
        final memberId = member['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        final attendanceType = _memberAttendanceTypes[memberId];

        if (attendanceType == 'onsite') {
          if (existingRecordByMemberId.containsKey(memberId)) {
            updates.add({
              'id': existingRecordByMemberId[memberId]!['id'].toString(),
              'type': 'onsite',
            });
          } else {
            onsiteMembers.add(memberId);
          }
        } else if (attendanceType == 'online') {
          if (existingRecordByMemberId.containsKey(memberId)) {
            updates.add({
              'id': existingRecordByMemberId[memberId]!['id'].toString(),
              'type': 'online',
            });
          } else {
            onlineMembers.add(memberId);
          }
        } else {
          // If null or not selected, mark as absent
          // This ensures every member is marked (either present or absent)
          if (existingRecordByMemberId.containsKey(memberId)) {
            updates.add({
              'id': existingRecordByMemberId[memberId]!['id'].toString(),
              'type': 'absent',
            });
          } else {
            absentMembers.add(memberId);
          }
        }
      }

      // Update existing attendance records
      for (final update in updates) {
        await ChurchAttendanceService.updateAttendance(
          attendanceId: update['id']!,
          attendanceType: update['type']!,
        );
      }

      // Insert attendance records only for members not already recorded
      if (onsiteMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: onsiteMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'onsite',
        );
      }
      if (onlineMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: onlineMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'online',
        );
      }
      if (absentMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: absentMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'absent',
        );
      }

      await _saveVisitorsAttendance();

      // Reload to reflect server state in view mode
      await Future.wait([
        _loadVisitorsFromTable(),
        _loadExistingAttendance(),
      ]);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _editAttendance(String attendanceId, String currentType) async {
    String? selectedType = currentType;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Attendance Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Onsite'),
                subtitle: const Text('Attended in person'),
                value: 'onsite',
                groupValue: selectedType,
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Online'),
                subtitle: const Text('Attended virtually'),
                value: 'online',
                groupValue: selectedType,
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Absent'),
                subtitle: const Text('Was not present'),
                value: 'absent',
                groupValue: selectedType,
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null && selectedType != currentType) {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedType != null && selectedType != currentType) {
      try {
        await ChurchAttendanceService.updateAttendance(
          attendanceId: attendanceId,
          attendanceType: selectedType,
        );
        _loadExistingAttendance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating attendance: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeAttendance(String attendanceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Attendance'),
        content: const Text(
          'Are you sure you want to remove this attendance record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ChurchAttendanceService.removeAttendance(attendanceId);
        _loadExistingAttendance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance removed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing attendance: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
              )
            : null,
        title: Text(_isViewMode ? 'Service Details' : 'Mark Attendance'),
        actions: [
          if (_isViewMode) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: _showAddVisitorDialog,
              tooltip: 'Add Visitor',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isViewMode = false;
                  // Ensure existing attendance is loaded into edit state
                  // Note: 'absent' records are set to null (not selected)
                  for (var record in _attendanceRecords) {
                    final memberId = record['member_id']?.toString();
                    if (memberId != null) {
                      final attendanceType = record['attendance_type']
                          ?.toString();
                      _memberAttendanceTypes[memberId] =
                          attendanceType == 'absent' ? null : attendanceType;
                    }
                  }
                  _syncVisitorAttendanceTypes();
                });
                _loadVisitorsFromTable();
              },
              tooltip: 'Edit Attendance',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: _showAddVisitorDialog,
              tooltip: 'Add Visitor',
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveAttendance,
                tooltip: 'Save Attendance',
              ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _buildBodyColumn(),
              ),
            )
          : _buildBodyColumn(),
    );
  }

  Widget _buildBodyColumn() {
    return Column(
      children: [
        // Date and Service Type Selector
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingMD),
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isViewMode ? null : _selectDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Service Date',
                          prefixIcon: const Icon(Icons.calendar_today),
                          filled: _isViewMode,
                          fillColor: _isViewMode
                              ? Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedServiceType,
                      decoration: InputDecoration(
                        labelText: 'Service Type',
                        prefixIcon: const Icon(Icons.church),
                        isDense: true,
                        filled: _isViewMode,
                        fillColor: _isViewMode
                            ? Theme.of(
                                context,
                              ).disabledColor.withValues(alpha: 0.1)
                            : null,
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'sunday',
                          child: Text(
                            'Sunday Service',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'wednesday',
                          child: Text(
                            'Wednesday Service',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      selectedItemBuilder: (BuildContext context) {
                        return ['sunday', 'wednesday'].map((String value) {
                          return Text(
                            value == 'sunday' ? 'Sunday' : 'Wednesday',
                            overflow: TextOverflow.ellipsis,
                          );
                        }).toList();
                      },
                      onChanged: _isViewMode
                          ? null
                          : (value) async {
                              if (value != null) {
                                setState(() {
                                  _selectedServiceType = value;
                                  _memberAttendanceTypes.clear();
                                  _visitorAttendanceTypes.clear();
                                });
                                await Future.wait([
                                  _loadVisitorsFromTable(),
                                  _loadExistingAttendance(),
                                ]);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              Builder(
                builder: (context) {
                  // Count attended (members with non-null attendance types)
                  int attendedCount = 0;
                  for (var member in _members) {
                    final memberId = member['id']?.toString() ?? '';
                    final attendanceType = _memberAttendanceTypes[memberId];
                    if (attendanceType != null) {
                      attendedCount++;
                    }
                  }
                  // Absent count is total members minus those who attended
                  final absentCount = _members.length - attendedCount;

                  final visitorCount = _visitorsForSelectedService
                      .where(_visitorAttended)
                      .length;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '$attendedCount attended, $absentCount absent'
                          '${visitorCount > 0 ? ', $visitorCount visitor${visitorCount == 1 ? '' : 's'}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (_isViewMode)
                        Text(
                          'View Mode',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        // Members List or Attendance Details
        Expanded(
          child: _isViewMode
              ? _buildViewModeContent()
              : _buildEditModeContent(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      return _members;
    }

    return _members.where((member) {
      final firstName = (member['first_name'] ?? '').toString().toLowerCase();
      final lastName = (member['last_name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      final phone = (member['phone'] ?? '').toString().toLowerCase();

      return firstName.contains(searchQuery) ||
          lastName.contains(searchQuery) ||
          '$firstName $lastName'.contains(searchQuery) ||
          email.contains(searchQuery) ||
          phone.contains(searchQuery);
    }).toList();
  }

  List<({bool isVisitor, Map<String, dynamic> data})>
      get _combinedMarkAttendanceList {
    final entries = <({bool isVisitor, Map<String, dynamic> data})>[
      ..._filteredVisitors.map((v) => (isVisitor: true, data: v)),
      ..._filteredMembers.map((m) => (isVisitor: false, data: m)),
    ];
    entries.sort((a, b) {
      final la = (a.data['last_name'] ?? '').toString().toLowerCase();
      final lb = (b.data['last_name'] ?? '').toString().toLowerCase();
      final fa = (a.data['first_name'] ?? '').toString().toLowerCase();
      final fb = (b.data['first_name'] ?? '').toString().toLowerCase();
      final lastCmp = la.compareTo(lb);
      if (lastCmp != 0) return lastCmp;
      final firstCmp = fa.compareTo(fb);
      if (firstCmp != 0) return firstCmp;
      if (a.isVisitor == b.isVisitor) return 0;
      return a.isVisitor ? 1 : -1;
    });
    return entries;
  }

  Widget _buildEditModeContent() {
    final combinedList = _combinedMarkAttendanceList;

    if (_members.isEmpty && _visitors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No active members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingLG),
            FilledButton.icon(
              onPressed: _showAddVisitorDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Visitor'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search members and visitors...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMD),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSM),
              IconButton.filled(
                onPressed: _showAddVisitorDialog,
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Add Visitor',
              ),
            ],
          ),
        ),
        Expanded(
          child: combinedList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        'No results found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          'Try adjusting your search',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacingMD,
                  ),
                  itemCount: combinedList.length,
                  itemBuilder: (context, index) {
                    final item = combinedList[index];
                    if (item.isVisitor) {
                      return _buildVisitorEditTile(item.data);
                    }
                    return _buildMemberEditTile(item.data);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceListRow({
    required Widget leading,
    required String title,
    Widget? subtitle,
    required List<Widget> actions,
    EdgeInsetsGeometry? margin,
  }) {
    return Card(
      margin: margin ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingXS,
          ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSM,
          vertical: AppDimensions.spacingXS,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: AppDimensions.spacingSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle,
                  ],
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTypeDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButton<String>(
      value: value,
      isDense: true,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem<String>(
          value: 'onsite',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.church, size: 16, color: AppColors.success),
              SizedBox(width: 8),
              Text('Onsite'),
            ],
          ),
        ),
        DropdownMenuItem<String>(
          value: 'online',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_call, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Online'),
            ],
          ),
        ),
        DropdownMenuItem<String>(
          value: 'absent',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Absent'),
            ],
          ),
        ),
      ],
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  CircleAvatar _attendanceAvatar(String? attendanceType) {
    final color = attendanceType == null || attendanceType == 'absent'
        ? AppColors.error
        : attendanceType == 'onsite'
        ? AppColors.success
        : AppColors.primary;
    final icon = attendanceType == null || attendanceType == 'absent'
        ? Icons.cancel_outlined
        : attendanceType == 'onsite'
        ? Icons.church
        : Icons.video_call;
    return CircleAvatar(
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildVisitorEditTile(Map<String, dynamic> visitor) {
    final firstName = visitor['first_name'] ?? '';
    final lastName = visitor['last_name'] ?? '';
    final visitorId = visitor['id']?.toString() ?? '';
    final forThisService = _visitorLoggedForSelectedService(visitor);
    final stored = _visitorAttendanceTypes[visitorId];
    final currentAttendanceType = stored ??
        (forThisService ? _visitorAttendanceFromDb(visitor) : null);
    final menuValue = currentAttendanceType ?? 'absent';

    return _buildAttendanceListRow(
      leading: _attendanceAvatar(currentAttendanceType),
      title: '$firstName $lastName',
      subtitle: Wrap(
        spacing: AppDimensions.spacingXS,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildVisitorTag(),
          if (!forThisService)
            Text(
              'Other visit date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        _buildAttendanceTypeDropdown(
          value: menuValue,
          onChanged: (value) {
            setState(() {
              _visitorAttendanceTypes[visitorId] =
                  value == 'absent' ? null : value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMemberEditTile(Map<String, dynamic> member) {
    final memberId = member['id']?.toString() ?? '';
    final firstName = member['first_name'] ?? '';
    final lastName = member['last_name'] ?? '';
    final isNewComer = member['is_new_comer'] == true;
    final currentAttendanceType = _memberAttendanceTypes[memberId];

    final menuValue = currentAttendanceType ?? 'absent';

    return _buildAttendanceListRow(
      leading: _attendanceAvatar(currentAttendanceType),
      title: '$firstName $lastName',
      subtitle: isNewComer
          ? Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.star, size: 16, color: AppColors.warning),
                Text(
                  'New Comer',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          : null,
      actions: [
        _buildAttendanceTypeDropdown(
          value: menuValue,
          onChanged: (value) {
            setState(() {
              _memberAttendanceTypes[memberId] =
                  value == 'absent' ? null : value;
            });
          },
        ),
      ],
    );
  }

  DateTime? _parseMemberBirthday(Map<String, dynamic>? member) {
    if (member == null) return null;
    final birthday = member['birthday'];
    if (birthday == null) return null;
    try {
      if (birthday is String) return DateTime.parse(birthday);
      if (birthday is DateTime) return birthday;
    } catch (_) {}
    return null;
  }

  bool _attendanceRecordIsChild(Map<String, dynamic> record) {
    final member = record['member'] as Map<String, dynamic>?;
    return MemberUtils.getAgeCategory(_parseMemberBirthday(member)) == 'child';
  }

  bool _attendanceRecordIsNewComer(Map<String, dynamic> record) {
    final member = record['member'] as Map<String, dynamic>?;
    return member?['is_new_comer'] == true;
  }

  bool _attendanceRecordIsNewComerChild(Map<String, dynamic> record) {
    return _attendanceRecordIsChild(record) &&
        _attendanceRecordIsNewComer(record);
  }

  int _uniqueOnsiteMemberCount(Iterable<Map<String, dynamic>> records) {
    return records
        .map((r) => r['member_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .length;
  }

  List<Map<String, dynamic>> get _filteredAttendanceRecords {
    var filtered = _attendanceRecords;

    if (_selectedAttendanceFilter == 'child') {
      filtered = filtered.where(_attendanceRecordIsChild).toList();
    } else if (_selectedAttendanceFilter != null) {
      filtered = filtered.where((record) {
        final attendanceType = record['attendance_type']?.toString();
        return attendanceType == _selectedAttendanceFilter;
      }).toList();
    }

    // Filter by search query
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final member = record['member'] as Map<String, dynamic>?;
        if (member == null) return false;

        final firstName = (member['first_name'] ?? '').toString().toLowerCase();
        final lastName = (member['last_name'] ?? '').toString().toLowerCase();
        final email = (member['email'] ?? '').toString().toLowerCase();
        final phone = (member['phone'] ?? '').toString().toLowerCase();

        return firstName.contains(searchQuery) ||
            lastName.contains(searchQuery) ||
            '$firstName $lastName'.contains(searchQuery) ||
            email.contains(searchQuery) ||
            phone.contains(searchQuery);
      }).toList();
    }

    return filtered;
  }

  Widget _buildViewModeContent() {
    final filteredItems = _filteredViewListItems;

    // Show message only if there are no members at all
    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No active members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_attendanceRecords.isEmpty && _visitorsForSelectedService.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No attendance recorded for this service',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSM),
            Text(
              'Tap Edit to mark attendance or add visitors',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Bar and Filter
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search members and visitors...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSM),
              // Attendance Type Filter
              Row(
                children: [
                  Text(
                    'Filter:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSM),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'All',
                            value: null,
                            icon: Icons.filter_list,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          _buildFilterChip(
                            label: 'Onsite',
                            value: 'onsite',
                            icon: Icons.church,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          _buildFilterChip(
                            label: 'Online',
                            value: 'online',
                            icon: Icons.video_call,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          _buildFilterChip(
                            label: 'Absent',
                            value: 'absent',
                            icon: Icons.cancel_outlined,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          _buildFilterChip(
                            label: 'Children',
                            value: 'child',
                            icon: Icons.child_care,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          _buildFilterChip(
                            label: 'Visitors',
                            value: 'visitor',
                            icon: Icons.person_add_alt_1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Summary Card
        Builder(
          builder: (context) {
            // "Attended" breakdown: onsite categories + online separately.
            final onsiteRecords = _attendanceRecords.where((record) {
              return record['attendance_type']?.toString() == 'onsite';
            }).toList();
            final onlineRecords = _attendanceRecords.where((record) {
              return record['attendance_type']?.toString() == 'online';
            }).toList();

            final childrenAttended = onsiteRecords
                .where(_attendanceRecordIsChild)
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            final newComerChildrenAttended = onsiteRecords
                .where(_attendanceRecordIsNewComerChild)
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            final newComersAttended = onsiteRecords
                .where(_attendanceRecordIsNewComer)
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            final adultsAttended = onsiteRecords
                .where((record) {
                  return !_attendanceRecordIsChild(record) &&
                      !_attendanceRecordIsNewComer(record);
                })
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            final onlineAttended = onlineRecords
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            final totalExcludingOnline = _uniqueOnsiteMemberCount(onsiteRecords);

            return Container(
              margin: const EdgeInsets.all(AppDimensions.spacingMD),
              padding: const EdgeInsets.all(AppDimensions.spacingMD),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryLine(
                    'Children attended',
                    childrenAttended,
                    Icons.child_care,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'New comer children attended',
                    newComerChildrenAttended,
                    Icons.child_care,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'Adults attended',
                    adultsAttended,
                    Icons.people,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'New comers attended',
                    newComersAttended,
                    Icons.star,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'Visitors attended',
                    _visitorsForSelectedService.where(_visitorAttended).length,
                    Icons.person_add_alt_1,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'Online attendance',
                    onlineAttended,
                    Icons.video_call,
                  ),
                  const SizedBox(height: AppDimensions.spacingXS),
                  _buildSummaryLine(
                    'Total (excluding online)',
                    totalExcludingOnline,
                    Icons.calculate,
                  ),
                ],
              ),
            );
          },
        ),
        // Attendance List
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        'No results found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_searchController.text.isNotEmpty ||
                          _selectedAttendanceFilter != null) ...[
                        const SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          'Try adjusting search or filters',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMD,
                  ),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final record = filteredItems[index];
                    if (_isVisitorDisplayRecord(record)) {
                      return _buildVisitorViewTile(record);
                    }
                    return _buildMemberViewTile(record);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _editVisitorAttendance(
    String visitorId,
    String currentType,
  ) async {
    String? selectedType = currentType;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Visitor Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Onsite'),
                value: 'onsite',
                groupValue: selectedType,
                onChanged: (value) => setDialogState(() => selectedType = value),
              ),
              RadioListTile<String>(
                title: const Text('Online'),
                value: 'online',
                groupValue: selectedType,
                onChanged: (value) => setDialogState(() => selectedType = value),
              ),
              RadioListTile<String>(
                title: const Text('Absent'),
                value: 'absent',
                groupValue: selectedType,
                onChanged: (value) => setDialogState(() => selectedType = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null && selectedType != currentType) {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedType != null && selectedType != currentType) {
      try {
        await VisitorService.updateVisitor(
          visitorId: visitorId,
          updates: {'attendance_type': selectedType},
        );
        await _loadVisitorsFromTable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor attendance updated'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating visitor: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildVisitorViewTile(Map<String, dynamic> record) {
    final member = record['member'] as Map<String, dynamic>?;
    final firstName = member?['first_name'] ?? 'Unknown';
    final lastName = member?['last_name'] ?? '';
    final visitorId = record['visitor_id']?.toString() ?? '';
    final attendanceType =
        record['attendance_type']?.toString() ?? 'onsite';
    final attendanceTypeLabel = attendanceType == 'onsite'
        ? 'Onsite'
        : attendanceType == 'online'
        ? 'Online'
        : 'Absent';
    final attendanceTypeIcon = attendanceType == 'onsite'
        ? Icons.church
        : attendanceType == 'online'
        ? Icons.video_call
        : Icons.cancel_outlined;
    final attendanceTypeColor = attendanceType == 'onsite'
        ? AppColors.success
        : attendanceType == 'online'
        ? AppColors.primary
        : AppColors.error;

    return _buildAttendanceListRow(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingXS),
      leading: _attendanceAvatar(attendanceType),
      title: '$firstName $lastName',
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildVisitorTag(),
              Icon(attendanceTypeIcon, size: 14, color: attendanceTypeColor),
              Text(
                attendanceTypeLabel,
                style: TextStyle(
                  color: attendanceTypeColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            'Logged: ${_formatDateTime(record['created_at'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: visitorId.isEmpty
              ? null
              : () => _editVisitorAttendance(visitorId, attendanceType),
          tooltip: 'Edit Attendance',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed:
              visitorId.isEmpty ? null : () => _removeVisitor(visitorId),
          tooltip: 'Remove Visitor',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMemberViewTile(Map<String, dynamic> record) {
    final member = record['member'] as Map<String, dynamic>?;
    final firstName = member?['first_name'] ?? 'Unknown';
    final lastName = member?['last_name'] ?? '';
    final attendanceId = record['id']?.toString() ?? '';
    final attendanceType =
        record['attendance_type']?.toString() ?? 'onsite';
    final attendanceTypeLabel = attendanceType == 'onsite'
        ? 'Onsite'
        : attendanceType == 'online'
        ? 'Online'
        : 'Absent';
    final attendanceTypeIcon = attendanceType == 'onsite'
        ? Icons.church
        : attendanceType == 'online'
        ? Icons.video_call
        : Icons.cancel_outlined;
    final attendanceTypeColor = attendanceType == 'onsite'
        ? AppColors.success
        : attendanceType == 'online'
        ? AppColors.primary
        : AppColors.error;
    final isNewComer = member?['is_new_comer'] == true;

    return _buildAttendanceListRow(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingXS),
      leading: _attendanceAvatar(attendanceType),
      title: '$firstName $lastName',
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(attendanceTypeIcon, size: 14, color: attendanceTypeColor),
              Text(
                attendanceTypeLabel,
                style: TextStyle(
                  color: attendanceTypeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isNewComer) ...[
                Icon(Icons.star, size: 14, color: AppColors.warning),
                Text(
                  'New Comer',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Recorded: ${_formatDateTime(record['created_at'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: attendanceId.isEmpty
              ? null
              : () => _editAttendance(attendanceId, attendanceType),
          tooltip: 'Edit Attendance',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: attendanceId.isEmpty
              ? null
              : () => _removeAttendance(attendanceId),
          tooltip: 'Remove Attendance',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, int value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }

  Widget _buildFilterChip({
    required String label,
    required String? value,
    required IconData icon,
  }) {
    final isSelected = _selectedAttendanceFilter == value;
    final count = _getAttendanceTypeCount(value);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedAttendanceFilter = selected ? value : null;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  int _getAttendanceTypeCount(String? attendanceType) {
    if (attendanceType == null) {
      return _attendanceRecords.length + _visitorsForSelectedService.length;
    }
    if (attendanceType == 'visitor') {
      return _visitorsForSelectedService.length;
    }
    if (attendanceType == 'child') {
      return _attendanceRecords.where(_attendanceRecordIsChild).length;
    }
    final memberCount = _attendanceRecords
        .where(
          (record) => record['attendance_type']?.toString() == attendanceType,
        )
        .length;
    final visitorCount = _visitorsForSelectedService.where((visitor) {
      final at = visitor['attendance_type']?.toString();
      if (attendanceType == 'absent') {
        return at != 'onsite' && at != 'online';
      }
      return at == attendanceType;
    }).length;
    return memberCount + visitorCount;
  }
}
