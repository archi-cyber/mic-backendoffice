import 'package:flutter/material.dart';
import '../../chat/chat_page.dart';

/// Desktop/Web chat. Uses same [ChatPage] and services.
class DesktopChatPage extends StatelessWidget {
  const DesktopChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatPage(hideAppBarAndBottomNav: true);
  }
}
