import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/class_service.dart';
import '../../services/offline_queue_service.dart';
import '../../widgets/attendance_toggle.dart';

/// Attendance-taking UI with fast toggles and bulk select
class AttendancePage extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> members;

  const AttendancePage({
    super.key,
    required this.sessionId,
    required this.members,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Map<String, String> _attendanceStatus = {};
  final Set<String> _selectedMembers = {};
  bool _isSaving = false;
  bool _isSelectMode = false;

  @override
  void initState() {
    super.initState();
    // Load existing attendance if any
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    try {
      final attendanceRecords = await ClassService.getSessionAttendance(
        widget.sessionId,
      );

      setState(() {
        for (final record in attendanceRecords) {
          final memberId = record['member_id']?.toString();
          final status = record['status']?.toString();
          if (memberId != null && status != null) {
            _attendanceStatus[memberId] = status;
          }
        }
      });
    } catch (e) {
      // If error, continue with empty attendance
      debugPrint('Error loading existing attendance: $e');
    }
  }

  void _handleStatusChanged(String memberId, String status) {
    setState(() {
      _attendanceStatus[memberId] = status;
      if (_isSelectMode) {
        if (status != 'absent') {
          _selectedMembers.add(memberId);
        } else {
          _selectedMembers.remove(memberId);
        }
      }
    });
  }

  Future<void> _saveAttendance() async {
    setState(() => _isSaving = true);

    try {
      // Prepare attendance records
      final records = _attendanceStatus.entries
          .map((entry) => {'member_id': entry.key, 'status': entry.value})
          .toList();

      // Check if online
      final isOnline = await OfflineQueueService.isOnline();

      if (isOnline) {
        // Save directly to backend
        await ClassService.recordAttendance(
          sessionId: widget.sessionId,
          attendanceRecords: records,
        );
      } else {
        // Queue for offline sync
        await OfflineQueueService.queueOperation(
          type: 'attendance',
          data: {'session_id': widget.sessionId, 'records': records},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Attendance saved successfully'
                  : 'Attendance queued for sync',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _bulkMarkPresent() {
    setState(() {
      for (final member in widget.members) {
        final memberId = member['id'].toString();
        _attendanceStatus[memberId] = 'present';
      }
    });
  }

  void _bulkMarkAbsent() {
    setState(() {
      for (final member in widget.members) {
        final memberId = member['id'].toString();
        _attendanceStatus[memberId] = 'absent';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Attendance'),
        actions: [
          if (_isSelectMode)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                setState(() {
                  for (final memberId in _selectedMembers) {
                    _attendanceStatus[memberId] = 'present';
                  }
                  _isSelectMode = false;
                  _selectedMembers.clear();
                });
              },
            ),
          IconButton(
            icon: Icon(_isSelectMode ? Icons.close : Icons.select_all),
            onPressed: () {
              setState(() {
                _isSelectMode = !_isSelectMode;
                if (!_isSelectMode) {
                  _selectedMembers.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bulk actions
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            color: AppColors.background,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: _bulkMarkPresent,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('All Present'),
                ),
                OutlinedButton.icon(
                  onPressed: _bulkMarkAbsent,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('All Absent'),
                ),
              ],
            ),
          ),
          // Members list with attendance toggles
          Expanded(
            child: ListView.builder(
              itemCount: widget.members.length,
              itemBuilder: (context, index) {
                final member = widget.members[index];
                final memberId = member['id'].toString();
                final memberName =
                    '${member['first_name']} ${member['last_name']}';

                return AttendanceToggle(
                  memberId: memberId,
                  memberName: memberName,
                  currentStatus: _attendanceStatus[memberId],
                  onStatusChanged: _handleStatusChanged,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAttendance,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                AppDimensions.buttonHeightLG,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Attendance'),
          ),
        ),
      ),
    );
  }
}
