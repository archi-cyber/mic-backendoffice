import 'package:flutter/foundation.dart' show debugPrint;
import 'package:url_launcher/url_launcher.dart';

/// Helpers for opening WhatsApp chats from phone numbers.
class WhatsAppUtils {
  static String? phoneDigits(String? phone) {
    final raw = phone ?? '';
    if (raw.trim().isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  static String? urlFromPhone(String? phone) {
    final digits = phoneDigits(phone);
    if (digits == null) return null;
    return 'https://wa.me/$digits';
  }

  /// Opens WhatsApp for [phone]. Returns true if a handler was launched.
  static Future<bool> openChat({
    required String phone,
    String? message,
  }) async {
    final digits = phoneDigits(phone);
    if (digits == null) return false;

    final encodedMessage = message?.trim();
    final hasMessage = encodedMessage != null && encodedMessage.isNotEmpty;

    final uris = <Uri>[
      Uri.parse(
        hasMessage
            ? 'https://wa.me/$digits?text=${Uri.encodeComponent(encodedMessage)}'
            : 'https://wa.me/$digits',
      ),
      Uri.parse(
        hasMessage
            ? 'whatsapp://send?phone=$digits&text=${Uri.encodeComponent(encodedMessage)}'
            : 'whatsapp://send?phone=$digits',
      ),
    ];

    for (final uri in uris) {
      if (await _tryLaunch(uri)) return true;
    }
    return false;
  }

  /// Opens WhatsApp from an existing `https://wa.me/...` URL.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await _tryLaunch(uri)) {
      return true;
    }

    final match = RegExp(r'wa\.me/(\d+)').firstMatch(url);
    if (match != null) {
      return openChat(phone: match.group(1)!);
    }
    return false;
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (e) {
      debugPrint('[WhatsAppUtils] externalApplication failed for $uri: $e');
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[WhatsAppUtils] platformDefault failed for $uri: $e');
      return false;
    }
  }
}
