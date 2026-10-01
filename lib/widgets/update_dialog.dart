import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimensions.dart';
import '../core/localization/app_localizations.dart';
import '../core/navigation/app_navigator.dart';
import '../models/app_update_info.dart';
import '../providers/app_update_provider.dart';
import '../screens/desktop/desktop_shell.dart';
import '../services/update_service.dart';

/// Presents available updates without blocking the UI on desktop.
/// On Android, downloads and installs via [AppUpdateProvider] (background-safe).
class UpdateDialog {
  UpdateDialog._();

  static OverlayEntry? _entry;
  static String? _shownVersion;

  static Future<void> showIfAvailable(
    BuildContext? context, {
    bool forceCheck = false,
  }) async {
    final update = await UpdateService.checkForUpdate(force: forceCheck);
    if (update == null) return;

    // Prefer the root navigator context so Overlay/Dialog always resolve
    // (lifecycle wrapper sits above MaterialApp and has no Overlay).
    final showContext =
        AppNavigator.rootNavigatorKey.currentContext ?? context;
    if (showContext == null || !showContext.mounted) {
      debugPrint('Update available but no navigator context to show toast');
      return;
    }
    await show(showContext, update);
  }

  static Future<void> show(BuildContext context, AppUpdateInfo update) async {
    if (!context.mounted) return;

    // Android installs via app-wide provider so progress survives navigation.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _autoInstall(context, update);
      return;
    }

    _showToast(context, update);
  }

  static BuildContext? _overlayContext(BuildContext context) {
    return AppNavigator.rootNavigatorKey.currentContext ?? context;
  }

  static Future<void> _autoInstall(
    BuildContext context,
    AppUpdateInfo update,
  ) async {
    final provider = Provider.of<AppUpdateProvider>(context, listen: false);
    if (provider.isBusy || provider.showsProgressUi) return;

    unawaited(provider.startUpdate(update));

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Downloading update ({version})...',
            {'version': update.displayVersion},
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showToast(BuildContext context, AppUpdateInfo update) {
    final versionKey = update.displayVersion;
    if (_entry != null && _shownVersion == versionKey) return;

    dismiss();

    final hostContext = _overlayContext(context);
    if (hostContext == null || !hostContext.mounted) {
      debugPrint('Update toast skipped: no overlay host context');
      return;
    }

    final overlay = Overlay.maybeOf(hostContext, rootOverlay: true);
    if (overlay == null) {
      debugPrint('Update toast skipped: Overlay not found');
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final width = MediaQuery.sizeOf(overlayContext).width;
        final bottomInset = MediaQuery.paddingOf(overlayContext).bottom;
        final left = width >= kDesktopBreakpoint ? 20.0 : 12.0;

        return Positioned(
          left: left,
          bottom: 20 + bottomInset,
          child: _UpdateToastCard(
            update: update,
            onDismiss: () {
              if (!update.forceUpdate) {
                unawaited(UpdateService.skipVersion(update));
              }
              dismiss();
            },
            onClose: dismiss,
          ),
        );
      },
    );

    _entry = entry;
    _shownVersion = versionKey;
    overlay.insert(entry);
  }

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _shownVersion = null;
  }
}

class _UpdateToastCard extends StatefulWidget {
  final AppUpdateInfo update;
  final VoidCallback onDismiss;
  final VoidCallback onClose;

  const _UpdateToastCard({
    required this.update,
    required this.onDismiss,
    required this.onClose,
  });

  @override
  State<_UpdateToastCard> createState() => _UpdateToastCardState();
}

class _UpdateToastCardState extends State<_UpdateToastCard> {
  bool _isWorking = false;
  double? _progress;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _isWorking = true;
      _error = null;
      _progress = 0;
    });

    try {
      await UpdateService.applyUpdate(
        widget.update,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );
      if (mounted) widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = widget.update.releaseNotes;
    final isWeb = widget.update.platformKey == 'web';
    final canDismiss = !widget.update.forceUpdate && !_isWorking;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      color: theme.colorScheme.surface,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.system_update_alt,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            'Update {version}',
                            {'version': widget.update.displayVersion},
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (notes != null && notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canDismiss)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: context.tr('Later'),
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              if (_isWorking) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 3,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  isWeb
                      ? context.tr('Refreshing...')
                      : context.tr('Downloading...'),
                  style: theme.textTheme.labelSmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  context.tr('Update failed'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              if (!_isWorking) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _startUpdate,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      isWeb
                          ? context.tr('Refresh')
                          : context.tr('Update'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
