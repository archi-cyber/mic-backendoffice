import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/class_service.dart';
import '../../services/offline_queue_service.dart';
import '../../widgets/attendance_toggle.dart';

/// Attendance-taking UI with fast toggles and bulk select
class AttendancePage extends StatefulWidget {
  final String sessionId;

  /// When null (e.g. opened from desktop stack), members are loaded from session's class.
  final List<Map<String, dynamic>>? members;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const AttendancePage({
    super.key,
    required this.sessionId,
    this.members,
    this.onClose,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final Map<String, String> _attendanceStatus = {};
  final Set<String> _selectedMembers = {};
  bool _isSaving = false;
  bool _isSelectMode = false;
  List<Map<String, dynamic>>? _members;
  bool _isLoadingMembers = false;

  List<Map<String, dynamic>> get _effectiveMembers =>
      widget.members ?? _members ?? [];

  @override
  void initState() {
    super.initState();
    if (widget.members != null && widget.members!.isNotEmpty) {
      _members = widget.members;
      _loadExistingAttendance();
    } else {
      _loadMembersFromSession();
    }
  }

  Future<void> _loadMembersFromSession() async {
    setState(() => _isLoadingMembers = true);
    try {
      final session = await ClassService.getSessionById(widget.sessionId);
      final classId = session['class_id']?.toString();
      if (classId == null) throw Exception('Session has no class_id');
      final enrollments = await ClassService.getClassMembers(classId);
      final memberList = enrollments
          .map((e) => e['members'] as Map<String, dynamic>?)
          .where((m) => m != null)
          .cast<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _members = memberList;
        _isLoadingMembers = false;
      });
      _loadExistingAttendance();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
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
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
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
      for (final member in _effectiveMembers) {
        final memberId = member['id'].toString();
        _attendanceStatus[memberId] = 'present';
      }
    });
  }

  void _bulkMarkAbsent() {
    setState(() {
      for (final member in _effectiveMembers) {
        final memberId = member['id'].toString();
        _attendanceStatus[memberId] = 'absent';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 700;

    if (_isLoadingMembers) {
      return Scaffold(
        appBar: widget.onClose != null
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onClose,
                ),
                title: const Text('Take Attendance'),
              )
            : AppBar(title: const Text('Take Attendance')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onClose,
                    )
                  : null,
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
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
      bottomNavigationBar: isDesktop ? null : _buildSaveBar(context),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: back (desktop stack) + title + actions + save
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.onClose != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppDimensions.spacingSM,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onClose,
                        tooltip: 'Back',
                      ),
                    ),
                  Text(
                    'Take Attendance',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _bulkMarkPresent,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('All Present'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      OutlinedButton.icon(
                        onPressed: _bulkMarkAbsent,
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text('All Absent'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingMD),
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
                          tooltip: 'Mark selected present',
                        ),
                      IconButton(
                        icon: Icon(
                          _isSelectMode ? Icons.close : Icons.select_all,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSelectMode = !_isSelectMode;
                            if (!_isSelectMode) {
                              _selectedMembers.clear();
                            }
                          });
                        },
                        tooltip: _isSelectMode
                            ? 'Cancel selection'
                            : 'Select all',
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveAttendance,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Attendance',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.paddingLG,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Table of members and status
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: const [
                    DataColumn(label: Text('Member')),
                    DataColumn(label: Text('Present'), numeric: true),
                    DataColumn(label: Text('Late'), numeric: true),
                    DataColumn(label: Text('Absent'), numeric: true),
                  ],
                  rows: _effectiveMembers.map((member) {
                    final memberId = member['id'].toString();
                    final memberName =
                        '${member['first_name']} ${member['last_name']}';
                    final status = _attendanceStatus[memberId];
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              if (_isSelectMode)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppDimensions.spacingSM,
                                  ),
                                  child: Checkbox(
                                    value:
                                        status != 'absent' &&
                                        _selectedMembers.contains(memberId),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _attendanceStatus[memberId] =
                                              'present';
                                          _selectedMembers.add(memberId);
                                        } else {
                                          _attendanceStatus[memberId] =
                                              'absent';
                                          _selectedMembers.remove(memberId);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              Text(
                                memberName,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          _DesktopStatusChip(
                            label: 'P',
                            isSelected: status == 'present',
                            color: AppColors.success,
                            onTap: () =>
                                _handleStatusChanged(memberId, 'present'),
                          ),
                        ),
                        DataCell(
                          _DesktopStatusChip(
                            label: 'L',
                            isSelected: status == 'late',
                            color: AppColors.warning,
                            onTap: () => _handleStatusChanged(memberId, 'late'),
                          ),
                        ),
                        DataCell(
                          _DesktopStatusChip(
                            label: 'A',
                            isSelected: status == 'absent',
                            color: AppColors.error,
                            onTap: () =>
                                _handleStatusChanged(memberId, 'absent'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return Column(
      children: [
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
        Expanded(
          child: ListView.builder(
            itemCount: _effectiveMembers.length,
            itemBuilder: (context, index) {
              final member = _effectiveMembers[index];
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
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return Container(
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
    );
  }
}

/// Desktop-only status chip for DataTable cell
class _DesktopStatusChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _DesktopStatusChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textLight : color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
