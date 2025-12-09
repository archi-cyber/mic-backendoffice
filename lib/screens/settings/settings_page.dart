import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../services/settings_service.dart';
import '../../services/data_export_service.dart';
import '../../services/data_import_service.dart';
import '../../services/supabase_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
          'This will export all members, departments, classes, events, and tasks to a JSON file. Continue?',
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
      await DataExportService.exportAndShareAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully'),
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
      await DataExportService.exportAndShareAllUsersReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
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
                _currentLocale?.languageCode == 'es'
                    ? 'Spanish'
                    : _currentLocale?.languageCode == 'fr'
                    ? 'French'
                    : 'English',
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

          // App Info
          _buildSectionHeader('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Current User'),
                  subtitle: Text(
                    SupabaseService.currentUser?.email ?? 'Not logged in',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
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
              title: const Text('Spanish'),
              value: const Locale('es'),
              groupValue: _currentLocale ?? const Locale('en'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<Locale>(
              title: const Text('French'),
              value: const Locale('fr'),
              groupValue: _currentLocale ?? const Locale('en'),
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
      await _changeLanguage(selected);
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
