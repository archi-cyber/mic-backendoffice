import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/mic_theme.dart';
import '../../services/chat_video_service.dart';
import 'chat_video_embed.dart'
    if (dart.library.io) 'chat_video_embed_io.dart';

/// Full-screen video call for a chat conversation.
class ChatVideoCallPage extends StatefulWidget {
  const ChatVideoCallPage({
    super.key,
    required this.roomName,
    required this.roomTitle,
    required this.displayName,
    this.onClose,
  });

  final String roomName;
  final String roomTitle;
  final String displayName;
  final VoidCallback? onClose;

  @override
  State<ChatVideoCallPage> createState() => _ChatVideoCallPageState();
}

class _ChatVideoCallPageState extends State<ChatVideoCallPage> {
  bool _browserLaunchAttempted = false;

  String get _meetUrl => ChatVideoService.meetUrl(
        roomName: widget.roomName,
        displayName: widget.displayName,
      );

  @override
  void initState() {
    super.initState();
    if (!ChatVideoEmbed.supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_browserLaunchAttempted) {
          _browserLaunchAttempted = true;
          unawaited(_openInBrowser());
        }
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(_meetUrl);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Could not start video call')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      appBar: AppBar(
        leading: widget.onClose != null
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.tr('Cancel'),
                onPressed: widget.onClose,
              )
            : null,
        title: Text(widget.roomTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: context.tr('Open in browser'),
            onPressed: _openInBrowser,
          ),
        ],
      ),
      body: ChatVideoEmbed.supported
          ? ChatVideoEmbed(url: _meetUrl)
          : _BrowserFallback(
              roomTitle: widget.roomTitle,
              onOpen: _openInBrowser,
            ),
    );
  }
}

class _BrowserFallback extends StatelessWidget {
  const _BrowserFallback({
    required this.roomTitle,
    required this.onOpen,
  });

  final String roomTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.paddingLG),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: AppColors.primary,
              ),
              SizedBox(height: AppDimensions.spacingMD),
              Text(
                context.tr('Start video call'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.mic.appBarForeground,
                    ),
              ),
              SizedBox(height: AppDimensions.spacingSM),
              Text(
                roomTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.mic.textSecondary,
                    ),
              ),
              SizedBox(height: AppDimensions.spacingLG),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.videocam),
                label: Text(context.tr('Join video call')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
