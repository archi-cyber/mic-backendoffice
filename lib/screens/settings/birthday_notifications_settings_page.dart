import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../services/birthday_notification_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../widgets/desktop/desktop_ui.dart';

/// Settings page for birthday notification configuration
class BirthdayNotificationsSettingsPage extends StatefulWidget {
  /// When provided (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final VoidCallback? onClose;

  BirthdayNotificationsSettingsPage({super.key, this.onClose});

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

  Widget _buildTargetOptions() {
    return Column(
      children: [
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
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    return DesktopPageShell(
      isLoading: _isLoading,
      maxWidth: kDesktopNarrowMaxWidth,
      banner: DesktopHeroBanner(
        title: context.tr('Birthday Notifications'),
        subtitle: context.tr('Configure birthday notification settings'),
        icon: Icons.cake_outlined,
        accent: AppColors.accent,
        trailing: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopSectionCard(
            title: context.tr('Notification Target'),
            icon: Icons.notifications_active_outlined,
            accent: AppColors.accent,
            children: [_buildTargetOptions()],
          ),
          SizedBox(height: AppDimensions.spacingMD),
          DesktopSectionCard(
            title: context.tr('Note'),
            icon: Icons.info_outline,
            accent: AppColors.accent,
            children: [
              Text(
                'Individual members can opt-out of birthday notifications '
                'regardless of this setting. This setting controls the default '
                'behavior for all users.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingLG),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save, size: 20),
              label: Text(context.tr('Save Settings')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopEmbedded(
      context,
      inShell: widget.onClose != null,
    );

    if (_isLoading && !isDesktop) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(title: Text(context.tr('Birthday Notifications'))),
      body: isDesktop
          ? _buildDesktopBody(context)
          : ListView(
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
                        _buildTargetOptions(),
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
                        Text(
                          'Note',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                    minimumSize: Size(
                      double.infinity,
                      AppDimensions.buttonHeightLG,
                    ),
                  ),
                  child: Text(context.tr('Save Settings')),
                ),
              ],
            ),
    );
  }
}
