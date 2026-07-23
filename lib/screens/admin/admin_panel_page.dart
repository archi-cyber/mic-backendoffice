import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/admin_service.dart';
import '../../core/localization/app_localizations.dart';

/// Admin panel for user management
class AdminPanelPage extends StatelessWidget {
  AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Admin Panel'))),
      body: ListView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          _AdminCard(
            title: context.tr('Create User'),
            description: context.tr('Create admin, pastor, or admin users'),
            icon: Icons.person_add_outlined,
            onTap: () => _showCreateUserDialog(context),
          ),
          SizedBox(height: AppDimensions.spacingMD),
          _AdminCard(
            title: context.tr('Role Assignment'),
            description: context.tr('Assign roles to users'),
            icon: Icons.admin_panel_settings_outlined,
            onTap: () {
              // Navigate to role assignment
            },
          ),
          SizedBox(height: AppDimensions.spacingMD),
          _AdminCard(
            title: context.tr('Activity Logs'),
            description: context.tr('View system activity logs'),
            icon: Icons.history_outlined,
            onTap: () {
              // Navigate to logs
            },
          ),
        ],
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'admin';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.tr('Create User')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: context.tr('Email'),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: AppDimensions.spacingMD),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: context.tr('Password'),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              SizedBox(height: AppDimensions.spacingMD),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: context.tr('Role'),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text(context.tr('Admin')),
                  ),
                  DropdownMenuItem(
                    value: 'pastor',
                    child: Text(context.tr('Pastor')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AdminService.createAdminUser(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    role: selectedRole,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('User created successfully')),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Error: $e')),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(context.tr('Create')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  _AdminCard({
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
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: Row(
            children: [
              Icon(icon, size: 48, color: AppColors.primary),
              SizedBox(width: AppDimensions.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: AppDimensions.spacingXS),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
