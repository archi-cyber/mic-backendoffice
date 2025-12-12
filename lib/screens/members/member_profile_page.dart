import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import '../../services/report_service.dart';
import '../../services/supabase_service.dart';

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
      setState(() {
        _member = member;
        _report = report;
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
      default:
        return 'Member';
    }
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
