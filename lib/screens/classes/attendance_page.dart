import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/class_service.dart';
import '../../services/offline_queue_service.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Attendance-taking UI with MIC styling, search, and quick bulk actions.
class AttendancePage extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>>? members;
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
  final TextEditingController _searchController = TextEditingController();
  bool _isSaving = false;
  bool _isSelectMode = false;
  bool _isLoadingMembers = false;
  bool _isLoadingSession = true;
  List<Map<String, dynamic>>? _members;
  Map<String, dynamic>? _session;
  Map<String, dynamic>? _training;

  List<Map<String, dynamic>> get _effectiveMembers =>
      widget.members ?? _members ?? [];

  List<Map<String, dynamic>> get _filteredMembers {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _effectiveMembers;
    return _effectiveMembers.where((member) {
      final firstName = (member['first_name'] ?? '').toString().toLowerCase();
      final lastName = (member['last_name'] ?? '').toString().toLowerCase();
      final email = (member['email'] ?? '').toString().toLowerCase();
      return firstName.contains(query) ||
          lastName.contains(query) ||
          '$firstName $lastName'.contains(query) ||
          email.contains(query);
    }).toList();
  }

  int get _presentCount => _attendanceStatus.values
      .where((status) => status == 'present')
      .length;

  int get _lateCount =>
      _attendanceStatus.values.where((status) => status == 'late').length;

  int get _absentCount => _attendanceStatus.values
      .where((status) => status == 'absent')
      .length;

  int get _unmarkedCount =>
      _effectiveMembers.length - _attendanceStatus.length;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
    if (widget.members != null && widget.members!.isNotEmpty) {
      _members = widget.members;
      _loadExistingAttendance();
    } else {
      _loadMembersFromSession();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionInfo() async {
    try {
      final session = await ClassService.getSessionById(widget.sessionId);
      final classId = session['class_id']?.toString();
      Map<String, dynamic>? training;
      if (classId != null) {
        training = await ClassService.getClassById(classId);
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _training = training;
        _isLoadingSession = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSession = false);
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
          .map((enrollment) => enrollment['members'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _members = memberList;
        _isLoadingMembers = false;
      });
      _loadExistingAttendance();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMembers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error loading members: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadExistingAttendance() async {
    try {
      final attendanceRecords = await ClassService.getSessionAttendance(
        widget.sessionId,
      );
      if (!mounted) return;
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
      final records = _attendanceStatus.entries
          .map((entry) => {'member_id': entry.key, 'status': entry.value})
          .toList();
      final isOnline = await OfflineQueueService.isOnline();

      if (isOnline) {
        await ClassService.recordAttendance(
          sessionId: widget.sessionId,
          attendanceRecords: records,
        );
      } else {
        await OfflineQueueService.queueOperation(
          type: 'attendance',
          data: {'session_id': widget.sessionId, 'records': records},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? context.tr('Attendance saved successfully')
                : context.tr('Attendance queued for sync'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error saving attendance: $e')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _bulkMarkPresent() {
    setState(() {
      for (final member in _effectiveMembers) {
        _attendanceStatus[member['id'].toString()] = 'present';
      }
    });
  }

  void _bulkMarkAbsent() {
    setState(() {
      for (final member in _effectiveMembers) {
        _attendanceStatus[member['id'].toString()] = 'absent';
      }
    });
  }

  String? _sessionDateLabel() {
    final raw = _session?['session_date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat.yMMMEd().format(DateTime.parse(raw));
    } catch (_) {
      return raw;
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

    if (_isLoadingMembers || _isLoadingSession) {
      return Scaffold(
        backgroundColor: context.mic.background,
        appBar: embedded ? null : _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final body = Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: embedded
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppDimensions.paddingLG,
                          AppDimensions.paddingLG,
                          AppDimensions.paddingLG,
                          0,
                        ),
                        child: _buildDesktopBanner(),
                      )
                    : _buildHeaderBanner(),
              ),
              SliverToBoxAdapter(child: SizedBox(height: AppDimensions.spacingMD)),
              SliverToBoxAdapter(child: _buildStatsRow(useDesktopLayout)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    embedded
                        ? AppDimensions.paddingLG
                        : AppDimensions.paddingMD,
                    AppDimensions.spacingMD,
                    embedded
                        ? AppDimensions.paddingLG
                        : AppDimensions.paddingMD,
                    AppDimensions.spacingSM,
                  ),
                  child: _buildActionRow(useDesktopLayout),
                ),
              ),
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: context.mic.background,
                surfaceTintColor: context.mic.background,
                elevation: innerBoxIsScrolled ? 1 : 0,
                scrolledUnderElevation: 1,
                toolbarHeight: 72,
                titleSpacing: embedded
                    ? AppDimensions.paddingLG
                    : AppDimensions.paddingMD,
                title: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.tr('Search members...'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.mic.surface,
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
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMD),
                      borderSide: BorderSide(color: context.mic.border),
                    ),
                  ),
                ),
              ),
            ],
            body: embedded
                ? Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingLG,
                    ),
                    child: DesktopSectionCard(
                      title: context.tr('Members'),
                      icon: Icons.people_outline,
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height - 420,
                          child: _buildMembersList(),
                        ),
                      ],
                    ),
                  )
                : _buildMembersList(),
          ),
        ),
        _buildSaveBar(context, useDesktopLayout),
      ],
    );

    return Scaffold(
      backgroundColor: context.mic.background,
      appBar: embedded ? null : _buildAppBar(context),
      body: embedded
          ? DesktopPageShell(
              maxWidth: kDesktopContentMaxWidth,
              isLoading: _isSaving,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height - 48,
                child: body,
              ),
            )
          : body,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    return AppBar(
      leading: widget.onClose != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            )
          : null,
      title: Text(context.tr('Mark Attendance')),
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
              if (!_isSelectMode) _selectedMembers.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDesktopBanner() {
    final trainingName =
        _training?['name']?.toString() ?? context.tr('Training');
    final sessionDate = _sessionDateLabel();

    return DesktopHeroBanner(
      title: context.tr('Mark Attendance'),
      subtitle: sessionDate != null
          ? '$trainingName · $sessionDate'
          : trainingName,
      icon: Icons.fact_check_outlined,
      trailing: widget.onClose != null
          ? IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
              tooltip: context.tr('Close'),
            )
          : null,
    );
  }

  Widget _buildHeaderBanner() {
    final trainingName =
        _training?['name']?.toString() ?? context.tr('Training');
    final sessionDate = _sessionDateLabel();

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        widget.onClose != null ? AppDimensions.spacingSM : 0,
        AppDimensions.paddingMD,
        0,
      ),
      padding: EdgeInsets.all(AppDimensions.paddingLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            context.mic.surfaceTint,
            context.mic.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
              tooltip: context.tr('Back'),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Mark Attendance'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingXS),
                Text(
                  trainingName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.mic.appBarForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sessionDate != null) ...[
                  SizedBox(height: AppDimensions.spacingXS),
                  Text(
                    sessionDate,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool useDesktopLayout) {
    if (useDesktopLayout) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingLG),
        child: Wrap(
          spacing: AppDimensions.spacingSM,
          runSpacing: AppDimensions.spacingSM,
          children: [
            DesktopStatChip(
              label: context.tr('Present'),
              value: '$_presentCount',
              icon: Icons.check_circle_outline,
              color: AppColors.success,
            ),
            DesktopStatChip(
              label: context.tr('Late'),
              value: '$_lateCount',
              icon: Icons.schedule_outlined,
              color: AppColors.warning,
            ),
            DesktopStatChip(
              label: context.tr('Absent'),
              value: '$_absentCount',
              icon: Icons.cancel_outlined,
              color: AppColors.error,
            ),
            DesktopStatChip(
              label: context.tr('Unmarked'),
              value: '$_unmarkedCount',
              icon: Icons.help_outline,
              color: context.mic.textSecondary,
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
        children: [
          _StatChip(
            label: context.tr('Present'),
            value: '$_presentCount',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _StatChip(
            label: context.tr('Late'),
            value: '$_lateCount',
            icon: Icons.schedule_outlined,
            color: AppColors.warning,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _StatChip(
            label: context.tr('Absent'),
            value: '$_absentCount',
            icon: Icons.cancel_outlined,
            color: AppColors.error,
          ),
          SizedBox(width: AppDimensions.spacingSM),
          _StatChip(
            label: context.tr('Unmarked'),
            value: '$_unmarkedCount',
            icon: Icons.help_outline,
            color: context.mic.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(bool useDesktopLayout) {
    return Wrap(
      spacing: AppDimensions.spacingSM,
      runSpacing: AppDimensions.spacingSM,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _bulkMarkPresent,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(context.tr('All Present')),
        ),
        OutlinedButton.icon(
          onPressed: _bulkMarkAbsent,
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: Text(context.tr('All Absent')),
        ),
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
            tooltip: context.tr('Mark selected present'),
          ),
        IconButton(
          icon: Icon(_isSelectMode ? Icons.close : Icons.select_all),
          onPressed: () {
            setState(() {
              _isSelectMode = !_isSelectMode;
              if (!_isSelectMode) _selectedMembers.clear();
            });
          },
          tooltip: _isSelectMode
              ? context.tr('Cancel')
              : context.tr('Select all'),
        ),
        if (useDesktopLayout)
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveAttendance,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              _isSaving
                  ? context.tr('Saving...')
                  : context.tr('Save Attendance'),
            ),
          ),
      ],
    );
  }

  Widget _buildMembersList() {
    final members = _filteredMembers;
    if (members.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 56,
                      color: context.mic.textSecondary,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Text(
                      _searchController.text.isNotEmpty
                          ? context.tr('No members found')
                          : context.tr('No members enrolled'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        AppDimensions.spacingMD,
        AppDimensions.paddingMD,
        AppDimensions.paddingXL,
      ),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final memberId = member['id'].toString();
        final memberName =
            '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();
        final status = _attendanceStatus[memberId];

        return _MemberAttendanceCard(
          memberName: memberName.isEmpty
              ? context.tr('Unknown')
              : memberName,
          status: status,
          isSelectMode: _isSelectMode,
          isSelected: status != 'absent' && _selectedMembers.contains(memberId),
          onSelectChanged: (selected) {
            setState(() {
              if (selected) {
                _attendanceStatus[memberId] = 'present';
                _selectedMembers.add(memberId);
              } else {
                _attendanceStatus[memberId] = 'absent';
                _selectedMembers.remove(memberId);
              }
            });
          },
          onStatusChanged: (newStatus) =>
              _handleStatusChanged(memberId, newStatus),
        );
      },
    );
  }

  Widget _buildSaveBar(BuildContext context, bool useDesktopLayout) {
    if (useDesktopLayout) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: context.mic.surface,
        border: Border(top: BorderSide(color: context.mic.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveAttendance,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textLight,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _isSaving
                ? context.tr('Saving...')
                : context.tr('Save Attendance'),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLG),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.mic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAttendanceCard extends StatelessWidget {
  const _MemberAttendanceCard({
    required this.memberName,
    required this.status,
    required this.isSelectMode,
    required this.isSelected,
    required this.onSelectChanged,
    required this.onStatusChanged,
  });

  final String memberName;
  final String? status;
  final bool isSelectMode;
  final bool isSelected;
  final ValueChanged<bool> onSelectChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppDimensions.spacingSM),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Row(
          children: [
            if (isSelectMode)
              Padding(
                padding: EdgeInsets.only(right: AppDimensions.spacingSM),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectChanged(value == true),
                ),
              ),
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: AppDimensions.spacingMD),
            Expanded(
              child: Text(
                memberName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.mic.appBarForeground,
                ),
              ),
            ),
            _StatusButton(
              label: 'P',
              isSelected: status == 'present',
              color: AppColors.success,
              onTap: () => onStatusChanged('present'),
            ),
            SizedBox(width: AppDimensions.spacingXS),
            _StatusButton(
              label: 'L',
              isSelected: status == 'late',
              color: AppColors.warning,
              onTap: () => onStatusChanged('late'),
            ),
            SizedBox(width: AppDimensions.spacingXS),
            _StatusButton(
              label: 'A',
              isSelected: status == 'absent',
              color: AppColors.error,
              onTap: () => onStatusChanged('absent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : context.mic.border,
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
