import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../services/data_export_service.dart';
import '../../services/data_import_service.dart';
import '../../services/user_member_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/role_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Settings page
class SettingsPage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  SettingsPage({super.key, this.hideAppBarAndBottomNav = false});

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
        title: Text(context.tr('Export All Data')),
        content: Text(
          context.tr(
            'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Export')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.exporting ?? 'Exporting data...'),
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
              content: Text(
                localizations?.dataExportedWithPath(filePath) ??
                    'Data exported successfully to:\n$filePath',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
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
        title: Text(context.tr('Sync Users & Members')),
        content: Text(
          context.tr(
            'This will:\n'
            '1. Create a member for every user\n'
            '2. Create a user (with default password "Password123") for every leader member\n\n'
            'Leaders will be required to change their password on first login.\n\n'
            'Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Sync')),
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
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.syncFailed ?? 'Sync failed: $e'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 5),
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
              content: Text(
                localizations?.reportSavedWithPath(filePath) ??
                    'Report saved successfully to:\n$filePath',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 4),
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
        title: Text(context.tr('Import Data')),
        content: Text(
          context.tr(
            'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Import')),
          ),
       ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations?.importing ?? 'Importing data...'),
          duration: Duration(seconds: 2),
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
            duration: Duration(seconds: 5),
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
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final localizations = AppLocalizations.of(context);
        final isDesktop = isDesktopEmbedded(
          context,
          hideAppBar: widget.hideAppBarAndBottomNav,
        );
        return Scaffold(
          appBar: widget.hideAppBarAndBottomNav
              ? null
              : AppBar(title: Text(localizations?.settings ?? 'Settings')),
          body: isDesktop
              ? _buildDesktopBody(context, settingsProvider, localizations)
              : ListView(
            padding: EdgeInsets.all(AppDimensions.paddingMD),
            children: [
              // Language Settings
              _buildSectionHeader(
                localizations?.languageAndRegion ?? 'Language & Region',
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.language),
                  title: Text(localizations?.language ?? 'Language'),
                  subtitle: Text(
                    settingsProvider.locale?.languageCode == 'fr'
                        ? 'Français'
                        : settingsProvider.locale?.languageCode == 'es'
                        ? 'Español'
                        : 'English',
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _showLanguageDialog(settingsProvider.locale),
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Appearance Settings
              _buildSectionHeader(localizations?.appearance ?? 'Appearance'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.brightness_6),
                      title: Text(localizations?.theme ?? 'Theme'),
                      subtitle: Text(
                        settingsProvider.themeMode == ThemeMode.light
                            ? (localizations?.light ?? 'Light')
                            : settingsProvider.themeMode == ThemeMode.dark
                            ? (localizations?.dark ?? 'Dark')
                            : (localizations?.systemDefault ??
                                  'System Default'),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => _showThemeDialog(settingsProvider.themeMode),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Notifications Settings
              _buildSectionHeader(
                localizations?.notifications ?? 'Notifications',
              ),
              Card(
                child: SwitchListTile(
                  secondary: Icon(Icons.notifications),
                  title: Text(
                    localizations?.enableNotifications ??
                        'Enable Notifications',
                  ),
                  subtitle: Text(
                    localizations?.receivePushNotifications ??
                        context.tr('Receive push notifications'),
                  ),
                  value: settingsProvider.notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Data Management
              _buildSectionHeader(
                localizations?.dataManagement ?? 'Data Management',
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.upload_file,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        localizations?.exportAllData ?? 'Export All Data',
                      ),
                      subtitle: Text(
                        localizations?.exportAllDataSubtitle ??
                            context.tr('Export all data to JSON file'),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _exportAllData,
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.file_download,
                        color: AppColors.primary,
                      ),
                      title: Text(localizations?.importData ?? 'Import Data'),
                      subtitle: Text(
                        localizations?.importDataSubtitle ??
                            context.tr('Import data from JSON file'),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _importData,
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.people, color: AppColors.primary),
                      title: Text(
                        localizations?.exportMembers ?? 'Export Members',
                      ),
                      subtitle: Text(
                        localizations?.exportMembersSubtitle ??
                            context.tr('Export members to CSV'),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _exportMembers,
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.sync, color: AppColors.primary),
                      title: Text(
                        localizations?.syncUsersMembers ??
                            'Sync Users & Members',
                      ),
                      subtitle: Text(
                        localizations?.syncUsersMembers ??
                            context.tr(
                              'Create members for all users and users for all leaders',
                            ),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _syncUsersAndMembers,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Reports
              _buildSectionHeader(localizations?.reports ?? 'Reports'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.assessment, color: AppColors.primary),
                  title: Text(
                    localizations?.generateAllUsersReport ??
                        'Generate All Users Report',
                  ),
                  subtitle: Text(
                    localizations?.generateReportComprehensive ??
                        context.tr(
                          'Generate comprehensive report for all users',
                        ),
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _generateAllUsersReport,
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Other Settings
              _buildSectionHeader(localizations?.other ?? 'Other'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.cake),
                  title: Text(
                    localizations?.birthdayNotifications ??
                        'Birthday Notifications',
                  ),
                  subtitle: Text(
                    localizations?.configureBirthdayNotifications ??
                        context.tr('Configure birthday notification settings'),
                  ),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    final scope = DesktopShellScope.maybeOf(context);
                    if (widget.hideAppBarAndBottomNav && scope != null) {
                      scope.pushDetail(
                        RouteNames.birthdayNotificationsSettings,
                        '',
                      );
                    } else {
                      Navigator.of(context).pushNamed(
                        RouteNames.notifications,
                        arguments: 'birthday',
                      );
                    }
                  },
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // Admin Settings
              if (_isAdmin) ...[
                _buildSectionHeader(
                  localizations?.adminSettings ?? 'Admin Settings',
                ),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      localizations?.leaderAccessManagement ??
                          'Leader Access Management',
                    ),
                    subtitle: Text(
                      localizations?.defineFeatureAccess ??
                          context.tr('Define feature access for each leader'),
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      final scope = DesktopShellScope.maybeOf(context);
                      if (widget.hideAppBarAndBottomNav && scope != null) {
                        scope.pushDetail(RouteNames.leaderAccess, '');
                      } else {
                        Navigator.of(
                          context,
                        ).pushNamed(RouteNames.leaderAccess);
                      }
                    },
                  ),
                ),
                SizedBox(height: AppDimensions.spacingSM),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: AppColors.primary),
                    title: Text(context.tr('Member Accounts')),
                    subtitle: Text(
                    context.tr(
                      'Create login accounts for members and manage their access',
                    ),
                  ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      final scope = DesktopShellScope.maybeOf(context);
                      if (widget.hideAppBarAndBottomNav && scope != null) {
                        scope.pushDetail(RouteNames.memberAccounts, '');
                      } else {
                        Navigator.of(
                          context,
                        ).pushNamed(RouteNames.memberAccounts);
                      }
                    },
                  ),
                ),
                SizedBox(height: AppDimensions.spacingMD),
              ],

              // Account
              _buildSectionHeader(localizations?.account ?? 'Account'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person),
                      title: Text(localizations?.currentUser ?? 'Current User'),
                      subtitle: Text(
                        SupabaseService.currentUser?.email ??
                            (localizations?.notLoggedIn ?? 'Not logged in'),
                      ),
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.logout, color: AppColors.error),
                      title: Text(
                        localizations?.logout ?? 'Logout',
                        style: TextStyle(color: AppColors.error),
                      ),
                      subtitle: Text(
                        localizations?.signOutAccount ??
                            context.tr('Sign out of your account'),
                      ),
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDimensions.spacingMD),

              // App Info
              _buildSectionHeader(localizations?.about ?? 'About'),
              Card(
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text(localizations?.appVersion ?? 'App Version'),
                  subtitle: Text('1.0.0'),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Logout')),
        content: Text(context.tr('Are you sure you want to logout?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.tr('Logout')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await authProvider.logout();

      if (mounted) {
        navigator.pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
      }
    } catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(localizations?.logoutFailed ?? 'Logout failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildDesktopBody(
    BuildContext context,
    SettingsProvider settingsProvider,
    AppLocalizations? localizations,
  ) {
    final scope = DesktopShellScope.maybeOf(context);
    final languageLabel = settingsProvider.locale?.languageCode == 'fr'
        ? 'Français'
        : settingsProvider.locale?.languageCode == 'es'
        ? 'Español'
        : 'English';
    final themeLabel = settingsProvider.themeMode == ThemeMode.light
        ? (localizations?.light ?? 'Light')
        : settingsProvider.themeMode == ThemeMode.dark
        ? (localizations?.dark ?? 'Dark')
        : (localizations?.systemDefault ?? 'System Default');

    return DesktopPageShell(
      banner: DesktopHeroBanner(
        title: localizations?.settings ?? 'Settings',
        subtitle: context.tr('Manage preferences, data, and admin tools'),
        icon: Icons.settings_outlined,
        accent: AppColors.secondary,
        trailing: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMD,
            vertical: AppDimensions.spacingSM,
          ),
          decoration: BoxDecoration(
            color: context.mic.accentIconBackground(AppColors.secondary),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          child: Text(
            SupabaseService.currentUser?.email ?? context.tr('Account'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.mic.appBarForeground,
                ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppDimensions.spacingSM,
            runSpacing: AppDimensions.spacingSM,
            children: [
              DesktopStatChip(
                label: localizations?.language ?? 'Language',
                value: languageLabel,
                icon: Icons.translate,
                color: AppColors.primary,
              ),
              DesktopStatChip(
                label: localizations?.theme ?? 'Theme',
                value: themeLabel,
                icon: Icons.palette_outlined,
                color: AppColors.accent,
              ),
              DesktopStatChip(
                label: localizations?.notifications ?? 'Notifications',
                value: settingsProvider.notificationsEnabled
                    ? context.tr('On')
                    : context.tr('Off'),
                icon: Icons.notifications_outlined,
                color: settingsProvider.notificationsEnabled
                    ? AppColors.success
                    : AppColors.secondary,
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingLG),
          DesktopFormColumns(
            sections: [
              DesktopSectionCard(
                title: localizations?.languageAndRegion ?? 'Language & Region',
                icon: Icons.language,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.translate),
                    title: Text(localizations?.language ?? 'Language'),
                    subtitle: Text(languageLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguageDialog(settingsProvider.locale),
                  ),
                ],
              ),
              DesktopSectionCard(
                title: localizations?.appearance ?? 'Appearance',
                icon: Icons.brightness_6,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(localizations?.theme ?? 'Theme'),
                    subtitle: Text(themeLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showThemeDialog(settingsProvider.themeMode),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(
                      localizations?.enableNotifications ??
                          'Enable Notifications',
                    ),
                    subtitle: Text(
                      localizations?.receivePushNotifications ??
                          context.tr('Receive push notifications'),
                    ),
                    value: settingsProvider.notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingLG),
          DesktopSectionCard(
            title: localizations?.dataManagement ?? 'Data Management',
            icon: Icons.storage_outlined,
            accent: AppColors.primary,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 900 ? 2 : 1;
                  final tiles = <Widget>[
                    DesktopSettingsTile(
                      icon: Icons.cake_outlined,
                      title: localizations?.birthdayNotifications ??
                          'Birthday Notifications',
                      subtitle: localizations?.configureBirthdayNotifications ??
                          context.tr('Configure birthday notification settings'),
                      color: AppColors.accent,
                      onTap: () {
                        if (scope != null) {
                          scope.pushDetail(
                            RouteNames.birthdayNotificationsSettings,
                            '',
                          );
                        }
                      },
                    ),
                    DesktopSettingsTile(
                      icon: Icons.upload_file,
                      title: localizations?.exportAllData ?? 'Export All Data',
                      subtitle: localizations?.exportAllDataSubtitle ??
                          context.tr('Export all data to JSON file'),
                      color: AppColors.primary,
                      onTap: _exportAllData,
                    ),
                    DesktopSettingsTile(
                      icon: Icons.file_download_outlined,
                      title: localizations?.importData ?? 'Import Data',
                      subtitle: localizations?.importDataSubtitle ??
                          context.tr('Import data from JSON file'),
                      color: AppColors.primary,
                      onTap: _importData,
                    ),
                    DesktopSettingsTile(
                      icon: Icons.people_outline,
                      title: localizations?.exportMembers ?? 'Export Members',
                      subtitle: localizations?.exportMembersSubtitle ??
                          context.tr('Export members to CSV'),
                      color: AppColors.primary,
                      onTap: _exportMembers,
                    ),
                    DesktopSettingsTile(
                      icon: Icons.sync,
                      title: localizations?.syncUsersMembers ??
                          'Sync Users & Members',
                      subtitle: localizations?.syncUsersMembers ??
                          context.tr(
                            'Create members for all users and users for all leaders',
                          ),
                      color: AppColors.secondary,
                      onTap: _syncUsersAndMembers,
                    ),
                    DesktopSettingsTile(
                      icon: Icons.assessment_outlined,
                      title: localizations?.generateAllUsersReport ??
                          'Generate All Users Report',
                      subtitle: localizations?.generateReportComprehensive ??
                          context.tr(
                            'Generate comprehensive report for all users',
                          ),
                      color: AppColors.info,
                      onTap: _generateAllUsersReport,
                    ),
                    if (_isAdmin)
                      DesktopSettingsTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: localizations?.leaderAccessManagement ??
                            'Leader Access Management',
                        subtitle: localizations?.defineFeatureAccess ??
                            context.tr('Define feature access for each leader'),
                        color: AppColors.warning,
                        onTap: () {
                          scope?.pushDetail(RouteNames.leaderAccess, '');
                        },
                      ),
                    if (_isAdmin)
                      DesktopSettingsTile(
                        icon: Icons.person_add_alt_1_outlined,
                        title: context.tr('Member Accounts'),
                        subtitle: context.tr(
                          'Create login accounts for members and manage their access',
                        ),
                        color: AppColors.success,
                        onTap: () {
                          scope?.pushDetail(RouteNames.memberAccounts, '');
                        },
                      ),
                  ];

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: AppDimensions.spacingMD,
                      crossAxisSpacing: AppDimensions.spacingMD,
                      childAspectRatio: crossAxisCount == 2 ? 2.8 : 2.4,
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (context, index) => tiles[index],
                  );
                },
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          DesktopFormColumns(
            sections: [
              DesktopSectionCard(
                title: localizations?.account ?? 'Account',
                icon: Icons.person_outline,
                accent: AppColors.warning,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: Text(localizations?.currentUser ?? 'Current User'),
                    subtitle: Text(
                      SupabaseService.currentUser?.email ??
                          (localizations?.notLoggedIn ?? 'Not logged in'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout, color: AppColors.error),
                    title: Text(
                      localizations?.logout ?? 'Logout',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: Text(
                      localizations?.signOutAccount ??
                          context.tr('Sign out of your account'),
                    ),
                    onTap: _handleLogout,
                  ),
                ],
              ),
              DesktopSectionCard(
                title: localizations?.about ?? 'About',
                icon: Icons.info_outline,
                accent: AppColors.info,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_outlined),
                    title: Text(localizations?.appVersion ?? 'App Version'),
                    subtitle: const Text('1.0.0'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
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
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale>(
              title: Text(context.tr('English')),
              value: Locale('en'),
              groupValue: currentLocale ?? Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: Text(context.tr('Español')),
              value: Locale('es'),
              groupValue: currentLocale ?? Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: Text(context.tr('Français')),
              value: Locale('fr'),
              groupValue: currentLocale ?? Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _changeLanguage(selected);
    }
  }

  Future<void> _showThemeDialog(ThemeMode currentThemeMode) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Select Theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text(context.tr('Light')),
              value: ThemeMode.light,
              groupValue: currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: Text(context.tr('Dark')),
              value: ThemeMode.dark,
              groupValue: currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<ThemeMode>(
              title: Text(context.tr('System Default')),
              value: ThemeMode.system,
              groupValue: currentThemeMode,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _changeThemeMode(selected);
    }
  }
}
