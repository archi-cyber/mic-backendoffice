import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/birthday_notification_service.dart';
import '../../core/localization/app_localizations.dart';

/// Settings page for birthday notification configuration
class BirthdayNotificationsSettingsPage extends StatefulWidget {
  BirthdayNotificationsSettingsPage({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Error loading config: $e'))),
        );
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
          SnackBar(
            content: Text(context.tr('Settings saved successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Error saving config: $e')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Birthday Notifications'))),
      body: ListView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Target',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  RadioListTile<String>(
                    title: Text(context.tr('All Church App Users')),
                    subtitle: Text(context.tr('Default: All active members')),
                    value: 'all',
                    groupValue: _target,
                    onChanged: (value) {
                      setState(() => _target = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(context.tr('Leaders Only')),
                    subtitle: Text(
                      context.tr('Only department leaders and admins'),
                    ),
                    value: 'leaders_only',
                    groupValue: _target,
                    onChanged: (value) {
                      setState(() => _target = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(context.tr('Opt-Out (No Notifications)')),
                    subtitle: Text(context.tr('Users can opt-in individually')),
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
          SizedBox(height: AppDimensions.spacingMD),
          Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: AppDimensions.spacingSM),
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
          SizedBox(height: AppDimensions.spacingXL),
          ElevatedButton(
            onPressed: _saveConfig,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, AppDimensions.buttonHeightLG),
            ),
            child: Text(context.tr('Save Settings')),
          ),
        ],
      ),
    );
  }
}
