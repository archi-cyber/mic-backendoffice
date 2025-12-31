import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/sunday_school_attendance_service.dart';
import '../../services/member_service.dart';
import '../../utils/member_utils.dart';

/// Page for marking Sunday school attendance (for children only)
class SundaySchoolAttendancePage extends StatefulWidget {
  final String? sessionDate;

  const SundaySchoolAttendancePage({super.key, this.sessionDate});

  @override
  State<SundaySchoolAttendancePage> createState() =>
      _SundaySchoolAttendancePageState();
}

class _SundaySchoolAttendancePageState
    extends State<SundaySchoolAttendancePage> {
  late DateTime _selectedDate;
  List<Map<String, dynamic>> _members = [];
  Set<String> _attendedMemberIds = {};
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isViewMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize from arguments if provided
    if (widget.sessionDate != null) {
      _selectedDate = DateTime.parse(widget.sessionDate!);
      _isViewMode = true;
    } else {
      _selectedDate = DateTime.now();
    }
    _loadMembers();
    _loadExistingAttendance();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final allMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'first_name',
        ascending: true,
      );

      // Filter to only show children
      final childrenMembers = allMembers.where((member) {
        final birthday = member['birthday'];
        if (birthday == null) return false; // Exclude if no birthday

        DateTime? birthdayDate;
        try {
          if (birthday is String) {
            birthdayDate = DateTime.parse(birthday);
          } else if (birthday is DateTime) {
            birthdayDate = birthday;
          }
        } catch (e) {
          return false; // Exclude if can't parse birthday
        }

        final ageCategory = MemberUtils.getAgeCategory(birthdayDate);
        // Only include children
        return ageCategory == 'child';
      }).toList();

      setState(() {
        _members = childrenMembers;
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
      final attendance = await SundaySchoolAttendanceService.getDateAttendance(
        attendanceDate: _selectedDate,
      );

      setState(() {
        _attendanceRecords = attendance;
        _attendedMemberIds = attendance
            .map((record) => record['member_id']?.toString())
            .whereType<String>()
            .toSet();
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
      helpText: 'Select Session Date',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _attendedMemberIds.clear();
      });
      _loadExistingAttendance();
    }
  }

  void _toggleMemberAttendance(String memberId) {
    setState(() {
      if (_attendedMemberIds.contains(memberId)) {
        _attendedMemberIds.remove(memberId);
      } else {
        _attendedMemberIds.add(memberId);
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (_attendedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one child'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await SundaySchoolAttendanceService.markBulkAttendance(
        memberIds: _attendedMemberIds.toList(),
        attendanceDate: _selectedDate,
      );

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
        await SundaySchoolAttendanceService.removeAttendance(attendanceId);
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
        title: Text(_isViewMode ? 'Session Details' : 'Mark Attendance'),
        actions: [
          if (!_isViewMode) ...[
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
                // Date Selector
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacingMD),
                  color: Theme.of(context).cardColor,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _isViewMode ? null : _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Session Date',
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
                      const SizedBox(height: AppDimensions.spacingSM),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_attendedMemberIds.length} of ${_members.length} children marked',
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
              Icons.child_care_outlined,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppDimensions.spacingMD),
            Text(
              'No active children found',
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
        final isAttended = _attendedMemberIds.contains(memberId);
        final firstName = member['first_name'] ?? '';
        final lastName = member['last_name'] ?? '';
        final birthday = member['birthday'];
        int? age;
        if (birthday != null) {
          try {
            DateTime? birthdayDate;
            if (birthday is String) {
              birthdayDate = DateTime.parse(birthday);
            } else if (birthday is DateTime) {
              birthdayDate = birthday;
            }
            age = MemberUtils.getAge(birthdayDate);
          } catch (e) {
            // Ignore
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMD,
            vertical: AppDimensions.spacingXS,
          ),
          child: CheckboxListTile(
            title: Text('$firstName $lastName'),
            subtitle: age != null ? Text('Age: $age') : null,
            value: isAttended,
            onChanged: (value) => _toggleMemberAttendance(memberId),
            secondary: isAttended
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : const Icon(Icons.radio_button_unchecked),
          ),
        );
      },
    );
  }

  Widget _buildViewModeContent() {
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
              'No attendance recorded for this session',
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
            color: AppColors.accent.withOpacity(0.1),
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
                'Active Children',
                '${_members.length}',
                Icons.child_care,
              ),
            ],
          ),
        ),
        // Attendance List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMD,
            ),
            itemCount: _attendanceRecords.length,
            itemBuilder: (context, index) {
              final record = _attendanceRecords[index];
              final member = record['member'] as Map<String, dynamic>?;
              final firstName = member?['first_name'] ?? 'Unknown';
              final lastName = member?['last_name'] ?? '';
              final attendanceId = record['id']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingXS),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: Text(
                      '${firstName[0]}${lastName.isNotEmpty ? lastName[0] : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text('$firstName $lastName'),
                  subtitle: Text(
                    'Recorded: ${_formatDateTime(record['created_at'])}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => _removeAttendance(attendanceId),
                    tooltip: 'Remove Attendance',
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
        Icon(icon, color: AppColors.accent),
        const SizedBox(height: AppDimensions.spacingXS),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
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
