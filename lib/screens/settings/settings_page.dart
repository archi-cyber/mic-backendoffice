import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../config/app_config.dart';
import '../desktop/desktop_shell_scope.dart';
import '../../services/data_export_service.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../../services/data_import_service.dart';
import '../../services/user_member_sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/role_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_update_provider.dart';
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
  String _appVersionLabel = '…';

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final label = await UpdateService.getCurrentVersionLabel();
      if (mounted) setState(() => _appVersionLabel = label);
    } catch (_) {
      if (mounted) setState(() => _appVersionLabel = AppConfig.appVersion);
    }
  }

  Future<void> _checkForUpdates() async {
    if (!PlatformCapabilities.supportsAppUpdates) return;
    final updateProvider = context.read<AppUpdateProvider>();
    if (updateProvider.isBusy || updateProvider.showsProgressUi) return;

    try {
      final update = await updateProvider.checkForUpdate(force: true);
      if (!mounted) return;
      if (update != null) {
        await UpdateDialog.show(context, update);
      } else if (updateProvider.phase != AppUpdatePhase.error) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.translate('You are on the latest version.') ??
                  'You are on the latest version.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (updateProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'Update failed: {error}',
                {'error': updateProvider.errorMessage!},
              ),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Update failed: {error}', {'error': '$e'}),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _updateStatusLabel(BuildContext context, AppUpdateProvider updates) {
    switch (updates.phase) {
      case AppUpdatePhase.checking:
        return context.tr('Checking for updates...');
      case AppUpdatePhase.downloading:
        final pct = ((updates.progress ?? 0) * 100).round();
        return context.tr('Downloading… {percent}%', {
          'percent': '$pct',
        });
      case AppUpdatePhase.awaitingInstallPermission:
        return context.tr(
          'Allow installing apps from SysteMIC, then return to finish the update.',
        );
      case AppUpdatePhase.installing:
        return context.tr('Installing update...');
      case AppUpdatePhase.completed:
        return context.tr(
          'Installer opened. Follow the prompts to finish.',
        );
      case AppUpdatePhase.error:
        return context.tr(
          'Update failed: {error}',
          {'error': updates.errorMessage ?? ''},
        );
      case AppUpdatePhase.idle:
        return context.tr('Download the latest release');
    }
  }

  Widget _buildUpdateProgressSection(BuildContext context) {
    return Consumer<AppUpdateProvider>(
      builder: (context, updates, _) {
        if (!updates.showsProgressUi &&
            updates.phase != AppUpdatePhase.error &&
            updates.phase != AppUpdatePhase.completed) {
          return const SizedBox.shrink();
        }

        final isError = updates.phase == AppUpdatePhase.error;
        final needsPermission =
            updates.phase == AppUpdatePhase.awaitingInstallPermission;

        return Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.paddingMD,
            right: AppDimensions.paddingMD,
            bottom: AppDimensions.spacingSM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (updates.phase == AppUpdatePhase.downloading)
                LinearProgressIndicator(
                  value: updates.progress,
                  minHeight: 4,
                  color: AppColors.primary,
                )
              else if (updates.showsProgressUi)
                const LinearProgressIndicator(
                  minHeight: 4,
                  color: AppColors.primary,
                ),
              const SizedBox(height: 8),
              Text(
                _updateStatusLabel(context, updates),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isError ? AppColors.error : null,
                ),
              ),
              if (needsPermission) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => updates.openInstallPermissionSettings(),
                    icon: const Icon(Icons.settings, size: 18),
                    label: Text(context.tr('Open install settings')),
                  ),
                ),
              ],
              if (isError || updates.phase == AppUpdatePhase.completed) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: updates.clearError,
                    child: Text(context.tr('Dismiss')),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
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
                    settingsProvider.locale.languageCode == 'fr'
                        ? 'Français'
                        : settingsProvider.locale.languageCode == 'es'
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
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info),
                      title: Text(localizations?.appVersion ?? 'App Version'),
                      subtitle: Text(_appVersionLabel),
                    ),
                    if (PlatformCapabilities.supportsAppUpdates) ...[
                      Consumer<AppUpdateProvider>(
                        builder: (context, updates, _) {
                          final busy =
                              updates.isBusy || updates.showsProgressUi;
                          return ListTile(
                            leading: busy
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.system_update),
                            title: Text(context.tr('Check for updates')),
                            subtitle: Text(
                              busy
                                  ? _updateStatusLabel(context, updates)
                                  : context.tr('Download the latest release'),
                            ),
                            onTap: busy ? null : _checkForUpdates,
                          );
                        },
                      ),
                      _buildUpdateProgressSection(context),
                    ],
                  ],
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
    final languageLabel = settingsProvider.locale.languageCode == 'fr'
        ? 'Français'
        : settingsProvider.locale.languageCode == 'es'
        ? 'Español'
        : 'English';
    final themeLabel = settingsProvider.themeMode == ThemeMode.light
        ? context.tr('Light')
        : settingsProvider.themeMode == ThemeMode.dark
        ? context.tr('Dark')
        : context.tr('System Default');
    final email =
        SupabaseService.currentUser?.email ?? context.tr('Not logged in');

    return DesktopPageShell(
      maxWidth: 960,
      padding: EdgeInsets.fromLTRB(
        AppDimensions.paddingLG,
        AppDimensions.paddingMD,
        AppDimensions.paddingLG,
        AppDimensions.paddingLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations?.settings ?? context.tr('Settings'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('Choose how SysteMIC looks and speaks.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  border: Border.all(
                    color: context.mic.border.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 760;
              final preferences = _buildDesktopCompactSection(
                context,
                title: context.tr('Preferences'),
                icon: Icons.tune_outlined,
                accent: AppColors.primary,
                children: [
                  _desktopSettingTile(
                    context,
                    icon: Icons.translate,
                    color: AppColors.primary,
                    title: context.tr('Language'),
                    subtitle: languageLabel,
                    onTap: () =>
                        _showLanguageDialog(settingsProvider.locale),
                  ),
                  _desktopSettingTile(
                    context,
                    icon: Icons.palette_outlined,
                    color: AppColors.accent,
                    title: context.tr('Theme'),
                    subtitle: themeLabel,
                    onTap: () =>
                        _showThemeDialog(settingsProvider.themeMode),
                  ),
                  _desktopSettingTile(
                    context,
                    icon: Icons.notifications_outlined,
                    color: settingsProvider.notificationsEnabled
                        ? AppColors.success
                        : AppColors.secondary,
                    title: localizations?.enableNotifications ??
                        context.tr('Enable Notifications'),
                    subtitle: settingsProvider.notificationsEnabled
                        ? context.tr('On')
                        : context.tr('Off'),
                    onTap: () => _toggleNotifications(
                      !settingsProvider.notificationsEnabled,
                    ),
                    trailing: Switch.adaptive(
                      value: settingsProvider.notificationsEnabled,
                      onChanged: _toggleNotifications,
                    ),
                  ),
                ],
              );
              final account = _buildDesktopCompactSection(
                context,
                title: context.tr('Account'),
                icon: Icons.person_outline,
                accent: AppColors.error,
                children: [
                  _desktopSettingTile(
                    context,
                    icon: Icons.logout,
                    color: AppColors.error,
                    title: localizations?.logout ?? context.tr('Logout'),
                    subtitle: context.tr('Sign out of your account'),
                    onTap: _handleLogout,
                    titleColor: AppColors.error,
                  ),
                  _desktopSettingTile(
                    context,
                    icon: Icons.info_outline,
                    color: context.mic.textSecondary,
                    title: context.tr('App Version'),
                    subtitle: _appVersionLabel,
                  ),
                  if (PlatformCapabilities.supportsAppUpdates)
                    Consumer<AppUpdateProvider>(
                      builder: (context, updates, _) {
                        final busy =
                            updates.isBusy || updates.showsProgressUi;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _desktopSettingTile(
                              context,
                              icon: Icons.system_update,
                              color: AppColors.info,
                              title: context.tr('Check for updates'),
                              subtitle: busy
                                  ? _updateStatusLabel(context, updates)
                                  : context.tr('Download the latest release'),
                              onTap: busy ? null : _checkForUpdates,
                              trailing: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            if (updates.showsProgressUi ||
                                updates.phase == AppUpdatePhase.error ||
                                updates.phase == AppUpdatePhase.completed)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (updates.phase ==
                                        AppUpdatePhase.downloading)
                                      LinearProgressIndicator(
                                        value: updates.progress,
                                        minHeight: 3,
                                        color: AppColors.primary,
                                      )
                                    else if (updates.showsProgressUi)
                                      const LinearProgressIndicator(
                                        minHeight: 3,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              );

              if (!useTwoColumns) {
                return Column(
                  children: [
                    preferences,
                    SizedBox(height: AppDimensions.spacingMD),
                    account,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: preferences),
                  SizedBox(width: AppDimensions.spacingMD),
                  Expanded(child: account),
                ],
              );
            },
          ),
          SizedBox(height: AppDimensions.spacingMD),
          _buildDesktopCompactSection(
            context,
            title: context.tr('Workspace tools'),
            icon: Icons.handyman_outlined,
            accent: AppColors.info,
            children: [
              _desktopSettingTile(
                context,
                icon: Icons.cake_outlined,
                color: AppColors.accent,
                title: localizations?.birthdayNotifications ??
                    context.tr('Birthday Notifications'),
                subtitle:
                    context.tr('Configure birthday notification settings'),
                onTap: () {
                  scope?.pushDetail(
                    RouteNames.birthdayNotificationsSettings,
                    '',
                  );
                },
              ),
              _desktopSettingTile(
                context,
                icon: Icons.upload_file_outlined,
                color: AppColors.primary,
                title: localizations?.exportAllData ??
                    context.tr('Export All Data'),
                subtitle: context.tr('Export all data to JSON file'),
                onTap: _exportAllData,
              ),
              _desktopSettingTile(
                context,
                icon: Icons.file_download_outlined,
                color: AppColors.primary,
                title: localizations?.importData ?? context.tr('Import Data'),
                subtitle: context.tr('Import data from JSON file'),
                onTap: _importData,
              ),
              _desktopSettingTile(
                context,
                icon: Icons.people_outline,
                color: AppColors.primary,
                title: localizations?.exportMembers ??
                    context.tr('Export Members'),
                subtitle: context.tr('Export members to CSV'),
                onTap: _exportMembers,
              ),
              _desktopSettingTile(
                context,
                icon: Icons.sync,
                color: AppColors.secondary,
                title: localizations?.syncUsersMembers ??
                    context.tr('Sync Users & Members'),
                subtitle: context.tr(
                  'Create members for all users and users for all leaders',
                ),
                onTap: _syncUsersAndMembers,
              ),
              _desktopSettingTile(
                context,
                icon: Icons.assessment_outlined,
                color: AppColors.info,
                title: localizations?.generateAllUsersReport ??
                    context.tr('Generate All Users Report'),
                subtitle: context.tr(
                  'Generate comprehensive report for all users',
                ),
                onTap: _generateAllUsersReport,
              ),
            ],
          ),
          if (_isAdmin) ...[
            SizedBox(height: AppDimensions.spacingMD),
            _buildDesktopCompactSection(
              context,
              title: context.tr('Admin'),
              icon: Icons.admin_panel_settings_outlined,
              accent: AppColors.warning,
              children: [
                _desktopSettingTile(
                  context,
                  icon: Icons.security_outlined,
                  color: AppColors.warning,
                  title: localizations?.leaderAccessManagement ??
                      context.tr('Leader Access Management'),
                  subtitle:
                      context.tr('Define feature access for each leader'),
                  onTap: () =>
                      scope?.pushDetail(RouteNames.leaderAccess, ''),
                ),
                _desktopSettingTile(
                  context,
                  icon: Icons.person_add_alt_1_outlined,
                  color: AppColors.success,
                  title: context.tr('Member Accounts'),
                  subtitle: context.tr(
                    'Create login accounts for members and manage their access',
                  ),
                  onTap: () =>
                      scope?.pushDetail(RouteNames.memberAccounts, ''),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCompactSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        side: BorderSide(color: context.mic.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.mic.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _desktopSettingTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.mic.textTertiary,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
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
