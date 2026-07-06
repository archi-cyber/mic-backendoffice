import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/church_attendance_service.dart';
import '../../services/member_service.dart';
import '../../services/visitor_service.dart';
import '../../services/attendance_report_pdf_service.dart';
import '../../utils/member_utils.dart';
import '../../utils/whatsapp_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Page for marking church attendance (Wednesday and Sunday services)
class ChurchAttendancePage extends StatefulWidget {
  final String? serviceDate;
  final String? serviceType;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  ChurchAttendancePage({
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
  Map<String, String> _memberSpecificObservations =
      {}; // memberId -> optional note for this service
  Map<String, String?> _visitorAttendanceTypes =
      {}; // visitorId -> attendanceType (null = absent)
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isViewMode = false;
  final TextEditingController _searchController = TextEditingController();

  /// Attendance rows loaded when editing an existing service (keyed by member id).
  Map<String, Map<String, dynamic>> _editSessionRecords = {};

  /// Visitor ids tied to the service being edited (survives date/type changes).
  Set<String> _editSessionVisitorIds = {};

  /// null = all, 'onsite', 'online', 'absent', 'child' (members age 0–12)
  String? _selectedAttendanceFilter;

  /// Visitors logged for the selected service date (`visit_date`).
  List<Map<String, dynamic>> _visitors = [];

  bool _isCompactServiceDetails(BuildContext context) =>
      _isViewMode && MediaQuery.sizeOf(context).width < 700;

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
    await Future.wait([_loadVisitorsFromTable(), _loadExistingAttendance()]);
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
      member['phone'] ??= fromMembers['phone'];
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
    final targetDate = _formatDateOnly(_selectedDate);

    for (final entry in _visitorAttendanceTypes.entries) {
      final visitorId = entry.key;
      if (visitorId.isEmpty) continue;
      final effectiveType = entry.value ?? 'absent';
      await VisitorService.updateVisitor(
        visitorId: visitorId,
        updates: {
          'attendance_type': effectiveType,
          'visit_date': targetDate,
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
          'visit_date': targetDate,
          'service_type': _selectedServiceType,
        },
      );
      savedIds.add(visitorId);
    }

    for (final visitorId in _editSessionVisitorIds) {
      if (savedIds.contains(visitorId)) continue;
      final effectiveType = _visitorAttendanceTypes[visitorId] ?? 'absent';
      await VisitorService.updateVisitor(
        visitorId: visitorId,
        updates: {
          'attendance_type': effectiveType,
          'visit_date': targetDate,
          'service_type': _selectedServiceType,
        },
      );
    }
  }

  void _beginEditSession() {
    _editSessionRecords = {
      for (final record in _attendanceRecords)
        if (record['id'] != null && record['member_id'] != null)
          record['member_id'].toString(): Map<String, dynamic>.from(record),
    };
    _editSessionVisitorIds = _visitorsForSelectedService
        .map((visitor) => visitor['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  void _clearEditSession() {
    _editSessionRecords = {};
    _editSessionVisitorIds = {};
  }

  Future<void> _onServiceDateOrTypeChanged({
    DateTime? newDate,
    String? newServiceType,
  }) async {
    final preserveEditState = _editSessionRecords.isNotEmpty;

    setState(() {
      if (newDate != null) _selectedDate = newDate;
      if (newServiceType != null) _selectedServiceType = newServiceType;
      if (!preserveEditState) {
        _memberAttendanceTypes.clear();
        _visitorAttendanceTypes.clear();
        _memberSpecificObservations.clear();
      }
    });

    await _loadVisitorsFromTable();
    if (!preserveEditState) {
      await _loadExistingAttendance();
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
            content: Text(context.tr('Could not load visitors: $e')),
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
            content: Text(context.tr('Error loading members: $e')),
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
      final memberObservationsMap = <String, String>{};
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
          final observation = record['specific_observation']?.toString().trim();
          if (observation != null && observation.isNotEmpty) {
            memberObservationsMap[memberId] = observation;
          }
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
        _memberSpecificObservations = memberObservationsMap;
      });
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
    }
  }

  void _sortVisitors(List<Map<String, dynamic>> visitors) {
    visitors.sort((a, b) {
      final nameA = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'
          .toLowerCase();
      final nameB = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'
          .toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  bool _isVisitorDisplayRecord(Map<String, dynamic> record) {
    return record['is_visitor'] == true;
  }

  Map<String, dynamic> _visitorDisplayRecord(Map<String, dynamic> visitor) {
    final raw = visitor['attendance_type']?.toString();
    final attendanceType = raw == 'onsite' || raw == 'online' || raw == 'absent'
        ? raw!
        : 'absent';
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
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
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
    final visitorRecords = _filteredVisitors.map(_visitorDisplayRecord).where((
      record,
    ) {
      if (_selectedAttendanceFilter == null) return true;
      final at = record['attendance_type']?.toString();
      return at == _selectedAttendanceFilter;
    }).toList();

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
          title: Text(context.tr('Add Visitor')),
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
                  SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: firstNameController,
                    decoration: InputDecoration(
                      labelText: context.tr('First name *'),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: lastNameController,
                    decoration: InputDecoration(
                      labelText: context.tr('Last name *'),
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: context.tr('Phone (optional)'),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: context.tr('Notes (optional)'),
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
              onPressed: isSaving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
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
                            final withoutOptional =
                                Map<String, dynamic>.from(visitorData)
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
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('Add')),
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
          SnackBar(
            content: Text(context.tr('Visitor added')),
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
        title: Text(context.tr('Remove Visitor')),
        content: Text(
          context.tr('Remove this visitor from today\'s visit log?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.tr('Remove')),
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
          SnackBar(
            content: Text(context.tr('Visitor removed')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error removing visitor: $e')),
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
      lastDate: DateTime.now().add(Duration(days: 1)),
      helpText: 'Select Service Date',
    );
    if (picked != null) {
      await _onServiceDateOrTypeChanged(newDate: picked);
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      // Keep historical rows intact: update existing records in-place and only
      // insert missing ones for this service. Do not soft-delete/recreate rows.
      final existingRecordByMemberId = <String, Map<String, dynamic>>{};
      if (_editSessionRecords.isNotEmpty) {
        existingRecordByMemberId.addAll(_editSessionRecords);
      } else {
        for (final record in _attendanceRecords) {
          final memberId = record['member_id']?.toString();
          final attendanceId = record['id']?.toString();
          if (memberId != null && memberId.isNotEmpty && attendanceId != null) {
            existingRecordByMemberId[memberId] = record;
          }
        }
      }

      final movingExistingService = _editSessionRecords.isNotEmpty;

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
              'memberId': memberId,
            });
          } else {
            onsiteMembers.add(memberId);
          }
        } else if (attendanceType == 'online') {
          if (existingRecordByMemberId.containsKey(memberId)) {
            updates.add({
              'id': existingRecordByMemberId[memberId]!['id'].toString(),
              'type': 'online',
              'memberId': memberId,
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
              'memberId': memberId,
            });
          } else {
            absentMembers.add(memberId);
          }
        }
      }

      // Update existing attendance records
      for (final update in updates) {
        final memberId = update['memberId']!;
        await ChurchAttendanceService.updateAttendance(
          attendanceId: update['id']!,
          attendanceType: update['type']!,
          specificObservation: _memberSpecificObservations[memberId] ?? '',
          serviceDate: movingExistingService ? _selectedDate : null,
          serviceType: movingExistingService ? _selectedServiceType : null,
        );
      }

      // Insert attendance records only for members not already recorded
      if (onsiteMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: onsiteMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'onsite',
          specificObservationsByMemberId: _memberSpecificObservations,
        );
      }
      if (onlineMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: onlineMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'online',
          specificObservationsByMemberId: _memberSpecificObservations,
        );
      }
      if (absentMembers.isNotEmpty) {
        await ChurchAttendanceService.markBulkAttendance(
          memberIds: absentMembers,
          serviceDate: _selectedDate,
          serviceType: _selectedServiceType,
          attendanceType: 'absent',
          specificObservationsByMemberId: _memberSpecificObservations,
        );
      }

      await _saveVisitorsAttendance();

      _clearEditSession();

      // Reload to reflect server state in view mode
      await Future.wait([_loadVisitorsFromTable(), _loadExistingAttendance()]);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Attendance saved successfully')),
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
            content: Text(context.tr('Error saving attendance: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showMemberObservationDialog({
    required String memberId,
    required String memberName,
    String? attendanceId,
  }) async {
    final initial = _memberSpecificObservations[memberId] ?? '';
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    final result = isCompact
        ? await showModalBottomSheet<String?>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppDimensions.radiusLG),
              ),
            ),
            builder: (sheetContext) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: _MemberObservationEditor(
                memberName: memberName,
                initialText: initial,
                onCancel: () => Navigator.pop(sheetContext),
                onSave: (text) => Navigator.pop(sheetContext, text),
              ),
            ),
          )
        : await showDialog<String?>(
            context: context,
            builder: (dialogContext) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingLG,
                vertical: AppDimensions.spacingLG,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 440),
                child: _MemberObservationEditor(
                  memberName: memberName,
                  initialText: initial,
                  onCancel: () => Navigator.pop(dialogContext),
                  onSave: (text) => Navigator.pop(dialogContext, text),
                ),
              ),
            ),
          );

    if (result == null || !mounted) return;

    final trimmed = result.trim();

    if (_isViewMode && attendanceId != null && attendanceId.isNotEmpty) {
      try {
        await ChurchAttendanceService.updateAttendance(
          attendanceId: attendanceId,
          specificObservation: trimmed,
        );
        await _loadExistingAttendance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                trimmed.isEmpty ? 'Observation removed' : 'Observation saved',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error saving observation: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      return;
    }

    setState(() {
      if (trimmed.isEmpty) {
        _memberSpecificObservations.remove(memberId);
      } else {
        _memberSpecificObservations[memberId] = trimmed;
      }
    });
  }

  Widget _buildObservationAction({
    required String memberId,
    required String memberName,
    String? attendanceId,
  }) {
    final hasObservation =
        (_memberSpecificObservations[memberId]?.trim().isNotEmpty ?? false);

    return IconButton(
      icon: Icon(
        hasObservation ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
        color: hasObservation ? AppColors.primary : null,
      ),
      tooltip: context.tr('Specific observation'),
      visualDensity: VisualDensity.compact,
      onPressed:
          memberId.isEmpty ||
              (_isViewMode && (attendanceId == null || attendanceId.isEmpty))
          ? null
          : () => _showMemberObservationDialog(
              memberId: memberId,
              memberName: memberName,
              attendanceId: attendanceId,
            ),
    );
  }

  Future<void> _editAttendance(String attendanceId, String currentType) async {
    String? selectedType = currentType;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Edit Attendance Type')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(context.tr('Onsite')),
                subtitle: Text(context.tr('Attended in person')),
                value: 'onsite',
                groupValue: selectedType,
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: Text(context.tr('Online')),
                subtitle: Text(context.tr('Attended virtually')),
                value: 'online',
                groupValue: selectedType,
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              ),
              RadioListTile<String>(
                title: Text(context.tr('Absent')),
                subtitle: Text(context.tr('Was not present')),
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
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null && selectedType != currentType) {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pop(context, false);
                }
              },
              child: Text(context.tr('Save')),
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
            SnackBar(
              content: Text(context.tr('Attendance updated successfully')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error updating attendance: $e')),
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
        title: Text(context.tr('Remove Attendance')),
        content: Text(
          'Are you sure you want to remove this attendance record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.tr('Remove')),
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
            SnackBar(
              content: Text(context.tr('Attendance removed successfully')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error removing attendance: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );
    final useDesktopLayout =
        embedded ||
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    final bodyColumn = _buildBodyColumn(embedded: embedded);

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
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
                    tooltip: context.tr('Add Visitor'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      setState(() {
                        _isViewMode = false;
                        _beginEditSession();
                        for (var record in _attendanceRecords) {
                          final memberId = record['member_id']?.toString();
                          if (memberId != null) {
                            final attendanceType =
                                record['attendance_type']?.toString();
                            _memberAttendanceTypes[memberId] =
                                attendanceType == 'absent'
                                    ? null
                                    : attendanceType;
                            final observation = record['specific_observation']
                                ?.toString()
                                .trim();
                            if (observation != null && observation.isNotEmpty) {
                              _memberSpecificObservations[memberId] =
                                  observation;
                            }
                          }
                        }
                        _syncVisitorAttendanceTypes();
                      });
                      _loadVisitorsFromTable();
                    },
                    tooltip: context.tr('Edit Attendance'),
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    onPressed: _showAddVisitorDialog,
                    tooltip: context.tr('Add Visitor'),
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
                      tooltip: context.tr('Save Attendance'),
                    ),
                ],
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : embedded
          ? DesktopPageShell(
              maxWidth: kDesktopNarrowMaxWidth,
              isLoading: _isSaving,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height - 48,
                child: bodyColumn,
              ),
            )
          : useDesktopLayout
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: bodyColumn,
              ),
            )
          : bodyColumn,
    );
  }

  Widget _buildDesktopHeroBanner() {
    final serviceLabel = _selectedServiceType == 'sunday'
        ? context.tr('Sunday Service')
        : context.tr('Wednesday Service');
    final dateLabel = DateFormat('EEEE, MMM d, yyyy').format(_selectedDate);

    return DesktopHeroBanner(
      title: _isViewMode
          ? context.tr('Service Details')
          : context.tr('Mark Attendance'),
      subtitle: '$serviceLabel · $dateLabel',
      icon: Icons.church_outlined,
      trailing: widget.onClose != null
          ? IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              tooltip: context.tr('Close'),
            )
          : null,
    );
  }

  Widget _buildBodyColumn({required bool embedded}) {
    final compactView = _isCompactServiceDetails(context);

    return Column(
      children: [
        if (embedded)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimensions.paddingLG,
              AppDimensions.paddingLG,
              AppDimensions.paddingLG,
              0,
            ),
            child: _buildDesktopHeroBanner(),
          ),
        if (compactView)
          _buildCompactServiceHeader()
        else if (!embedded || !_isViewMode)
          _buildStandardServiceHeader(),
        Expanded(
          child: embedded
              ? Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLG),
                  child: DesktopSectionCard(
                    title: _isViewMode
                        ? context.tr('Attendance Records')
                        : context.tr('Members & Visitors'),
                    icon: Icons.people_outline,
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height - 380,
                        child: _isViewMode
                            ? _buildViewModeContent()
                            : _buildEditModeContent(),
                      ),
                    ],
                  ),
                )
              : (_isViewMode
                  ? _buildViewModeContent()
                  : _buildEditModeContent()),
        ),
      ],
    );
  }

  Widget _buildCompactServiceHeader() {
    final serviceLabel = _selectedServiceType == 'sunday'
        ? 'Sunday service'
        : 'Wednesday service';
    final dateLabel = DateFormat('EEEE, MMM d, yyyy').format(_selectedDate);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
        AppDimensions.spacingMD,
        AppDimensions.spacingMD,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 2),
          Text(
            dateLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.mic.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardServiceHeader() {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingMD),
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
                      labelText: context.tr('Service Date'),
                      prefixIcon: Icon(Icons.calendar_today),
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
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedServiceType,
                  decoration: InputDecoration(
                    labelText: context.tr('Service Type'),
                    prefixIcon: Icon(Icons.church),
                    isDense: true,
                    filled: _isViewMode,
                    fillColor: _isViewMode
                        ? Theme.of(context).disabledColor.withValues(alpha: 0.1)
                        : null,
                  ),
                  isExpanded: true,
                  items: [
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
                            await _onServiceDateOrTypeChanged(
                              newServiceType: value,
                            );
                          }
                        },
                ),
              ),
            ],
          ),
          if (!_isViewMode) ...[
            SizedBox(height: AppDimensions.spacingSM),
            Builder(
              builder: (context) {
                int attendedCount = 0;
                for (var member in _members) {
                  final memberId = member['id']?.toString() ?? '';
                  final attendanceType = _memberAttendanceTypes[memberId];
                  if (attendanceType != null) {
                    attendedCount++;
                  }
                }
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
                  ],
                );
              },
            ),
          ],
        ],
      ),
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

  Map<String, int> _viewSummaryStats() {
    final onsiteRecords = _attendanceRecords.where((record) {
      return record['attendance_type']?.toString() == 'onsite';
    }).toList();
    final onlineRecords = _attendanceRecords.where((record) {
      return record['attendance_type']?.toString() == 'online';
    }).toList();

    return {
      'children': onsiteRecords
          .where(_attendanceRecordIsChild)
          .map((r) => r['member_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .length,
      'newComerChildren': onsiteRecords
          .where(_attendanceRecordIsNewComerChild)
          .map((r) => r['member_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .length,
      'adults': onsiteRecords
          .where(
            (r) =>
                !_attendanceRecordIsChild(r) && !_attendanceRecordIsNewComer(r),
          )
          .map((r) => r['member_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .length,
      'newComers': onsiteRecords
          .where(_attendanceRecordIsNewComer)
          .map((r) => r['member_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .length,
      'visitors': _visitorsForSelectedService.where(_visitorAttended).length,
      'online': onlineRecords
          .map((r) => r['member_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .length,
      'totalOnsite': _uniqueOnsiteMemberCount(onsiteRecords),
    };
  }

  String _attendanceStatusLabel(String? type) {
    switch (type) {
      case 'onsite':
        return 'Onsite';
      case 'online':
        return 'Online';
      default:
        return 'Absent';
    }
  }

  Color _attendanceStatusColor(String? type) {
    switch (type) {
      case 'onsite':
        return AppColors.success;
      case 'online':
        return AppColors.primary;
      default:
        return context.mic.textTertiary;
    }
  }

  Widget _buildMobileSummaryMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMD,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          SizedBox(width: AppDimensions.spacingMD),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.mic.textPrimary),
            ),
          ),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummarySection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.spacingXS,
            bottom: AppDimensions.spacingSM,
          ),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.mic.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMobileSummaryHero(Map<String, int> stats) {
    final totalOnsite = stats['totalOnsite'] ?? 0;
    final online = stats['online'] ?? 0;
    final visitors = stats['visitors'] ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppDimensions.spacingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            '$totalOnsite',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1,
            ),
          ),
          SizedBox(height: AppDimensions.spacingXS),
          Text(
            'onsite attendees',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.mic.textSecondary),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Row(
            children: [
              Expanded(
                child: _buildMobileSummaryHeroChip(
                  icon: Icons.video_call_outlined,
                  label: 'Online',
                  value: online,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              Expanded(
                child: _buildMobileSummaryHeroChip(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Visitors',
                  value: visitors,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryHeroChip({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMD,
        vertical: AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: AppDimensions.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryTab(Map<String, int> stats) {
    Widget metricDivider() => Divider(
      height: 1,
      indent: 60,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacingMD,
        AppDimensions.spacingMD,
        AppDimensions.spacingMD,
        AppDimensions.spacingLG,
      ),
      children: [
        _buildMobileSummaryHero(stats),
        SizedBox(height: AppDimensions.spacingLG),
        _buildMobileSummarySection(
          title: 'Onsite breakdown',
          children: [
            _buildMobileSummaryMetric(
              icon: Icons.people_outline,
              iconColor: AppColors.primary,
              label: 'Adults',
              value: stats['adults'] ?? 0,
            ),
            metricDivider(),
            _buildMobileSummaryMetric(
              icon: Icons.child_care_outlined,
              iconColor: AppColors.accent,
              label: 'Children',
              value: stats['children'] ?? 0,
            ),
            metricDivider(),
            _buildMobileSummaryMetric(
              icon: Icons.star_outline,
              iconColor: AppColors.warning,
              label: 'New comers',
              value: stats['newComers'] ?? 0,
            ),
            metricDivider(),
            _buildMobileSummaryMetric(
              icon: Icons.family_restroom_outlined,
              iconColor: AppColors.warning,
              label: 'New comer children',
              value: stats['newComerChildren'] ?? 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileAttendeesEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_searchController.text.isNotEmpty ||
              _selectedAttendanceFilter != null) ...[
            SizedBox(height: AppDimensions.spacingXS),
            Text(
              'Try adjusting search or filters',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileAttendeesTab(List<Map<String, dynamic>> filteredItems) {
    return Column(
      children: [
        _buildMobileViewToolbar(),
        Expanded(
          child: filteredItems.isEmpty
              ? _buildMobileAttendeesEmptyState()
              : ListView.builder(
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

  Widget _buildCompactViewModeContent(
    List<Map<String, dynamic>> filteredItems,
  ) {
    final stats = _viewSummaryStats();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: context.mic.textSecondary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Theme.of(
                context,
              ).dividerColor.withValues(alpha: 0.5),
              tabs: [
                Tab(text: 'Attendees'),
                Tab(text: 'Summary'),
              ],
            ),
          ),
          if (_isViewMode) _buildMobileAbsentActions(),
          Expanded(
            child: TabBarView(
              children: [
                _buildMobileAttendeesTab(filteredItems),
                _buildMobileSummaryTab(stats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMobileAttendanceFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.spacingMD,
                  0,
                  AppDimensions.spacingMD,
                  AppDimensions.spacingSM,
                ),
                child: Text(
                  'Filter attendees',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildMobileFilterOption(sheetContext, null, 'All'),
              _buildMobileFilterOption(sheetContext, 'onsite', 'Onsite'),
              _buildMobileFilterOption(sheetContext, 'online', 'Online'),
              _buildMobileFilterOption(sheetContext, 'absent', 'Absent'),
              _buildMobileFilterOption(sheetContext, 'child', 'Children'),
              _buildMobileFilterOption(sheetContext, 'visitor', 'Visitors'),
              SizedBox(height: AppDimensions.spacingSM),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileFilterOption(
    BuildContext sheetContext,
    String? value,
    String label,
  ) {
    final isSelected = _selectedAttendanceFilter == value;
    final count = _getAttendanceTypeCount(value);

    return ListTile(
      title: Text(context.tr('$label ($count)')),
      trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _selectedAttendanceFilter = value);
        Navigator.pop(sheetContext);
      },
    );
  }

  Widget _buildMobileAbsentActions() {
    final absentCount = _absentPeopleEntries().length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showAbsentPeopleDialog,
              icon: const Icon(Icons.person_off_outlined, size: 18),
              label: Text('Absent ($absentCount)'),
            ),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          IconButton.filledTonal(
            onPressed: _generateAbsentPeoplePdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export absent PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileViewToolbar() {
    final hasActiveFilter = _selectedAttendanceFilter != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
        AppDimensions.spacingMD,
        AppDimensions.spacingSM,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('Search…'),
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18),
                        onPressed: _searchController.clear,
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          SizedBox(width: AppDimensions.spacingSM),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: hasActiveFilter ? 0.65 : 0.45),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showMobileAttendanceFilterSheet,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  hasActiveFilter ? Icons.filter_alt : Icons.filter_list,
                  size: 22,
                  color: hasActiveFilter
                      ? AppColors.primary
                      : context.mic.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileViewListTile({
    required String title,
    required String attendanceType,
    String? note,
    bool isVisitor = false,
    bool isNewComer = false,
    required List<PopupMenuEntry<String>> menuItems,
    required void Function(String action) onMenuAction,
  }) {
    final statusLabel = _attendanceStatusLabel(attendanceType);
    final statusColor = _attendanceStatusColor(attendanceType);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(AppDimensions.spacingMD, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        statusLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: statusColor),
                      ),
                      if (isVisitor)
                        Text(
                          'Visitor',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.mic.textSecondary),
                        ),
                      if (isNewComer)
                        Text(
                          'New comer',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      note,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (menuItems.isNotEmpty)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: context.mic.textSecondary,
                ),
                padding: EdgeInsets.zero,
                onSelected: onMenuAction,
                itemBuilder: (context) => menuItems,
              ),
          ],
        ),
      ),
    );
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
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No active members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppDimensions.spacingLG),
            FilledButton.icon(
              onPressed: _showAddVisitorDialog,
              icon: Icon(Icons.person_add_alt_1),
              label: Text(context.tr('Add Visitor')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.tr('Search members and visitors...'),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMD,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.spacingSM),
              IconButton.filled(
                onPressed: _showAddVisitorDialog,
                icon: Icon(Icons.person_add_alt_1),
                tooltip: context.tr('Add Visitor'),
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
                      SizedBox(height: AppDimensions.spacingMD),
                      Text(
                        'No results found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_searchController.text.isNotEmpty) ...[
                        SizedBox(height: AppDimensions.spacingXS),
                        Text(
                          'Try adjusting your search',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(bottom: AppDimensions.spacingMD),
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
      margin:
          margin ??
          EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingXS,
          ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingSM,
          vertical: AppDimensions.spacingXS,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            SizedBox(width: AppDimensions.spacingSM),
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
                  if (subtitle != null) ...[SizedBox(height: 2), subtitle],
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
      underline: SizedBox.shrink(),
      items: [
        DropdownMenuItem<String>(
          value: 'onsite',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.church, size: 16, color: AppColors.success),
              SizedBox(width: 8),
              Text(context.tr('Onsite')),
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
              Text(context.tr('Online')),
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
              Text(context.tr('Absent')),
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
    final currentAttendanceType =
        stored ?? (forThisService ? _visitorAttendanceFromDb(visitor) : null);
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
              _visitorAttendanceTypes[visitorId] = value == 'absent'
                  ? null
                  : value;
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
    final observation = _memberSpecificObservations[memberId]?.trim();
    final memberName = '$firstName $lastName';
    final hasSubtitle =
        isNewComer || (observation != null && observation.isNotEmpty);

    return _buildAttendanceListRow(
      leading: _attendanceAvatar(currentAttendanceType),
      title: memberName,
      subtitle: hasSubtitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNewComer)
                  Wrap(
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
                  ),
                if (observation != null && observation.isNotEmpty)
                  Text(
                    observation,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          : null,
      actions: [
        _buildObservationAction(memberId: memberId, memberName: memberName),
        _buildAttendanceTypeDropdown(
          value: menuValue,
          onChanged: (value) {
            setState(() {
              _memberAttendanceTypes[memberId] = value == 'absent'
                  ? null
                  : value;
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
            SizedBox(height: AppDimensions.spacingMD),
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
            SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No attendance recorded for this service',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: AppDimensions.spacingSM),
            Text(
              'Tap Edit to mark attendance or add visitors',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final compactView = _isCompactServiceDetails(context);

    if (compactView) {
      return _buildCompactViewModeContent(filteredItems);
    }

    final summaryCard = Builder(
      builder: (context) {
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
          margin: EdgeInsets.all(AppDimensions.spacingMD),
          padding: EdgeInsets.all(AppDimensions.spacingMD),
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
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'New comer children attended',
                newComerChildrenAttended,
                Icons.child_care,
              ),
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'Adults attended',
                adultsAttended,
                Icons.people,
              ),
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'New comers attended',
                newComersAttended,
                Icons.star,
              ),
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'Visitors attended',
                _visitorsForSelectedService.where(_visitorAttended).length,
                Icons.person_add_alt_1,
              ),
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'Online attendance',
                onlineAttended,
                Icons.video_call,
              ),
              SizedBox(height: AppDimensions.spacingXS),
              _buildSummaryLine(
                'Total (excluding online)',
                totalExcludingOnline,
                Icons.calculate,
              ),
            ],
          ),
        );
      },
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMD,
              vertical: AppDimensions.spacingSM,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.tr('Search members and visitors...'),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMD,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingSM),
                Row(
                  children: [
                    Text(
                      'Filter:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
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
                            SizedBox(width: AppDimensions.spacingXS),
                            _buildFilterChip(
                              label: 'Onsite',
                              value: 'onsite',
                              icon: Icons.church,
                            ),
                            SizedBox(width: AppDimensions.spacingXS),
                            _buildFilterChip(
                              label: 'Online',
                              value: 'online',
                              icon: Icons.video_call,
                            ),
                            SizedBox(width: AppDimensions.spacingXS),
                            _buildFilterChip(
                              label: 'Absent',
                              value: 'absent',
                              icon: Icons.cancel_outlined,
                            ),
                            SizedBox(width: AppDimensions.spacingXS),
                            _buildFilterChip(
                              label: 'Children',
                              value: 'child',
                              icon: Icons.child_care,
                            ),
                            SizedBox(width: AppDimensions.spacingXS),
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
                SizedBox(height: AppDimensions.spacingMD),
                Wrap(
                  spacing: AppDimensions.spacingSM,
                  runSpacing: AppDimensions.spacingSM,
                  children: [
                    FilledButton.icon(
                      onPressed: _showAbsentPeopleDialog,
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Absent people'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _generateAbsentPeoplePdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: summaryCard),
        if (filteredItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    'No results found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_searchController.text.isNotEmpty ||
                      _selectedAttendanceFilter != null) ...[
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      'Try adjusting search or filters',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingMD),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final record = filteredItems[index];
                if (_isVisitorDisplayRecord(record)) {
                  return _buildVisitorViewTile(record);
                }
                return _buildMemberViewTile(record);
              }, childCount: filteredItems.length),
            ),
          ),
      ],
    );
  }

  List<Map<String, String?>> _absentPeopleEntries() {
    final entries = <Map<String, String?>>[];

    void addEntry({
      required String kind,
      required String name,
      String? phone,
      String? email,
    }) {
      entries.add({
        'kind': kind,
        'name': name,
        'phone': phone,
        'email': email,
        'whatsappUrl': WhatsAppUtils.urlFromPhone(phone),
      });
    }

    if (_isViewMode) {
      for (final record in _attendanceRecords) {
        if (record['attendance_type']?.toString() != 'absent') continue;

        final memberId = record['member_id']?.toString() ?? '';
        final member = record['member'] as Map<String, dynamic>?;
        final fromMembers =
            memberId.isNotEmpty ? _membersById[memberId] : null;

        final first = (member?['first_name'] ?? fromMembers?['first_name'] ?? '')
            .toString()
            .trim();
        final last = (member?['last_name'] ?? fromMembers?['last_name'] ?? '')
            .toString()
            .trim();
        final name = '$first $last'.trim().isEmpty
            ? (memberId.isNotEmpty ? memberId : 'Unknown')
            : '$first $last'.trim();

        addEntry(
          kind: 'Member',
          name: name,
          phone: fromMembers?['phone']?.toString() ?? member?['phone']?.toString(),
          email: fromMembers?['email']?.toString() ?? member?['email']?.toString(),
        );
      }

      for (final visitor in _visitorsForSelectedService) {
        final at = visitor['attendance_type']?.toString();
        if (at == 'onsite' || at == 'online') continue;

        final first = visitor['first_name']?.toString().trim() ?? '';
        final last = visitor['last_name']?.toString().trim() ?? '';
        final name = '$first $last'.trim().isEmpty
            ? (visitor['id']?.toString() ?? 'Unknown')
            : '$first $last'.trim();

        addEntry(
          kind: 'Visitor',
          name: name,
          phone: visitor['phone']?.toString(),
          email: visitor['email']?.toString(),
        );
      }
    } else {
      for (final member in _members) {
        final id = member['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (_memberAttendanceTypes[id] != null) continue;

        final first = member['first_name']?.toString().trim() ?? '';
        final last = member['last_name']?.toString().trim() ?? '';
        final name = '$first $last'.trim().isEmpty ? id : '$first $last'.trim();

        addEntry(
          kind: 'Member',
          name: name,
          phone: member['phone']?.toString(),
          email: member['email']?.toString(),
        );
      }

      for (final visitor in _visitorsForSelectedService) {
        final id = visitor['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (_visitorAttendanceTypes[id] != null) continue;

        final first = visitor['first_name']?.toString().trim() ?? '';
        final last = visitor['last_name']?.toString().trim() ?? '';
        final name = '$first $last'.trim().isEmpty ? id : '$first $last'.trim();

        addEntry(
          kind: 'Visitor',
          name: name,
          phone: visitor['phone']?.toString(),
          email: visitor['email']?.toString(),
        );
      }
    }

    entries.sort((a, b) {
      final an = (a['name'] ?? '').toLowerCase();
      final bn = (b['name'] ?? '').toLowerCase();
      return an.compareTo(bn);
    });

    return entries;
  }

  Widget _buildAbsentPeopleList(List<Map<String, String?>> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No absent people',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.mic.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
      ),
      itemBuilder: (context, index) {
        final e = entries[index];
        final name = e['name'] ?? '-';
        final kind = e['kind'] ?? '';
        final phone = e['phone'] ?? '';
        final email = e['email'] ?? '';

        return ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingXS,
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.error.withValues(alpha: 0.12),
            child: const Icon(Icons.person_off_outlined, color: AppColors.error),
          ),
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kind.isNotEmpty)
                Text(
                  kind,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                ),
              if (phone.isNotEmpty) Text('Phone: $phone'),
              if (email.isNotEmpty) Text('Email: $email'),
            ],
          ),
          trailing: phone.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.chat, color: Colors.green),
                  tooltip: 'Open WhatsApp',
                  onPressed: () => _openWhatsApp(phone),
                )
              : null,
        );
      },
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    final opened = await WhatsAppUtils.openChat(phone: phone);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open WhatsApp. Make sure it is installed on this device.',
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _showAbsentPeopleDialog() async {
    final entries = _absentPeopleEntries();
    final isMobile = _isCompactServiceDetails(context);

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
          return SafeArea(
            child: SizedBox(
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.spacingMD,
                      0,
                      AppDimensions.spacingMD,
                      AppDimensions.spacingSM,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Absent people (${entries.length})',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _generateAbsentPeoplePdf();
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          tooltip: 'Export PDF',
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildAbsentPeopleList(entries)),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Absent people (${entries.length})'),
          content: SizedBox(
            width: 720,
            height: 480,
            child: _buildAbsentPeopleList(entries),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _generateAbsentPeoplePdf();
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateAbsentPeoplePdf() async {
    final l10n =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('en'));

    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final filePath =
          await AttendanceReportPdfService.generateChurchAttendanceAbsentPeopleReport(
        serviceDate: _selectedDate,
        serviceType: _selectedServiceType,
        localizations: l10n,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Absent PDF generated successfully: $filePath',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error generating absent PDF: $e',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
          title: Text(context.tr('Edit Visitor Attendance')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(context.tr('Onsite')),
                value: 'onsite',
                groupValue: selectedType,
                onChanged: (value) =>
                    setDialogState(() => selectedType = value),
              ),
              RadioListTile<String>(
                title: Text(context.tr('Online')),
                value: 'online',
                groupValue: selectedType,
                onChanged: (value) =>
                    setDialogState(() => selectedType = value),
              ),
              RadioListTile<String>(
                title: Text(context.tr('Absent')),
                value: 'absent',
                groupValue: selectedType,
                onChanged: (value) =>
                    setDialogState(() => selectedType = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null && selectedType != currentType) {
                  Navigator.pop(context, true);
                } else {
                  Navigator.pop(context, false);
                }
              },
              child: Text(context.tr('Save')),
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
            SnackBar(
              content: Text(context.tr('Visitor attendance updated')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error updating visitor: $e')),
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
    final attendanceType = record['attendance_type']?.toString() ?? 'onsite';

    if (_isCompactServiceDetails(context)) {
      final menuItems = <PopupMenuEntry<String>>[
        if (visitorId.isNotEmpty)
          PopupMenuItem(
            value: 'edit',
            child: Text(context.tr('Edit attendance')),
          ),
        if (visitorId.isNotEmpty)
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('Remove visitor')),
          ),
      ];

      return _buildMobileViewListTile(
        title: '$firstName $lastName',
        attendanceType: attendanceType,
        isVisitor: true,
        menuItems: menuItems,
        onMenuAction: (action) {
          switch (action) {
            case 'edit':
              _editVisitorAttendance(visitorId, attendanceType);
            case 'delete':
              _removeVisitor(visitorId);
          }
        },
      );
    }

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
      margin: EdgeInsets.only(bottom: AppDimensions.spacingXS),
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
          icon: Icon(Icons.edit),
          onPressed: visitorId.isEmpty
              ? null
              : () => _editVisitorAttendance(visitorId, attendanceType),
          tooltip: context.tr('Edit Attendance'),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: visitorId.isEmpty ? null : () => _removeVisitor(visitorId),
          tooltip: context.tr('Remove Visitor'),
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
    final attendanceType = record['attendance_type']?.toString() ?? 'onsite';
    final isNewComer = member?['is_new_comer'] == true;
    final memberId = record['member_id']?.toString() ?? '';
    final observation = record['specific_observation']?.toString().trim();
    final memberName = '$firstName $lastName';

    if (_isCompactServiceDetails(context)) {
      final menuItems = <PopupMenuEntry<String>>[
        if (attendanceId.isNotEmpty)
          PopupMenuItem(
            value: 'edit',
            child: Text(context.tr('Edit attendance')),
          ),
        if (attendanceId.isNotEmpty && memberId.isNotEmpty)
          PopupMenuItem(
            value: 'note',
            child: Text(context.tr('Specific observation')),
          ),
        if (attendanceId.isNotEmpty)
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('Remove attendance')),
          ),
      ];

      return _buildMobileViewListTile(
        title: memberName,
        attendanceType: attendanceType,
        note: observation,
        isNewComer: isNewComer,
        menuItems: menuItems,
        onMenuAction: (action) {
          switch (action) {
            case 'edit':
              _editAttendance(attendanceId, attendanceType);
            case 'note':
              _showMemberObservationDialog(
                memberId: memberId,
                memberName: memberName,
                attendanceId: attendanceId,
              );
            case 'delete':
              _removeAttendance(attendanceId);
          }
        },
      );
    }

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
      margin: EdgeInsets.only(bottom: AppDimensions.spacingXS),
      leading: _attendanceAvatar(attendanceType),
      title: memberName,
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
          if (observation != null && observation.isNotEmpty)
            Text(
              observation,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          Text(
            'Recorded: ${_formatDateTime(record['created_at'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        _buildObservationAction(
          memberId: memberId,
          memberName: memberName,
          attendanceId: attendanceId.isEmpty ? null : attendanceId,
        ),
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: attendanceId.isEmpty
              ? null
              : () => _editAttendance(attendanceId, attendanceType),
          tooltip: context.tr('Edit Attendance'),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: attendanceId.isEmpty
              ? null
              : () => _removeAttendance(attendanceId),
          tooltip: context.tr('Remove Attendance'),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, int value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        SizedBox(width: AppDimensions.spacingSM),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
          SizedBox(width: 4),
          Text(label),
          if (count > 0) ...[
            SizedBox(width: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  color: isSelected ? AppColors.primary : context.mic.textPrimary,
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
        color: isSelected ? AppColors.primary : context.mic.textPrimary,
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

class _MemberObservationEditor extends StatefulWidget {
  final String memberName;
  final String initialText;
  final VoidCallback onCancel;
  final void Function(String text) onSave;

  _MemberObservationEditor({
    required this.memberName,
    required this.initialText,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_MemberObservationEditor> createState() =>
      _MemberObservationEditorState();
}

class _MemberObservationEditorState extends State<_MemberObservationEditor> {
  late final TextEditingController _controller;
  static const _maxLength = 500;
  static const _suggestions = ['Traveling', 'Sick', 'Arrived late', 'Away'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;
  int get _remaining => _maxLength - _controller.text.length;

  String get _memberInitials {
    final parts = widget.memberName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  void _applySuggestion(String suggestion) {
    final current = _controller.text.trim();
    _controller.text = current.isEmpty ? suggestion : '$current — $suggestion';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.spacingMD,
            AppDimensions.spacingSM,
            AppDimensions.spacingMD,
            AppDimensions.spacingMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      _memberInitials,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.memberName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Service note',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mic.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onCancel,
                    tooltip: context.tr('Close'),
                  ),
                ],
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 4,
                maxLength: _maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: context.tr('Write a note for this service…'),
                  counterText: '$_remaining left',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.all(AppDimensions.spacingMD),
                ),
              ),
              SizedBox(height: AppDimensions.spacingSM),
              Text(
                'Quick add',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.mic.textTertiary,
                ),
              ),
              SizedBox(height: AppDimensions.spacingSM),
              Wrap(
                spacing: AppDimensions.spacingSM,
                runSpacing: AppDimensions.spacingSM,
                children: _suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    visualDensity: VisualDensity.compact,
                    labelStyle: theme.textTheme.bodySmall,
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.6),
                    ),
                    onPressed: () => _applySuggestion(suggestion),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surface,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppDimensions.spacingMD,
            AppDimensions.spacingSM,
            AppDimensions.spacingMD,
            AppDimensions.spacingMD + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => widget.onSave(_controller.text.trim()),
                child: Text(context.tr('Save note')),
              ),
              if (_hasText) ...[
                SizedBox(height: AppDimensions.spacingXS),
                TextButton(
                  onPressed: () => widget.onSave(''),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: Text(context.tr('Remove note')),
                ),
              ] else
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(context.tr('Cancel')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
