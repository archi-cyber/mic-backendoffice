import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/data_export_service.dart';
import '../../services/data_import_service.dart';
import '../../services/user_member_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/role_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

/// Settings page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
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

  Future<void> _changeLanguage(Locale locale) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      await settingsProvider.setLocale(locale);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.languageChanged ?? 'Language changed successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorChangingLanguage ??
                  'Failed to change language: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      await settingsProvider.setThemeMode(themeMode);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.themeChanged ?? 'Theme changed successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorChangingTheme ?? 'Failed to change theme: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      await settingsProvider.setNotificationsEnabled(enabled);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? (localizations?.notificationsEnabled ??
                        'Notifications enabled')
                  : (localizations?.notificationsDisabled ??
                        'Notifications disabled'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.errorUpdatingNotifications ??
                  'Failed to update notifications: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportAllData() async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.exportAllData ?? 'Export All Data'),
        content: Text(
          localizations?.exportAllDataConfirm ??
              'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations?.export ?? 'Export'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.exporting ?? 'Exporting data...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final filePath = await DataExportService.exportAllDataAsJson();
      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.dataExportedWithPath(filePath) ??
                    'Data exported successfully to:\n$filePath',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.exportCancelled ?? 'Export cancelled',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.exportFailed ?? 'Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportMembers() async {
    final localizations = AppLocalizations.of(context);
    try {
      final file = await DataExportService.exportMembersToCSV();
      await Share.shareXFiles([
        XFile(file.path),
      ], text: localizations?.exportMembers ?? 'Members Export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.membersExported ?? 'Members exported successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.exportFailed ?? 'Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _syncUsersAndMembers() async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.syncUsersMembers ?? 'Sync Users & Members'),
        content: Text(
          localizations?.syncUsersMembersConfirm ??
              'This will:\n'
                  '1. Create a member for every user\n'
                  '2. Create a user (with default password "Password123") for every leader member\n\n'
                  'Leaders will be required to change their password on first login.\n\n'
                  'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations?.sync ?? 'Sync'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.syncing ?? 'Syncing users and members...',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final result = await UserMemberSyncService.syncAll();

      final usersToMembers = result['users_to_members'] as Map<String, dynamic>;
      final leadersToUsers = result['leaders_to_users'] as Map<String, dynamic>;

      if (mounted) {
        final message =
            '${localizations?.syncCompleted ?? 'Sync completed!'}\n'
            '${localizations?.usersToMembers ?? 'Users → Members'}: ${usersToMembers['created']} ${localizations?.createdLabel ?? 'created'}, '
            '${usersToMembers['skipped']} ${localizations?.skippedLabel ?? 'skipped'}, '
            '${usersToMembers['errors']} ${localizations?.errorsLabel ?? 'errors'}\n'
            '${localizations?.leadersToUsers ?? 'Leaders → Users'}: ${leadersToUsers['created']} ${localizations?.createdLabel ?? 'created'}, '
            '${leadersToUsers['skipped']} ${localizations?.skippedLabel ?? 'skipped'}, '
            '${leadersToUsers['errors']} ${localizations?.errorsLabel ?? 'errors'}';

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
            content: Text(localizations?.syncFailed ?? 'Sync failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _generateAllUsersReport() async {
    final localizations = AppLocalizations.of(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.generatingReport ?? 'Generating report...',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final filePath = await DataExportService.exportAllUsersReportAsPdf();
      if (mounted) {
        if (filePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.reportSavedWithPath(filePath) ??
                    'Report saved successfully to:\n$filePath',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations?.reportGenerationCancelled ??
                    'Report generation cancelled',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.reportGenerationFailed ??
                  'Report generation failed: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.importData ?? 'Import Data'),
        content: Text(
          localizations?.importDataConfirm ??
              'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations?.import ?? 'Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.importing ?? 'Importing data...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final results = await DataImportService.importFromFile();
      final membersResult = results['members'] as Map<String, dynamic>?;

      if (mounted) {
        final message = membersResult != null
            ? '${localizations?.importedLabel ?? 'Imported'} ${membersResult['success_count']} ${localizations?.members ?? 'members'}. '
                  '${membersResult['error_count']} ${localizations?.errorsLabel ?? 'errors'}.'
            : (localizations?.importCompleted ?? 'Import completed');

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
            content: Text(localizations?.importFailed ?? 'Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        if (settingsProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final localizations = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(localizations?.settings ?? 'Settings')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            children: [
              // Language Settings
              _buildSectionHeader(
                localizations?.languageAndRegion ?? 'Language & Region',
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(localizations?.language ?? 'Language'),
                  subtitle: Text(
                    settingsProvider.locale?.languageCode == 'fr'
                        ? 'Français'
                        : settingsProvider.locale?.languageCode == 'es'
                        ? 'Español'
                        : 'English',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(settingsProvider.locale),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Appearance Settings
              _buildSectionHeader(localizations?.appearance ?? 'Appearance'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: Text(localizations?.theme ?? 'Theme'),
                      subtitle: Text(
                        settingsProvider.themeMode == ThemeMode.light
                            ? (localizations?.light ?? 'Light')
                            : settingsProvider.themeMode == ThemeMode.dark
                            ? (localizations?.dark ?? 'Dark')
                            : (localizations?.systemDefault ??
                                  'System Default'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemeDialog(settingsProvider.themeMode),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Notifications Settings
              _buildSectionHeader(
                localizations?.notifications ?? 'Notifications',
              ),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.notifications),
                  title: Text(
                    localizations?.enableNotifications ??
                        'Enable Notifications',
                  ),
                  subtitle: Text(
                    localizations?.receivePushNotifications ??
                        'Receive push notifications',
                  ),
                  value: settingsProvider.notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Data Management
              _buildSectionHeader(
                localizations?.dataManagement ?? 'Data Management',
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.upload_file,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        localizations?.exportAllData ?? 'Export All Data',
                      ),
                      subtitle: Text(
                        localizations?.exportAllDataSubtitle ??
                            'Export all data to JSON file',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _exportAllData,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.file_download,
                        color: AppColors.primary,
                      ),
                      title: Text(localizations?.importData ?? 'Import Data'),
                      subtitle: Text(
                        localizations?.importDataSubtitle ??
                            'Import data from JSON file',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _importData,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.people,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        localizations?.exportMembers ?? 'Export Members',
                      ),
                      subtitle: Text(
                        localizations?.exportMembersSubtitle ??
                            'Export members to CSV',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _exportMembers,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.sync, color: AppColors.primary),
                      title: Text(
                        localizations?.syncUsersMembers ??
                            'Sync Users & Members',
                      ),
                      subtitle: Text(
                        localizations?.syncUsersMembers ??
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
              _buildSectionHeader(localizations?.reports ?? 'Reports'),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.assessment,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    localizations?.generateAllUsersReport ??
                        'Generate All Users Report',
                  ),
                  subtitle: Text(
                    localizations?.generateReportComprehensive ??
                        'Generate comprehensive report for all users',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _generateAllUsersReport,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Other Settings
              _buildSectionHeader(localizations?.other ?? 'Other'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cake),
                  title: Text(
                    localizations?.birthdayNotifications ??
                        'Birthday Notifications',
                  ),
                  subtitle: Text(
                    localizations?.configureBirthdayNotifications ??
                        'Configure birthday notification settings',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      RouteNames.notifications,
                      arguments: 'birthday',
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Admin Settings
              if (_isAdmin) ...[
                _buildSectionHeader(
                  localizations?.adminSettings ?? 'Admin Settings',
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      localizations?.leaderAccessManagement ??
                          'Leader Access Management',
                    ),
                    subtitle: Text(
                      localizations?.defineFeatureAccess ??
                          'Define feature access for each leader',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(RouteNames.leaderAccess);
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.person_add,
                      color: AppColors.primary,
                    ),
                    title: const Text('Member Accounts'),
                    subtitle: const Text(
                      'Create login accounts for members and manage their access',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(
                        context,
                      ).pushNamed(RouteNames.memberAccounts);
                    },
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMD),
              ],

              // Account
              _buildSectionHeader(localizations?.account ?? 'Account'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(localizations?.currentUser ?? 'Current User'),
                      subtitle: Text(
                        SupabaseService.currentUser?.email ??
                            (localizations?.notLoggedIn ?? 'Not logged in'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: AppColors.error),
                      title: Text(
                        localizations?.logout ?? 'Logout',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      subtitle: Text(
                        localizations?.signOutAccount ??
                            'Sign out of your account',
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // App Info
              _buildSectionHeader(localizations?.about ?? 'About'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(localizations?.appVersion ?? 'App Version'),
                  subtitle: const Text('1.0.0'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final localizations = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.logout ?? 'Logout'),
        content: Text(
          localizations?.logoutConfirm ?? 'Are you sure you want to logout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations?.logout ?? 'Logout'),
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
            content: Text(localizations?.logoutFailed ?? 'Logout failed: $e'),
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

  Future<void> _showLanguageDialog(Locale? currentLocale) async {
    final localizations = AppLocalizations.of(context);
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.language ?? 'Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale>(
              title: const Text('English'),
              value: const Locale('en'),
              groupValue: currentLocale ?? const Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: const Text('Español'),
              value: const Locale('es'),
              groupValue: currentLocale ?? const Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: const Text('Français'),
              value: const Locale('fr'),
              groupValue: currentLocale ?? const Locale('en'),
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
    }
  }

  Future<void> _showThemeDialog(ThemeMode currentThemeMode) async {
    final localizations = AppLocalizations.of(context);
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.selectTheme ?? 'Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text(localizations?.light ?? 'Light'),
              value: ThemeMode.light,
              groupValue: currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: Text(localizations?.dark ?? 'Dark'),
              value: ThemeMode.dark,
              groupValue: currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: Text(localizations?.systemDefault ?? 'System Default'),
              value: ThemeMode.system,
              groupValue: currentThemeMode,
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
      await _changeThemeMode(selected);
    }
  }
}
