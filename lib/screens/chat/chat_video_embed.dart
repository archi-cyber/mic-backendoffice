import 'package:flutter/widgets.dart';

/// Web/desktop stub: Jitsi is opened in the system browser instead of a WebView.
class ChatVideoEmbed extends StatelessWidget {
  const ChatVideoEmbed({super.key, required this.url});

  final String url;

  static bool get supported => false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
