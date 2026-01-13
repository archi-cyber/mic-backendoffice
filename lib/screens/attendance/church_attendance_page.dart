import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/church_attendance_service.dart';
import '../../services/member_service.dart';
import '../../utils/member_utils.dart';

/// Page for marking church attendance (Wednesday and Sunday services)
class ChurchAttendancePage extends StatefulWidget {
  final String? serviceDate;
  final String? serviceType;

  const ChurchAttendancePage({super.key, this.serviceDate, this.serviceType});

  @override
  State<ChurchAttendancePage> createState() => _ChurchAttendancePageState();
}

class _ChurchAttendancePageState extends State<ChurchAttendancePage> {
  late DateTime _selectedDate;
  late String _selectedServiceType;
  List<Map<String, dynamic>> _members = [];
  Map<String, String?> _memberAttendanceTypes =
      {}; // memberId -> attendanceType (null = not attended)
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isViewMode = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAttendanceFilter; // null = all, 'onsite', 'online', 'absent'

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
    _loadMembers();
    _loadExistingAttendance();
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

      // Filter out children - only show adults and teenagers
      final filteredMembers = allMembers.where((member) {
        final birthday = member['birthday'];
        if (birthday == null) {
          return true; // Include if no birthday (assume adult)
        }

        DateTime? birthdayDate;
        try {
          if (birthday is String) {
            birthdayDate = DateTime.parse(birthday);
          } else if (birthday is DateTime) {
            birthdayDate = birthday;
          }
        } catch (e) {
          return true; // Include if can't parse birthday
        }

        final ageCategory = MemberUtils.getAgeCategory(birthdayDate);
        // Only include adults and teenagers, exclude children
        return ageCategory != 'child';
      }).toList();

      setState(() {
        _members = filteredMembers;
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

      for (var member in _members) {
        final memberId = member['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        if (attendanceMap.containsKey(memberId)) {
          // Member has an attendance record
          final record = attendanceMap[memberId]!;
          allAttendanceRecords.add(record);
          final attendanceType = record['attendance_type']?.toString();
          // Store attendance type (null for absent in edit mode)
          memberAttendanceTypesMap[memberId] =
              attendanceType == 'absent' ? null : attendanceType;
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
            },
            'created_at': null,
          };
          allAttendanceRecords.add(absentRecord);
          memberAttendanceTypesMap[memberId] = null; // null means absent in edit mode
        }
      }

      setState(() {
        _attendanceRecords = allAttendanceRecords;
        _memberAttendanceTypes = memberAttendanceTypesMap;
      });
    } catch (e) {
      debugPrint('Error loading existing attendance: $e');
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
      });
      _loadExistingAttendance();
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      // If editing existing attendance, remove old records first
      // Only remove records that have database IDs (were previously saved)
      if (_attendanceRecords.isNotEmpty) {
        for (var record in _attendanceRecords) {
          final attendanceId = record['id']?.toString();
          if (attendanceId != null) {
            try {
              await ChurchAttendanceService.removeAttendance(attendanceId);
            } catch (e) {
              debugPrint('Error removing old attendance: $e');
            }
          }
        }
      }

      // Group members by attendance type
      // Members with null or no selection are automatically marked as absent
      final onsiteMembers = <String>[];
      final onlineMembers = <String>[];
      final absentMembers = <String>[];

      // Process ALL active members - ensure every member is accounted for
      for (var member in _members) {
        final memberId = member['id']?.toString() ?? '';
        if (memberId.isEmpty) continue;

        final attendanceType = _memberAttendanceTypes[memberId];

        if (attendanceType == 'onsite') {
          onsiteMembers.add(memberId);
        } else if (attendanceType == 'online') {
          onlineMembers.add(memberId);
        } else {
          // If null or not selected, mark as absent
          // This ensures every member is marked (either present or absent)
          absentMembers.add(memberId);
        }
      }

      // Mark attendance for each group
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isViewMode ? 'Service Details' : 'Mark Attendance'),
        actions: [
          if (_isViewMode) ...[
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
                });
              },
              tooltip: 'Edit Attendance',
            ),
          ] else ...[
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
          : Column(
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
                                        ).disabledColor.withOpacity(0.1)
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
                                      ).disabledColor.withOpacity(0.1)
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
                                return ['sunday', 'wednesday'].map((
                                  String value,
                                ) {
                                  return Text(
                                    value == 'sunday' ? 'Sunday' : 'Wednesday',
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }).toList();
                              },
                              onChanged: _isViewMode
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedServiceType = value;
                                          _memberAttendanceTypes.clear();
                                        });
                                        _loadExistingAttendance();
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
                            final attendanceType =
                                _memberAttendanceTypes[memberId];
                            if (attendanceType != null) {
                              attendedCount++;
                            }
                          }
                          // Absent count is total members minus those who attended
                          final absentCount = _members.length - attendedCount;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$attendedCount attended, $absentCount absent',
                                style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildEditModeContent() {
    final filteredMembers = _filteredMembers;

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

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingSM,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search members...',
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
        ),
        // Members List
        Expanded(
          child: filteredMembers.isEmpty
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
                        'No members found',
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
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
        final member = _members[index];
        final memberId = member['id']?.toString() ?? '';
        final firstName = member['first_name'] ?? '';
        final lastName = member['last_name'] ?? '';
        final isNewComer = member['is_new_comer'] == true;
        final currentAttendanceType = _memberAttendanceTypes[memberId];

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingXS,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: currentAttendanceType == null
                  ? AppColors.error
                  : currentAttendanceType == 'onsite'
                  ? AppColors.success
                  : AppColors.primary,
              child: Icon(
                currentAttendanceType == null
                    ? Icons.cancel_outlined
                    : currentAttendanceType == 'onsite'
                    ? Icons.church
                    : Icons.video_call,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text('$firstName $lastName'),
            subtitle: isNewComer
                ? Row(
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
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
            trailing: DropdownButton<String?>(
              value: currentAttendanceType,
              isDense: true,
              underline: const SizedBox.shrink(),
              hint: const Text('Absent'),
              items: [
                const DropdownMenuItem<String>(
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
                const DropdownMenuItem<String>(
                  value: 'online',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.video_call,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text('Online'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _memberAttendanceTypes[memberId] = value;
                });
              },
            ),
          ),
        );
                  },
                ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredAttendanceRecords {
    var filtered = _attendanceRecords;

    // Filter by attendance type
    if (_selectedAttendanceFilter != null) {
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
    final filteredRecords = _filteredAttendanceRecords;

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

    // If no attendance records yet, show message but still allow viewing
    if (_attendanceRecords.isEmpty) {
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
              'Tap Edit to mark attendance for all members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Card
        Builder(
          builder: (context) {
            // Count only actual attendance (onsite or online), exclude absent
            final attendedRecords = _attendanceRecords
                .where((record) {
                  final attendanceType = record['attendance_type']?.toString();
                  return attendanceType != null && attendanceType != 'absent';
                })
                .toList();
            
            // Count unique members who attended (onsite or online)
            final uniqueAttendedMembers = attendedRecords
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            // Count absent records
            final absentRecords = _attendanceRecords
                .where((record) {
                  final attendanceType = record['attendance_type']?.toString();
                  return attendanceType == 'absent';
                })
                .toList();
            
            // Count unique members who were absent
            final uniqueAbsentMembers = absentRecords
                .map((record) => record['member_id']?.toString())
                .where((id) => id != null)
                .toSet()
                .length;

            return Container(
              margin: const EdgeInsets.all(AppDimensions.spacingMD),
              padding: const EdgeInsets.all(AppDimensions.spacingMD),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Attended',
                    '$uniqueAttendedMembers',
                    Icons.people,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  _buildStatItem(
                    'Total Absence',
                    '$uniqueAbsentMembers',
                    Icons.cancel_outlined,
                  ),
                ],
              ),
            );
          },
        ),
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
                  hintText: 'Search members...',
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Attendance List
        Expanded(
          child: filteredRecords.isEmpty
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
                        'No members found',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMD,
                  ),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record = filteredRecords[index];
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

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingXS,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: attendanceTypeColor,
                          child: Icon(
                            attendanceTypeIcon,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text('$firstName $lastName'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  attendanceTypeIcon,
                                  size: 14,
                                  color: attendanceTypeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  attendanceTypeLabel,
                                  style: TextStyle(
                                    color: attendanceTypeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Recorded: ${_formatDateTime(record['created_at'])}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _editAttendance(attendanceId, attendanceType),
                              tooltip: 'Edit Attendance',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () => _removeAttendance(attendanceId),
                              tooltip: 'Remove Attendance',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: AppDimensions.spacingXS),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
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
                    : AppColors.primary.withOpacity(0.2),
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
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  int _getAttendanceTypeCount(String? attendanceType) {
    if (attendanceType == null) {
      return _attendanceRecords.length;
    }
    return _attendanceRecords
        .where((record) => record['attendance_type']?.toString() == attendanceType)
        .length;
  }
}
