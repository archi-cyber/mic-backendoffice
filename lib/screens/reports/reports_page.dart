import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../services/member_service.dart';
import '../../services/class_service.dart';
import 'member_report_page.dart';
import 'class_report_page.dart';

/// Reports page with member and training reports
class ReportsPage extends StatefulWidget {
  final bool hideAppBarAndBottomNav;

  const ReportsPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDesktop = widget.hideAppBarAndBottomNav;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(title: Text(localizations?.statistics ?? 'Reports')),
      body: isDesktop ? _buildDesktopBody(context) : _buildMobileBody(context),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)?.statistics ?? 'Reports',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXL),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _ReportCard(
                      title: 'Member Report',
                      description: 'View attendance and giving for a member',
                      icon: Icons.person_outline,
                      onTap: () => _showMemberSelectionDialog(context),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingLG),
                  Expanded(
                    child: _ReportCard(
                      title: 'Training Report',
                      description: 'View attendance statistics for a training',
                      icon: Icons.class_outlined,
                      onTap: () => _showClassSelectionDialog(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      children: [
        _ReportCard(
          title: 'Member Report',
          description: 'View attendance and giving for a member',
          icon: Icons.person_outline,
          onTap: () => _showMemberSelectionDialog(context),
        ),
        const SizedBox(height: AppDimensions.spacingMD),
        _ReportCard(
          title: 'Training Report',
          description: 'View attendance statistics for a training',
          icon: Icons.class_outlined,
          onTap: () => _showClassSelectionDialog(context),
        ),
      ],
    );
  }

  void _showMemberSelectionDialog(BuildContext context) async {
    try {
      final members = await MemberService.getMembers(limit: 100);
      if (!context.mounted) return;

      final scope = DesktopShellScope.maybeOf(context);
      final openAsStack = scope != null && widget.hideAppBarAndBottomNav;
      final narrowDialog = openAsStack;

      showDialog(
        context: context,
        builder: (context) => _MemberSelectionDialog(
          members: members,
          narrowForDesktop: narrowDialog,
          onSelect: (memberId) {
            Navigator.pop(context);
            if (openAsStack) {
              scope.pushDetail(RouteNames.memberReport, memberId);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemberReportPage(memberId: memberId),
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  void _showClassSelectionDialog(BuildContext context) async {
    try {
      final classes = await ClassService.getClasses(limit: 100);
      if (!context.mounted) return;

      final scope = DesktopShellScope.maybeOf(context);
      final openAsStack = scope != null && widget.hideAppBarAndBottomNav;
      final narrowDialog = openAsStack;

      showDialog(
        context: context,
        builder: (context) => _ClassSelectionDialog(
          classes: classes,
          narrowForDesktop: narrowDialog,
          onSelect: (classId) {
            Navigator.pop(context);
            if (openAsStack) {
              scope.pushDetail(RouteNames.classReport, classId);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClassReportPage(classId: classId),
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading trainings: $e')));
      }
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Icon(icon, size: 48, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final bool narrowForDesktop;
  final void Function(String memberId) onSelect;

  const _MemberSelectionDialog({
    required this.members,
    this.narrowForDesktop = false,
    required this.onSelect,
  });

  @override
  State<_MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<_MemberSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _filteredMembers = widget.members;
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredMembers = widget.members;
    } else {
      _filteredMembers = widget.members.where((member) {
        final firstName = (member['first_name'] ?? '').toString().toLowerCase();
        final lastName = (member['last_name'] ?? '').toString().toLowerCase();
        final email = (member['email'] ?? '').toString().toLowerCase();
        final phone = (member['phone'] ?? '').toString().toLowerCase();

        return firstName.contains(query) ||
            lastName.contains(query) ||
            '$firstName $lastName'.contains(query) ||
            email.contains(query) ||
            phone.contains(query);
      }).toList();
    }
    setState(() {}); // Rebuild to update UI
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Member'),
      contentPadding: widget.narrowForDesktop
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
          : null,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 500,
          maxWidth: widget.narrowForDesktop ? 480 : double.infinity,
        ),
        child: SizedBox(
          width: widget.narrowForDesktop ? 480 : double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar
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
                onChanged: (_) =>
                    setState(() {}), // Rebuild to update suffixIcon
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              // Members List
              Flexible(
                child: _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              'No members found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.spacingXS),
                              Text(
                                'Try adjusting your search',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: false,
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              '${member['first_name']} ${member['last_name']}',
                            ),
                            subtitle: member['email'] != null
                                ? Text(member['email'].toString())
                                : null,
                            onTap: () {
                              widget.onSelect(member['id'].toString());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ClassSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final bool narrowForDesktop;
  final void Function(String classId) onSelect;

  const _ClassSelectionDialog({
    required this.classes,
    this.narrowForDesktop = false,
    required this.onSelect,
  });

  @override
  State<_ClassSelectionDialog> createState() => _ClassSelectionDialogState();
}

class _ClassSelectionDialogState extends State<_ClassSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredClasses = [];

  @override
  void initState() {
    super.initState();
    _filteredClasses = widget.classes;
    _searchController.addListener(_filterClasses);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterClasses() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredClasses = widget.classes;
    } else {
      _filteredClasses = widget.classes.where((classItem) {
        final name = (classItem['name'] ?? '').toString().toLowerCase();
        final description = (classItem['description'] ?? '')
            .toString()
            .toLowerCase();

        return name.contains(query) || description.contains(query);
      }).toList();
    }
    setState(() {}); // Rebuild to update UI
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Training'),
      contentPadding: widget.narrowForDesktop
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
          : null,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 500,
          maxWidth: widget.narrowForDesktop ? 480 : double.infinity,
        ),
        child: SizedBox(
          width: widget.narrowForDesktop ? 480 : double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search trainings...',
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
                onChanged: (_) =>
                    setState(() {}), // Rebuild to update suffixIcon
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              // Classes List
              Flexible(
                child: widget.classes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 48,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              'No trainings available',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : _filteredClasses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(height: AppDimensions.spacingSM),
                            Text(
                              'No trainings found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              const SizedBox(height: AppDimensions.spacingXS),
                              Text(
                                'Try adjusting your search',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: false,
                        itemCount: _filteredClasses.length,
                        itemBuilder: (context, index) {
                          final classItem = _filteredClasses[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.class_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              classItem['name'] ?? 'Unnamed Training',
                            ),
                            subtitle: classItem['description'] != null
                                ? Text(classItem['description'].toString())
                                : null,
                            onTap: () {
                              widget.onSelect(classItem['id'].toString());
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
