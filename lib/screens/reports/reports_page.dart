import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/member_service.dart';
import '../../services/class_service.dart';
import 'member_report_page.dart';

/// Reports page with member and training reports
class ReportsPage extends StatelessWidget {
  final bool hideAppBarAndBottomNav;

  const ReportsPage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: hideAppBarAndBottomNav
          ? null
          : AppBar(title: Text(localizations?.statistics ?? 'Reports')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          _ReportCard(
            title: 'Member Report',
            description: 'View attendance and giving for a member',
            icon: Icons.person_outline,
            onTap: () {
              // Show member selection dialog
              _showMemberSelectionDialog(context);
            },
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          _ReportCard(
            title: 'Training Report',
            description: 'View attendance statistics for a training',
            icon: Icons.class_outlined,
            onTap: () {
              // Show training selection dialog
              _showClassSelectionDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMemberSelectionDialog(BuildContext context) async {
    try {
      final members = await MemberService.getMembers(limit: 100);
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => _MemberSelectionDialog(members: members),
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

      showDialog(
        context: context,
        builder: (context) => _ClassSelectionDialog(classes: classes),
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

  const _MemberSelectionDialog({required this.members});

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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: SizedBox(
          width: double.maxFinite,
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
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
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
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MemberReportPage(
                                    memberId: member['id'].toString(),
                                  ),
                                ),
                              );
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

  const _ClassSelectionDialog({required this.classes});

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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 500),
        child: SizedBox(
          width: double.maxFinite,
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
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
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
                              Navigator.pop(context);
                              Navigator.pushNamed(
                                context,
                                '/reports/training/${classItem['id']}',
                              );
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
