import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import '../../services/report_service.dart';
import '../../services/role_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../utils/member_utils.dart';
import '../../widgets/desktop/desktop_ui.dart';
import 'member_form_ui.dart';

/// Member profile with attendance summary, classes, and departments
class MemberProfilePage extends StatefulWidget {
  final String memberId;

  /// When set (e.g. desktop stack overlay), back/close and pop results use this instead of Navigator.pop.
  final void Function(bool? result)? onClose;

  /// When set (e.g. desktop), edit opens in stack overlay; parent shows edit overlay with this memberId.
  final void Function(String memberId)? onEditRequested;

  MemberProfilePage({
    super.key,
    required this.memberId,
    this.onClose,
    this.onEditRequested,
  });

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  Map<String, dynamic>? _member;
  bool _isLoading = true;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    setState(() => _isLoading = true);
    try {
      final member = await MemberService.getMemberById(widget.memberId);

      // Check if current user can delete (admin or leader)
      final isAdmin = await RoleService.isCurrentUserAdmin();
      final userRole = await RoleService.getUserRole();
      final isLeader = userRole == 'leader';
      final canDelete = isAdmin || isLeader;

      setState(() {
        _member = member;
        _canDelete = canDelete;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading member: $e'))),
        );
      }
    }
  }

  Future<void> _deleteMember() async {
    final localizations = AppLocalizations.of(context);
    final memberName = '${_member!['first_name']} ${_member!['last_name']}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.deleteMember ?? 'Delete Member'),
        content: Text(
          (localizations?.deleteMemberConfirmation.replaceAll(
                '{name}',
                memberName,
              )) ??
              'Are you sure you want to delete $memberName? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await MemberService.deleteMember(widget.memberId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.memberDeletedSuccessfully ??
                    'Member deleted successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          if (widget.onClose != null) {
            widget.onClose!(true);
          } else {
            Navigator.of(context).pop(true); // Return true to indicate deletion
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ErrorMessageHelper.getErrorMessage(context, e)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        widget.onClose != null &&
        MediaQuery.sizeOf(context).width >= kDesktopEmbeddedBreakpoint;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_member == null) {
      return Scaffold(
        backgroundColor: context.mic.background,
        appBar: isDesktop
            ? null
            : AppBar(
                title: Text(context.tr('Member Profile')),
                leading: widget.onClose != null
                    ? IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => widget.onClose!(null),
                      )
                    : null,
              ),
        body: Center(child: Text(context.tr('Member not found'))),
      );
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.mic.background,
        body: _buildDesktopBody(context),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.mic.background,
        appBar: AppBar(
          leading: widget.onClose != null
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => widget.onClose!(null),
                )
              : null,
          title: Text('${_member!['first_name']} ${_member!['last_name']}'),
          actions: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () async {
                if (widget.onEditRequested != null) {
                  widget.onEditRequested!(widget.memberId);
                  return;
                }
                final result =
                    await Navigator.of(
                      context,
                      rootNavigator: widget.onClose != null,
                    ).pushNamed(
                      RouteNames.editMember.replaceAll(':id', widget.memberId),
                    );
                if (result == true) {
                  _loadMemberData();
                }
              },
              tooltip: context.tr('Edit Member'),
            ),
            if (_canDelete)
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.error),
                        SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)?.deleteMember ??
                              'Delete Member',
                        ),
                      ],
                    ),
                    onTap: () {
                      // Delay to allow popup to close first
                      Future.delayed(
                        Duration(milliseconds: 100),
                        () => _deleteMember(),
                      );
                    },
                  ),
                ],
              ),
          ],
          bottom: MemberFormUi.coloredTabBar(
            context: context,
            tabs: [
              Tab(text: context.tr('Profile')),
              Tab(text: context.tr('Attendance')),
              Tab(text: context.tr('Classes')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(member: _member!),
            _AttendanceTab(memberId: widget.memberId),
            _ClassesTab(memberId: widget.memberId),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final member = _member!;
    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = member['email']?.toString();
    final role = member['role']?.toString() ?? 'member';

    return DefaultTabController(
      length: 3,
      child: DesktopPageShell(
        maxWidth: kDesktopContentMaxWidth,
        banner: DesktopHeroBanner(
          title: fullName.isEmpty ? context.tr('Unnamed Member') : fullName,
          subtitle: email,
          icon: MemberFormUi.roleIcon(role),
          accent: MemberFormUi.roleColor(role),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined),
                onPressed: () async {
                  if (widget.onEditRequested != null) {
                    widget.onEditRequested!(widget.memberId);
                    return;
                  }
                  final result = await Navigator.of(
                    context,
                    rootNavigator: true,
                  ).pushNamed(
                    RouteNames.editMember.replaceAll(':id', widget.memberId),
                  );
                  if (result == true) _loadMemberData();
                },
                tooltip: context.tr('Edit Member'),
              ),
              if (_canDelete)
                PopupMenuButton(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)?.deleteMember ??
                                'Delete Member',
                          ),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(
                          Duration(milliseconds: 100),
                          () => _deleteMember(),
                        );
                      },
                    ),
                  ],
                ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => widget.onClose!(null),
                tooltip: context.tr('Close'),
              ),
            ],
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            side: BorderSide(
              color: context.mic.border.withValues(alpha: 0.75),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              MemberFormUi.coloredTabBar(
                context: context,
                tabs: [
                  Tab(text: context.tr('Profile')),
                  Tab(text: context.tr('Attendance')),
                  Tab(text: context.tr('Classes')),
                ],
              ),
              SizedBox(
                height: 560,
                child: TabBarView(
                  children: [
                    _ProfileTab(member: member, isDesktop: true),
                    _AttendanceTab(memberId: widget.memberId, isDesktop: true),
                    _ClassesTab(memberId: widget.memberId, isDesktop: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Profile tab
class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isDesktop;

  const _ProfileTab({required this.member, this.isDesktop = false});

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.only(bottom: AppDimensions.spacingMD),
        child: DesktopSectionCard(
          title: title,
          icon: icon,
          accent: accent,
          children: children,
        ),
      );
    }
    return MemberFormUi.sectionCard(
      context: context,
      title: title,
      icon: icon,
      accent: accent,
      children: children,
    );
  }

  List<Widget> _detailSections(BuildContext context) {
    final sections = <Widget>[
      _sectionCard(
        context,
        title: context.tr('Contact'),
        icon: Icons.contact_phone_outlined,
        accent: AppColors.primary,
        children: [
          MemberFormUi.infoRow(
            context: context,
            label: context.tr('Phone'),
            value: member['phone']?.toString() ?? context.tr('N/A'),
            icon: Icons.phone_outlined,
          ),
          MemberFormUi.infoRow(
            context: context,
            label: context.tr('Address'),
            value: member['address']?.toString() ?? context.tr('N/A'),
            icon: Icons.location_on_outlined,
          ),
        ],
      ),
      _sectionCard(
        context,
        title: context.tr('Personal details'),
        icon: Icons.badge_outlined,
        accent: AppColors.accent,
        children: [
          MemberFormUi.infoRow(
            context: context,
            label: context.tr('Birthday'),
            value: member['birthday'] != null
                ? DateFormat('MMMM d, yyyy')
                    .format(DateTime.parse(member['birthday']))
                : context.tr('N/A'),
            icon: Icons.cake_outlined,
            iconColor: AppColors.accent,
          ),
          MemberFormUi.infoRow(
            context: context,
            label: context.tr('Age Category'),
            value: member['birthday'] != null
                ? MemberUtils.getAgeCategoryLabel(
                    DateTime.parse(member['birthday']),
                  )
                : context.tr('N/A'),
            icon: Icons.person_outline,
            iconColor: AppColors.accent,
          ),
          if (member['quarter'] != null &&
              member['quarter'].toString().isNotEmpty)
            MemberFormUi.infoRow(
              context: context,
              label: context.tr('Quarter'),
              value: member['quarter'].toString(),
              icon: Icons.calendar_view_month,
              iconColor: AppColors.accent,
            ),
        ],
      ),
    ];

    final professional = <Widget>[];
    if (member['profession'] != null &&
        member['profession'].toString().isNotEmpty) {
      professional.add(
        MemberFormUi.infoRow(
          context: context,
          label: context.tr('Profession'),
          value: MemberConstants.getProfessionLabel(member['profession']),
          icon: Icons.work_outline,
          iconColor: AppColors.info,
        ),
      );
    }
    if (member['level_of_study'] != null &&
        member['level_of_study'].toString().isNotEmpty) {
      professional.add(
        MemberFormUi.infoRow(
          context: context,
          label: context.tr('Level of Study'),
          value: member['level_of_study'].toString(),
          icon: Icons.school_outlined,
          iconColor: AppColors.info,
        ),
      );
    }
    if (member['sector_of_studies'] != null &&
        member['sector_of_studies'].toString().isNotEmpty) {
      professional.add(
        MemberFormUi.infoRow(
          context: context,
          label: context.tr('Sector of Studies'),
          value: member['sector_of_studies'].toString(),
          icon: Icons.category_outlined,
          iconColor: AppColors.info,
        ),
      );
    }
    if (member['domain_of_activity'] != null &&
        member['domain_of_activity'].toString().isNotEmpty) {
      professional.add(
        MemberFormUi.infoRow(
          context: context,
          label: context.tr('Domain of Activity'),
          value: member['domain_of_activity'].toString(),
          icon: Icons.business_outlined,
          iconColor: AppColors.info,
        ),
      );
    }
    if (member['last_diplomas'] != null &&
        member['last_diplomas'].toString().isNotEmpty) {
      professional.add(
        MemberFormUi.infoRow(
          context: context,
          label: context.tr('Last Diplomas'),
          value: member['last_diplomas'].toString(),
          icon: Icons.workspace_premium_outlined,
          iconColor: AppColors.info,
        ),
      );
    }
    if (professional.isNotEmpty) {
      sections.add(
        _sectionCard(
          context,
          title: context.tr('Professional details'),
          icon: Icons.work_outline,
          accent: AppColors.info,
          children: professional,
        ),
      );
    }

    final skills = _getKeySkillsList(member['key_skills']);
    if (skills.isNotEmpty) {
      sections.add(
        _sectionCard(
          context,
          title: context.tr('Key Skills'),
          icon: Icons.star_outline,
          accent: AppColors.secondary,
          children: [
            Wrap(
              spacing: AppDimensions.spacingSM,
              runSpacing: AppDimensions.spacingSM,
              children: skills
                  .map(
                    (skill) => Chip(
                      label: Text(skill),
                      backgroundColor:
                          AppColors.secondary.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = member['first_name']?.toString() ?? '';
    final lastName = member['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final photoUrl = member['photo_url']?.toString();
    final initials = [
      if (firstName.isNotEmpty) firstName[0],
      if (lastName.isNotEmpty) lastName[0],
    ].join().toUpperCase();

    if (isDesktop) {
      return ListView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          MemberFormUi.profileHero(
            context: context,
            fullName:
                fullName.isEmpty ? context.tr('Unnamed Member') : fullName,
            email: member['email']?.toString(),
            role: member['role']?.toString() ?? 'member',
            isActive: member['is_active'] == true,
            photoUrl: photoUrl,
            initials: initials.isEmpty ? 'M' : initials,
          ),
          SizedBox(height: AppDimensions.spacingMD),
          ..._detailSections(context),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingXL),
      children: [
        MemberFormUi.profileHero(
          context: context,
          fullName: fullName.isEmpty ? context.tr('Unnamed Member') : fullName,
          email: member['email']?.toString(),
          role: member['role']?.toString() ?? 'member',
          isActive: member['is_active'] == true,
          photoUrl: photoUrl,
          initials: initials.isEmpty ? 'M' : initials,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
          child: Column(children: _detailSections(context)),
        ),
      ],
    );
  }

  List<String> _getKeySkillsList(dynamic keySkills) {
    if (keySkills == null) return [];
    if (keySkills is List) {
      return keySkills
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (keySkills is String) {
      return keySkills
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }
}

/// Church attendance report for the Presence / Attendance tab.
class _AttendanceTab extends StatefulWidget {
  final String memberId;
  final bool isDesktop;

  const _AttendanceTab({required this.memberId, this.isDesktop = false});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now();
  bool _isLoading = true;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await ReportService.getMemberChurchAttendanceReport(
        memberId: widget.memberId,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Error loading report: $e'))),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      helpText: context.tr('Select Date Range'),
    );
    if (dates == null) return;
    setState(() {
      _fromDate = dates.start;
      _toDate = dates.end;
    });
    _loadReport();
  }

  String _formatDate(String dateString) {
    try {
      return DateFormat.yMMMd().format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_report == null) {
      return Center(child: Text(context.tr('No attendance data')));
    }

    final attendance = _report!['attendance'] as Map<String, dynamic>;
    final records = List<Map<String, dynamic>>.from(
      attendance['records'] as List? ?? [],
    );
    final totalPresent = attendance['total'] as int? ?? 0;
    final onsite = attendance['onsite'] as int? ?? 0;
    final online = attendance['online'] as int? ?? 0;
    final absent = attendance['absent'] as int? ?? 0;

    final statChips = [
      widget.isDesktop
          ? DesktopStatChip(
              label: context.tr('Total Attendance'),
              value: '$totalPresent',
              icon: Icons.how_to_reg_outlined,
              color: AppColors.primary,
            )
          : _AttendanceStatChip(
              label: context.tr('Total Attendance'),
              value: '$totalPresent',
              icon: Icons.how_to_reg_outlined,
              color: AppColors.primary,
            ),
      widget.isDesktop
          ? DesktopStatChip(
              label: context.tr('Onsite'),
              value: '$onsite',
              icon: Icons.church_outlined,
              color: AppColors.success,
            )
          : _AttendanceStatChip(
              label: context.tr('Onsite'),
              value: '$onsite',
              icon: Icons.church_outlined,
              color: AppColors.success,
            ),
      widget.isDesktop
          ? DesktopStatChip(
              label: context.tr('Online'),
              value: '$online',
              icon: Icons.wifi_tethering_outlined,
              color: AppColors.accent,
            )
          : _AttendanceStatChip(
              label: context.tr('Online'),
              value: '$online',
              icon: Icons.wifi_tethering_outlined,
              color: AppColors.accent,
            ),
      widget.isDesktop
          ? DesktopStatChip(
              label: context.tr('Absent'),
              value: '$absent',
              icon: Icons.event_busy_outlined,
              color: AppColors.error,
            )
          : _AttendanceStatChip(
              label: context.tr('Absent'),
              value: '$absent',
              icon: Icons.event_busy_outlined,
              color: AppColors.error,
            ),
    ];

    final recordsContent = records.isEmpty
        ? Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: context.mic.textSecondary,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(context.tr('No attendance records')),
                ],
              ),
            ),
          )
        : Column(
            children: records
                .map((record) => _churchRecordTile(context, record))
                .toList(),
          );

    if (widget.isDesktop) {
      return ListView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          DesktopSectionCard(
            title: context.tr('churchAttendance'),
            icon: Icons.how_to_reg_outlined,
            accent: AppColors.primary,
            trailing: TextButton.icon(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(context.tr('Select Date Range')),
            ),
            children: [
              Wrap(
                spacing: AppDimensions.spacingSM,
                runSpacing: AppDimensions.spacingSM,
                children: statChips,
              ),
              SizedBox(height: AppDimensions.spacingMD),
              recordsContent,
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingXL),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.paddingMD,
            AppDimensions.spacingMD,
            AppDimensions.paddingMD,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('churchAttendance'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.mic.appBarForeground,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(context.tr('Select Date Range')),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMD),
            children: [
              for (var i = 0; i < statChips.length; i++) ...[
                if (i > 0) SizedBox(width: AppDimensions.spacingSM),
                statChips[i],
              ],
            ],
          ),
        ),
        if (records.isEmpty)
          Padding(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: context.mic.textSecondary,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(context.tr('No attendance records')),
                ],
              ),
            ),
          )
        else
          ...records.map((record) => _churchRecordTile(context, record)),
      ],
    );
  }

  Widget _churchRecordTile(BuildContext context, Map<String, dynamic> record) {
    final displayType = record['display_type']?.toString() ?? '';
    final displayDate = record['display_date']?.toString() ?? '';
    final attendanceType = record['attendance_type']?.toString();
    final typeLabel = record['attendance_type_display']?.toString() ?? '';

    IconData icon;
    Color color;
    if (attendanceType == 'onsite') {
      icon = Icons.church_outlined;
      color = AppColors.success;
    } else if (attendanceType == 'online') {
      icon = Icons.wifi_tethering_outlined;
      color = AppColors.accent;
    } else {
      icon = Icons.cancel_outlined;
      color = AppColors.error;
    }

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppDimensions.paddingMD,
        0,
        AppDimensions.paddingMD,
        AppDimensions.spacingSM,
      ),
      decoration: BoxDecoration(
        color: context.mic.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: context.mic.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          displayType,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          typeLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          _formatDate(displayDate),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _AttendanceStatChip extends StatelessWidget {
  const _AttendanceStatChip({
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
    return SizedBox(
      width: 118,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingSM + 4,
          vertical: AppDimensions.paddingSM,
        ),
        decoration: BoxDecoration(
          color: context.mic.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.mic.textSecondary,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Classes tab
class _ClassesTab extends StatefulWidget {
  final String memberId;
  final bool isDesktop;

  const _ClassesTab({required this.memberId, this.isDesktop = false});

  @override
  State<_ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<_ClassesTab> {
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemberClasses();
  }

  /// Charge les formations auxquelles le membre est inscrit.
  ///
  /// Le bilan du membre porte déjà cette liste : une seule requête suffit là
  /// où l'ancienne version interrogeait la table de liaison avec une jointure
  /// imbriquée.
  Future<void> _loadMemberClasses() async {
    try {
      final report = await ReportService.getMemberReport(
        memberId: widget.memberId,
      );

      final trainings = (report['trainings'] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _classes = trainings
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      final emptyContent = Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.class_outlined, size: 56, color: AppColors.secondary),
              SizedBox(height: AppDimensions.spacingMD),
              Text(context.tr('No classes enrolled')),
            ],
          ),
        ),
      );

      if (widget.isDesktop) {
        return ListView(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          children: [
            DesktopSectionCard(
              title: context.tr('Classes'),
              icon: Icons.class_outlined,
              accent: AppColors.secondary,
              children: [SizedBox(height: 120, child: emptyContent)],
            ),
          ],
        );
      }

      return emptyContent;
    }

    final classTiles = _classes.map((classItem) {
      final classId = classItem['id']?.toString() ?? '';
      final route = RouteNames.classDetail.replaceAll(':id', classId);
      return Container(
        margin: EdgeInsets.only(bottom: AppDimensions.spacingSM),
        decoration: BoxDecoration(
          color: context.mic.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: context.mic.border),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
            child: Icon(Icons.class_, color: AppColors.secondaryDark),
          ),
          title: Text(
            classItem['name']?.toString() ?? context.tr('Class'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(classItem['description']?.toString() ?? ''),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed(route),
        ),
      );
    }).toList();

    if (widget.isDesktop) {
      return ListView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          DesktopSectionCard(
            title: context.tr('Classes'),
            icon: Icons.class_outlined,
            accent: AppColors.secondary,
            children: classTiles,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      itemCount: _classes.length,
      itemBuilder: (context, index) => classTiles[index],
    );
  }
}