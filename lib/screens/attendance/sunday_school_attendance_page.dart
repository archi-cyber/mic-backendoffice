import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/sunday_school_attendance_service.dart';
import '../../services/member_service.dart';
import '../../utils/member_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Page for marking Sunday school attendance (for children only)
class SundaySchoolAttendancePage extends StatefulWidget {
  final String? sessionDate;

  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  const SundaySchoolAttendancePage({
    super.key,
    this.sessionDate,
    this.onClose,
  });

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
    if (widget.sessionDate != null) {
      _selectedDate = DateTime.parse(widget.sessionDate!);
      _isViewMode = true;
    } else {
      _selectedDate = DateTime.now();
      _isViewMode = false;
    }
    _loadMembers();
    _loadExistingAttendance();
  }

  double get _attendanceProgress {
    if (_members.isEmpty) return 0;
    return _attendedMemberIds.length / _members.length;
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final allMembers = await MemberService.getMembers(
        filters: {'is_active': true},
        orderBy: 'first_name',
        ascending: true,
      );

      final childrenMembers = allMembers.where((member) {
        final birthday = member['birthday'];
        if (birthday == null) return false;

        DateTime? birthdayDate;
        try {
          if (birthday is String) {
            birthdayDate = DateTime.parse(birthday);
          } else if (birthday is DateTime) {
            birthdayDate = birthday;
          }
        } catch (e) {
          return false;
        }

        return MemberUtils.getAgeCategory(birthdayDate) == 'child';
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
            content: Text(context.tr('Error loading members: $e')),
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
      helpText: context.tr('Select Session Date'),
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
        SnackBar(
          content: Text(context.tr('Please select at least one child')),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final hasExistingAttendance = _attendanceRecords.isNotEmpty;

      if (hasExistingAttendance) {
        await SundaySchoolAttendanceService.updateSessionAttendance(
          attendanceDate: _selectedDate,
          memberIds: _attendedMemberIds.toList(),
        );
      } else {
        await SundaySchoolAttendanceService.markBulkAttendance(
          memberIds: _attendedMemberIds.toList(),
          attendanceDate: _selectedDate,
        );
      }

      await _loadExistingAttendance();

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isViewMode = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasExistingAttendance
                  ? context.tr('Attendance updated successfully')
                  : context.tr('Attendance saved successfully'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (!hasExistingAttendance) {
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop(true);
          }
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

  Future<void> _deleteSession() async {
    if (_attendanceRecords.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete Session')),
        content: Text(
          'Are you sure you want to delete this session for ${DateFormat('MMM d, yyyy').format(_selectedDate)}? This will remove all attendance records for this date and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SundaySchoolAttendanceService.deleteSession(_selectedDate);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Session deleted successfully')),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Error deleting session: $e')),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _memberInitials(String firstName, String lastName) {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final initials = '$f$l';
    return initials.isEmpty ? '?' : initials;
  }

  Widget _buildDesktopHeroBanner() {
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    return DesktopHeroBanner(
      title: _isViewMode
          ? context.tr('Session Details')
          : context.tr('Mark Attendance'),
      subtitle: dateLabel,
      icon: _isViewMode ? Icons.visibility_outlined : Icons.child_care_outlined,
      accent: AppColors.secondary,
      trailing: widget.onClose != null
          ? IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              tooltip: context.tr('Close'),
            )
          : null,
    );
  }

  Widget _buildHeroBanner() {
    final dateLabel = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
    final modeLabel = _isViewMode
        ? context.tr('View Mode')
        : context.tr('Edit Mode');

    return Container(
      margin: EdgeInsets.all(AppDimensions.paddingMD),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.22),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isViewMode ? Icons.visibility_outlined : Icons.edit_note,
                  color: AppColors.secondaryDark,
                  size: 26,
                ),
              ),
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isViewMode
                          ? context.tr('Session Details')
                          : context.tr('Mark Attendance'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.mic.appBarForeground,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_isViewMode ? AppColors.info : AppColors.accent)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  modeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _isViewMode ? AppColors.info : AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          if (!_isViewMode && widget.sessionDate == null) ...[
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('Session Date'),
                  prefixIcon: const Icon(Icons.calendar_today),
                  filled: true,
                  fillColor: context.mic.surface.withValues(alpha: 0.85),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: BorderSide(color: context.mic.border),
                  ),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              ),
            ),
            SizedBox(height: AppDimensions.spacingMD),
          ],
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _attendanceProgress,
                    minHeight: 8,
                    backgroundColor: context.mic.border,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              SizedBox(width: AppDimensions.spacingMD),
              Text(
                '${_attendedMemberIds.length}/${_members.length}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryDark,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingXS),
          Text(
            context.tr('{count} of {total} children marked', {
              'count': _attendedMemberIds.length,
              'total': _members.length,
            }),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildTile({
    required String memberId,
    required String firstName,
    required String lastName,
    int? age,
    required bool isAttended,
    String? recordedAt,
    bool interactive = true,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: isAttended
            ? AppColors.secondary.withValues(alpha: 0.08)
            : context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: isAttended
              ? AppColors.secondary.withValues(alpha: 0.35)
              : context.mic.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive
              ? () => _toggleMemberAttendance(memberId)
              : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMD,
              vertical: AppDimensions.paddingSM + 2,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isAttended
                      ? AppColors.secondary.withValues(alpha: 0.2)
                      : context.mic.surfaceTint.withValues(alpha: 0.5),
                  child: Text(
                    _memberInitials(firstName, lastName),
                    style: TextStyle(
                      color: isAttended
                          ? AppColors.secondaryDark
                          : context.mic.appBarForeground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: AppDimensions.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName'.trim(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.mic.appBarForeground,
                        ),
                      ),
                      if (age != null)
                        Text(
                          context.tr('Age: {age}', {'age': age}),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.mic.textSecondary),
                        ),
                      if (recordedAt != null)
                        Text(
                          recordedAt,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.mic.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (interactive)
                  Icon(
                    isAttended
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isAttended
                        ? AppColors.success
                        : context.mic.textSecondary,
                  )
                else
                  Icon(Icons.check_circle, color: AppColors.success, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditModeContent() {
    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.mic.surfaceTint.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.child_care_outlined,
                  size: 56,
                  color: AppColors.secondaryDark,
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Text(
                context.tr('No active children found'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.mic.appBarForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingXL),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final memberId = member['id']?.toString() ?? '';
        final firstName = member['first_name']?.toString() ?? '';
        final lastName = member['last_name']?.toString() ?? '';
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
          } catch (_) {}
        }

        return _buildChildTile(
          memberId: memberId,
          firstName: firstName,
          lastName: lastName,
          age: age,
          isAttended: _attendedMemberIds.contains(memberId),
        );
      },
    );
  }

  Widget _buildViewModeContent() {
    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.mic.surfaceTint.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_busy,
                  size: 56,
                  color: AppColors.secondaryDark,
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Text(
                context.tr('No attendance recorded for this session'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.mic.appBarForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingXL),
      itemCount: _attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        final member = record['member'] as Map<String, dynamic>?;
        final firstName = member?['first_name']?.toString() ?? 'Unknown';
        final lastName = member?['last_name']?.toString() ?? '';
        final recordedAt =
            '${context.tr('Recorded')}: ${_formatDateTime(record['created_at'])}';

        return _buildChildTile(
          memberId: record['member_id']?.toString() ?? '',
          firstName: firstName,
          lastName: lastName,
          isAttended: true,
          recordedAt: recordedAt,
          interactive: false,
        );
      },
    );
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
      backgroundColor: context.mic.background,
      appBar: embedded
          ? null
          : AppBar(
              leading: widget.onClose != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onClose,
                    )
                  : null,
              title: Text(
                _isViewMode
                    ? context.tr('Session Details')
                    : context.tr('Mark Attendance'),
              ),
              actions: [
                if (_isViewMode) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed:
                        _attendanceRecords.isEmpty ? null : _deleteSession,
                    tooltip: context.tr('Delete Session'),
                    color: AppColors.error,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => setState(() => _isViewMode = false),
                    tooltip: context.tr('Edit Session'),
                  ),
                ] else ...[
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    TextButton(
                      onPressed: () {
                        _loadExistingAttendance();
                        setState(() => _isViewMode = true);
                      },
                      child: Text(context.tr('Cancel')),
                    ),
                    FilledButton.icon(
                      onPressed: _saveAttendance,
                      icon: const Icon(Icons.save, size: 18),
                      label: Text(context.tr('Save')),
                    ),
                    SizedBox(width: AppDimensions.spacingSM),
                  ],
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
      floatingActionButton: !embedded &&
              !useDesktopLayout &&
              !_isViewMode &&
              !_isSaving &&
              _members.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _saveAttendance,
              icon: const Icon(Icons.save),
              label: Text(context.tr('Save Attendance')),
            )
          : null,
    );
  }

  Widget _buildBodyColumn({required bool embedded}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        embedded
            ? Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.paddingLG,
                  AppDimensions.paddingLG,
                  AppDimensions.paddingLG,
                  0,
                ),
                child: _buildDesktopHeroBanner(),
              )
            : _buildHeroBanner(),
        Expanded(
          child: embedded
              ? Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLG),
                  child: DesktopSectionCard(
                    title: _isViewMode
                        ? context.tr('Attendees')
                        : context.tr('Children'),
                    icon: Icons.child_care_outlined,
                    accent: AppColors.secondary,
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height - 340,
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

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return context.tr('Unknown');
    try {
      final dt = DateTime.parse(dateTime.toString());
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }
}
