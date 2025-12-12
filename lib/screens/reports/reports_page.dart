import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/member_service.dart';
import '../../services/class_service.dart';
import 'member_report_page.dart';

/// Reports page with member and class reports
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations?.statistics ?? 'Reports')),
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
            title: 'Class Report',
            description: 'View attendance statistics for a class',
            icon: Icons.class_outlined,
            onTap: () {
              // Show class selection dialog
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
        builder: (context) => AlertDialog(
          title: const Text('Select Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  title: Text('${member['first_name']} ${member['last_name']}'),
                  subtitle: Text(member['email'] ?? ''),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MemberReportPage(memberId: member['id'].toString()),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
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

      final selectedClass = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Class'),
          content: SizedBox(
            width: double.maxFinite,
            child: classes.isEmpty
                ? const Text('No classes available')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final classItem = classes[index];
                      return ListTile(
                        title: Text(classItem['name'] ?? 'Unnamed Class'),
                        subtitle: classItem['description'] != null
                            ? Text(classItem['description'].toString())
                            : null,
                        onTap: () => Navigator.pop(context, classItem),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedClass != null && context.mounted) {
        Navigator.pushNamed(context, '/reports/class/${selectedClass['id']}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading classes: $e')));
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
