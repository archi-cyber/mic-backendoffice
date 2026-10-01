import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// In-app Jitsi room for Android and iOS.
class ChatVideoEmbed extends StatefulWidget {
  const ChatVideoEmbed({super.key, required this.url});

  final String url;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<ChatVideoEmbed> createState() => _ChatVideoEmbedState();
}

class _ChatVideoEmbedState extends State<ChatVideoEmbed> {
  late final WebViewController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1410))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_ready)
          const ColoredBox(
            color: Color(0xFF1A1410),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
