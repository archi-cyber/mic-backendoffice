import '../config/app_config.dart';
import 'chat_service.dart';
import 'supabase_service.dart';

/// Jitsi-based video rooms for chat conversations.
class ChatVideoService {
  static const String videoCallTitle = 'Video call';
  static const Duration liveCallWindow = Duration(hours: 2);
  static const String _jitsiHost = 'meet.jit.si';

  static bool isVideoCall(Map<String, dynamic> announcement) {
    return (announcement['title']?.toString() ?? '') == videoCallTitle;
  }

  static bool isLiveVideoCall(Map<String, dynamic> announcement) {
    if (!isVideoCall(announcement)) return false;
    final createdAt = DateTime.tryParse(
      announcement['created_at']?.toString() ?? '',
    )?.toLocal();
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt) <= liveCallWindow;
  }

  /// Nom de salle stable par conversation, préfixé par l'hôte de l'API pour
  /// que deux installations distinctes ne partagent pas les mêmes salles.
  static String roomNameForChannel(String channelId) {
    final host = Uri.parse(AppConfig.apiBaseUrl).host.split('.').first;
    final project = host.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final slug = channelId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final safeSlug = slug.isEmpty ? 'chat' : slug;
    return 'SysteMIC$project$safeSlug';
  }

  static String meetUrl({
    required String roomName,
    String? displayName,
  }) {
    final encodedName = Uri.encodeComponent(displayName ?? 'Member');
    return 'https://$_jitsiHost/$roomName#userInfo.displayName="$encodedName"';
  }

  /// Nom affiché dans la salle : celui de la fiche membre, sinon la partie
  /// locale de l'e-mail. Lu depuis le profil chargé à la connexion.
  static Future<String> currentDisplayName() async {
    final user = SupabaseService.currentUser;
    if (user == null) return 'Member';

    final name =
        '${user.userMetadata['first_name'] ?? ''} ${user.userMetadata['last_name'] ?? ''}'
            .trim();
    if (name.isNotEmpty) return name;

    if (user.email.isNotEmpty) return user.email.split('@').first;
    return 'Member';
  }

  /// Posts a video-call message and notifies the conversation, unless a call
  /// is already live in this channel.
  static Future<void> announceCallIfNeeded({
    required String channelName,
    required bool isEveryone,
    String? departmentId,
    List<String>? targetMemberIds,
    required bool alreadyLive,
  }) async {
    if (alreadyLive) return;
    await ChatService.createAnnouncement(
      title: videoCallTitle,
      message:
          'A video call started in $channelName. Tap Join video call to join.',
      isGlobal: isEveryone,
      departmentId: departmentId,
      targetMemberIds: targetMemberIds,
    );
  }
}
