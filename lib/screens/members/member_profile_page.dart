import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/member_constants.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import '../../services/report_service.dart';
import '../../services/supabase_service.dart';
import '../../services/role_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../utils/member_utils.dart';

/// Member profile with attendance summary, classes, and departments
class MemberProfilePage extends StatefulWidget {
  final String memberId;

  const MemberProfilePage({super.key, required this.memberId});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _report;
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
      final report = await ReportService.getMemberReport(
        memberId: widget.memberId,
        fromDate: DateTime.now().subtract(const Duration(days: 90)),
        toDate: DateTime.now(),
      );
      
      // Check if current user can delete (admin or leader)
      final isAdmin = await RoleService.isCurrentUserAdmin();
      final userRole = await RoleService.getUserRole();
      final isLeader = userRole == 'leader';
      final canDelete = isAdmin || isLeader;
      
      setState(() {
        _member = member;
        _report = report;
        _canDelete = canDelete;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading member: $e')));
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
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
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ErrorMessageHelper.getErrorMessage(context, e),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Member Profile')),
        body: const Center(child: Text('Member not found')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_member!['first_name']} ${_member!['last_name']}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).pushNamed(
                  RouteNames.editMember.replaceAll(':id', widget.memberId),
                );
                if (result == true) {
                  // Reload member data if edit was successful
                  _loadMemberData();
                }
              },
              tooltip: 'Edit Member',
            ),
            if (_canDelete)
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)?.deleteMember ??
                              'Delete Member',
                        ),
                      ],
                    ),
                    onTap: () {
                      // Delay to allow popup to close first
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => _deleteMember(),
                      );
                    },
                  ),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Attendance'),
              Tab(text: 'Classes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(member: _member!),
            _AttendanceTab(report: _report),
            _ClassesTab(memberId: widget.memberId),
          ],
        ),
      ),
    );
  }
}

/// Profile tab
class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> member;

  const _ProfileTab({required this.member});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        // Profile card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(
                        member['first_name']?[0] ?? 'M',
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${member['first_name']} ${member['last_name']}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppDimensions.spacingXS),
                          Text(
                            member['email'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppDimensions.spacingXS),
                          _buildRoleChip(member['role'] ?? 'member'),
                        ],
                      ),
                    ),
                    Icon(
                      member['is_active'] == true
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: member['is_active'] == true
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ],
                ),
                const Divider(height: AppDimensions.spacingXL),
                _InfoRow(
                  label: 'Phone',
                  value: member['phone'] ?? 'N/A',
                  icon: Icons.phone,
                ),
                _InfoRow(
                  label: 'Birthday',
                  value: member['birthday'] != null
                      ? DateFormat(
                          'MMMM d, yyyy',
                        ).format(DateTime.parse(member['birthday']))
                      : 'N/A',
                  icon: Icons.cake,
                ),
                _InfoRow(
                  label: 'Address',
                  value: member['address'] ?? 'N/A',
                  icon: Icons.location_on,
                ),
                _InfoRow(
                  label: 'Role',
                  value: _getRoleLabel(member['role'] ?? 'member'),
                  icon: Icons.person_outline,
                ),
                _InfoRow(
                  label: 'Age Category',
                  value: member['birthday'] != null
                      ? MemberUtils.getAgeCategoryLabel(
                          DateTime.parse(member['birthday']),
                        )
                      : 'N/A',
                  icon: Icons.person,
                ),
                if (member['quarter'] != null &&
                    member['quarter'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Quarter',
                    value: member['quarter'],
                    icon: Icons.calendar_view_month,
                  ),
                if (member['profession'] != null &&
                    member['profession'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Profession',
                    value: MemberConstants.getProfessionLabel(
                      member['profession'],
                    ),
                    icon: Icons.work,
                  ),
                if (member['level_of_study'] != null &&
                    member['level_of_study'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Level of Study',
                    value: member['level_of_study'],
                    icon: Icons.school,
                  ),
                if (member['sector_of_studies'] != null &&
                    member['sector_of_studies'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Sector of Studies',
                    value: member['sector_of_studies'],
                    icon: Icons.category,
                  ),
                if (member['domain_of_activity'] != null &&
                    member['domain_of_activity'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Domain of Activity',
                    value: member['domain_of_activity'],
                    icon: Icons.business,
                  ),
                if (member['key_skills'] != null &&
                    _getKeySkillsList(member['key_skills']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingSM,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.star,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppDimensions.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Key Skills: ',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppDimensions.spacingXS),
                              Wrap(
                                spacing: AppDimensions.spacingSM,
                                runSpacing: AppDimensions.spacingSM,
                                children:
                                    _getKeySkillsList(member['key_skills'])
                                        .map(
                                          (skill) => Chip(
                                            label: Text(skill),
                                            padding: EdgeInsets.zero,
                                            labelPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (member['last_diplomas'] != null &&
                    member['last_diplomas'].toString().isNotEmpty)
                  _InfoRow(
                    label: 'Last Diplomas',
                    value: member['last_diplomas'],
                    icon: Icons.workspace_premium,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String role) {
    Color chipColor;
    String label;
    switch (role) {
      case 'admin':
        chipColor = AppColors.error;
        label = 'Admin';
        break;
      case 'leader':
        chipColor = AppColors.warning;
        label = 'Leader';
        break;
      case 'worker':
        chipColor = AppColors.primary;
        label = 'Worker';
        break;
      case 'sympathiser':
        chipColor = AppColors.textSecondary;
        label = 'Sympathiser';
        break;
      default:
        chipColor = AppColors.textSecondary;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: chipColor,
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'leader':
        return 'Leader';
      case 'worker':
        return 'Worker';
      case 'sympathiser':
        return 'Sympathiser';
      default:
        return 'Member';
    }
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

/// Attendance tab
class _AttendanceTab extends StatelessWidget {
  final Map<String, dynamic>? report;

  const _AttendanceTab({this.report});

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const Center(child: Text('No attendance data'));
    }

    final attendance = report!['attendance'] as Map<String, dynamic>;
    final total = attendance['total'] as int;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              children: [
                Text(
                  'Total Attendance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                Text(
                  '$total',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMD),
                Text(
                  'Last 90 days',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        // Attendance records list
        ...((attendance['records'] as List?) ?? []).map((record) {
          return ListTile(
            leading: const Icon(Icons.event),
            title: Text('Session ${record['session_number']}'),
            subtitle: Text(record['status'] ?? 'unknown'),
            trailing: Text(
              record['created_at'] != null
                  ? DateTime.parse(
                      record['created_at'],
                    ).toString().split(' ')[0]
                  : '',
            ),
          );
        }),
      ],
    );
  }
}

/// Classes tab
class _ClassesTab extends StatefulWidget {
  final String memberId;

  const _ClassesTab({required this.memberId});

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

  Future<void> _loadMemberClasses() async {
    try {
      // Get classes where member is enrolled
      final enrollments = await SupabaseService.client
          .from('class_members')
          .select('*, classes(*)')
          .eq('member_id', widget.memberId);

      setState(() {
        _classes = (enrollments as List)
            .map((e) => e['classes'] as Map<String, dynamic>?)
            .where((c) => c != null)
            .cast<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classes.isEmpty) {
      return const Center(child: Text('No classes enrolled'));
    }

    return ListView.builder(
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classItem = _classes[index];
        return ListTile(
          leading: const Icon(Icons.class_),
          title: Text(classItem['name'] ?? 'Unnamed Class'),
          subtitle: classItem['description'] != null
              ? Text(classItem['description'].toString())
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pushNamed(
              context,
              '${RouteNames.classes}/${classItem['id']}',
            );
          },
        );
      },
    );
  }
}

/// Info row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSM),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.spacingMD),
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
