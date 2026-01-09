import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/data_export_service.dart';
import '../../services/data_import_service.dart';
import '../../services/user_member_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/role_service.dart';
import '../../providers/auth_provider.dart';

/// Settings page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Locale? _currentLocale;
  ThemeMode _currentThemeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadSettings();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await RoleService.isCurrentUserAdmin();
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      setState(() => _isAdmin = false);
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SettingsService.getLocale(),
        SettingsService.getThemeMode(),
        SettingsService.getNotificationsEnabled(),
      ]);

      setState(() {
        _currentLocale = results[0] as Locale?;
        _currentThemeMode = results[1] as ThemeMode;
        _notificationsEnabled = results[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changeLanguage(Locale locale) async {
    try {
      await SettingsService.setLocale(locale);
      setState(() => _currentLocale = locale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Language changed. Please restart the app.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    try {
      await SettingsService.setThemeMode(themeMode);
      setState(() => _currentThemeMode = themeMode);
      // Update theme in MaterialApp
      if (mounted) {
        // Note: This requires a provider or state management to update theme
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theme changed. Please restart the app.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change theme: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      await SettingsService.setNotificationsEnabled(enabled);
      setState(() => _notificationsEnabled = enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled ? 'Notifications enabled' : 'Notifications disabled',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export All Data'),
        content: const Text(
          'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting data...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final filePath = await DataExportService.exportAllDataAsJson();
      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Data exported successfully to:\n$filePath'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export cancelled'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportMembers() async {
    try {
      final file = await DataExportService.exportMembersToCSV();
      await Share.shareXFiles([XFile(file.path)], text: 'Members Export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members exported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _syncUsersAndMembers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Users & Members'),
        content: const Text(
          'This will:\n'
          '1. Create a member for every user\n'
          '2. Create a user (with default password "Password123") for every leader member\n\n'
          'Leaders will be required to change their password on first login.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncing users and members...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final result = await UserMemberSyncService.syncAll();

      final usersToMembers = result['users_to_members'] as Map<String, dynamic>;
      final leadersToUsers = result['leaders_to_users'] as Map<String, dynamic>;

      if (mounted) {
        final message =
            'Sync completed!\n'
            'Users → Members: ${usersToMembers['created']} created, '
            '${usersToMembers['skipped']} skipped, '
            '${usersToMembers['errors']} errors\n'
            'Leaders → Users: ${leadersToUsers['created']} created, '
            '${leadersToUsers['skipped']} skipped, '
            '${leadersToUsers['errors']} errors';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _generateAllUsersReport() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating report...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final filePath = await DataExportService.exportAllUsersReportAsPdf();
      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report saved successfully to:\n$filePath'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report generation cancelled'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importing data...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final results = await DataImportService.importFromFile();
      final membersResult = results['members'] as Map<String, dynamic>?;

      if (mounted) {
        final message = membersResult != null
            ? 'Imported ${membersResult['success_count']} members. '
                  '${membersResult['error_count']} errors.'
            : 'Import completed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          // Language Settings
          _buildSectionHeader('Language & Region'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: Text(
                _currentLocale?.languageCode == 'fr' ? 'Français' : 'English',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguageDialog(),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Appearance Settings
          _buildSectionHeader('Appearance'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(
                    _currentThemeMode == ThemeMode.light
                        ? 'Light'
                        : _currentThemeMode == ThemeMode.dark
                        ? 'Dark'
                        : 'System Default',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Notifications Settings
          _buildSectionHeader('Notifications'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Data Management
          _buildSectionHeader('Data Management'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.upload_file,
                    color: AppColors.primary,
                  ),
                  title: const Text('Export All Data'),
                  subtitle: const Text('Export all data to JSON file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportAllData,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.file_download,
                    color: AppColors.primary,
                  ),
                  title: const Text('Import Data'),
                  subtitle: const Text('Import data from JSON file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importData,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.people, color: AppColors.primary),
                  title: const Text('Export Members'),
                  subtitle: const Text('Export members to CSV'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportMembers,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.sync, color: AppColors.primary),
                  title: const Text('Sync Users & Members'),
                  subtitle: const Text(
                    'Create members for all users and users for all leaders',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _syncUsersAndMembers,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Reports
          _buildSectionHeader('Reports'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assessment, color: AppColors.primary),
              title: const Text('Generate All Users Report'),
              subtitle: const Text(
                'Generate comprehensive report for all users',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _generateAllUsersReport,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Other Settings
          _buildSectionHeader('Other'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake),
              title: const Text('Birthday Notifications'),
              subtitle: const Text('Configure birthday notification settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(
                  context,
                ).pushNamed(RouteNames.notifications, arguments: 'birthday');
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // Admin Settings
          if (_isAdmin) ...[
            _buildSectionHeader('Admin Settings'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                title: const Text('Leader Access Management'),
                subtitle: const Text('Define feature access for each leader'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).pushNamed(RouteNames.leaderAccess);
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMD),
          ],

          // Account
          _buildSectionHeader('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Current User'),
                  subtitle: Text(
                    SupabaseService.currentUser?.email ?? 'Not logged in',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.error),
                  ),
                  subtitle: const Text('Sign out of your account'),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),

          // App Info
          _buildSectionHeader('About'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Version'),
              subtitle: const Text('1.0.0'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      if (mounted) {
        // Navigate to login page
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimensions.spacingMD,
        bottom: AppDimensions.spacingSM,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final localizations = AppLocalizations.of(context);
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.settings ?? 'Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale>(
              title: const Text('English'),
              value: const Locale('en'),
              groupValue: _currentLocale ?? const Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: const Text('Français'),
              value: const Locale('fr'),
              groupValue: _currentLocale ?? const Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _changeLanguage(selected);
      // Reload the app to apply locale change
      // Note: In a production app, you might want to use a locale provider
      // to update the locale dynamically without restart
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.dashboard, (route) => false);
      }
    }
  }

  Future<void> _showThemeDialog() async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: _currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: _currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System Default'),
              value: ThemeMode.system,
              groupValue: _currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _changeThemeMode(selected);
    }
  }
}
