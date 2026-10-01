import 'package:flutter/material.dart';
import '../../chat/chat_page.dart';

/// Desktop/Web chat. Uses the same messaging [ChatPage] as mobile.
class DesktopChatPage extends StatelessWidget {
  DesktopChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChatPage(hideAppBarAndBottomNav: true);
  }
}
