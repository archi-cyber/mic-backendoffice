import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/birthday_notification_service.dart';

/// Settings page for birthday notification configuration
class BirthdayNotificationsSettingsPage extends StatefulWidget {
  const BirthdayNotificationsSettingsPage({super.key});

  @override
  State<BirthdayNotificationsSettingsPage> createState() =>
      _BirthdayNotificationsSettingsPageState();
}

class _BirthdayNotificationsSettingsPageState
    extends State<BirthdayNotificationsSettingsPage> {
  String _target = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await BirthdayNotificationService.getNotificationConfig();
      setState(() {
        _target = config['target'] as String? ?? 'all';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading config: $e')));
      }
    }
  }

  Future<void> _saveConfig() async {
    try {
      await BirthdayNotificationService.updateNotificationConfig(
        target: _target,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving config: $e'),
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
      appBar: AppBar(title: const Text('Birthday Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Target',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  RadioListTile<String>(
                    title: const Text('All Church App Users'),
                    subtitle: const Text('Default: All active members'),
                    value: 'all',
                    groupValue: _target,
                    onChanged: (value) {
                      setState(() => _target = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Leaders Only'),
                    subtitle: const Text('Only department leaders and admins'),
                    value: 'leaders_only',
                    groupValue: _target,
                    onChanged: (value) {
                      setState(() => _target = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Opt-Out (No Notifications)'),
                    subtitle: const Text('Users can opt-in individually'),
                    value: 'opt_out',
                    groupValue: _target,
                    onChanged: (value) {
                      setState(() => _target = value!);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMD),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppDimensions.spacingSM),
                  Text(
                    'Individual members can opt-out of birthday notifications '
                    'regardless of this setting. This setting controls the default '
                    'behavior for all users.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXL),
          ElevatedButton(
            onPressed: _saveConfig,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                AppDimensions.buttonHeightLG,
              ),
            ),
            child: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
