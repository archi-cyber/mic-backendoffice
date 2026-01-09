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

      setState(() {
        _attendanceRecords = attendance;
        // Load attendance types for existing records
        // Note: 'absent' records are stored as null since they're not selected in the dropdown
        _memberAttendanceTypes = {
          for (var record in attendance)
            record['member_id']?.toString() ??
                '': record['attendance_type']?.toString() == 'absent'
                ? null
                : (record['attendance_type']?.toString()),
        };
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

      // Process all members - those with attendance selected and those without (marked as absent)
      for (var member in _members) {
        final memberId = member['id']?.toString() ?? '';
        final attendanceType = _memberAttendanceTypes[memberId];

        if (attendanceType == 'onsite') {
          onsiteMembers.add(memberId);
        } else if (attendanceType == 'online') {
          onlineMembers.add(memberId);
        } else {
          // If null or not selected, mark as absent
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

  Widget _buildEditModeContent() {
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

    return ListView.builder(
      itemCount: _members.length,
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
    );
  }

  List<Map<String, dynamic>> get _filteredAttendanceRecords {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      return _attendanceRecords;
    }

    return _attendanceRecords.where((record) {
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

  Widget _buildViewModeContent() {
    final filteredRecords = _filteredAttendanceRecords;

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
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Card
        Container(
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
                '${_attendanceRecords.length}',
                Icons.people,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.textSecondary.withOpacity(0.3),
              ),
              _buildStatItem(
                'Active Members',
                '${_members.length}',
                Icons.group,
              ),
            ],
          ),
        ),
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
}
