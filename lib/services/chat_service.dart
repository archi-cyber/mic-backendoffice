import '../core/api/api_client.dart';
import '../core/api/realtime_client.dart';
import 'auth_service.dart';

/// Abonnement aux changements d'annonces, à annuler avec [cancel].
class AnnouncementSubscription {
  AnnouncementSubscription._(this._realtime, this._handler);

  final RealtimeClient? _realtime;
  final void Function(dynamic) _handler;

  static const _events = [
    RealtimeEvents.announcementNew,
    RealtimeEvents.announcementUpdated,
    RealtimeEvents.announcementDeleted,
  ];

  void cancel() {
    for (final event in _events) {
      _realtime?.off(event, _handler);
    }
  }
}

/// Annonces.
///
/// Conservé comme classe distincte : les écrans l'importent sous ce nom, et le
/// fusionner ailleurs aurait imposé de modifier chacun d'eux sans bénéfice.
class ChatService {
  static ApiClient get _client => AuthService.client;

  /// Database title is required; use the first line of a chat message.
  static String titleFromMessage(String message) {
    final firstLine = message.trim().split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.isEmpty) return 'Message';
    if (firstLine.length <= 80) return firstLine;
    return '${firstLine.substring(0, 80)}…';
  }

  static Future<List<Map<String, dynamic>>> getAnnouncements({
    int? limit,
    int? offset,
    String? departmentId,
    bool? isGlobal,
  }) async {
    final effectiveLimit = limit ?? 50;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    final items = await _client.getList('/announcements', query: {
      'page': page,
      'limit': effectiveLimit,
      if (departmentId != null) 'department_id': departmentId,
      if (isGlobal != null) 'is_global': isGlobal,
    });
    return items.map(_withCreator).toList();
  }

  static Future<Map<String, dynamic>> getAnnouncementById(String id) async =>
      _withCreator(await _client.getOne('/announcements/$id'));

  /// Expose l'auteur sous la forme lue par la messagerie
  /// (`users: {id, email, members: {first_name, last_name}}`).
  static Map<String, dynamic> _withCreator(Map<String, dynamic> announcement) {
    final author = announcement['author'];
    if (author is Map && announcement['users'] == null) {
      announcement['users'] = {
        'id': author['id'],
        'email': author['email'],
        'members': author['member'],
      };
    }
    return announcement;
  }

  /// Live updates for the messaging view.
  static AnnouncementSubscription subscribeToAnnouncements(
    void Function() onChanged,
  ) {
    final realtime = RealtimeClient.current;
    void handler(dynamic _) => onChanged();
    for (final event in AnnouncementSubscription._events) {
      realtime?.on(event, handler);
    }
    return AnnouncementSubscription._(realtime, handler);
  }

  /// Publie une annonce.
  ///
  /// Une annonce non globale doit viser un département ou une liste de
  /// membres, faute de quoi le serveur renvoie
  /// `ANNOUNCEMENT_AUDIENCE_REQUIRED` — sans destinataire, elle
  /// n'apparaîtrait nulle part.
  static Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String message,
    bool isGlobal = true,
    String? departmentId,
    List<String>? targetMemberIds,
  }) async {
    final data = await _client.post('/announcements', body: {
      'title': title,
      'message': message,
      'is_global': isGlobal,
      if (departmentId != null) 'department_id': departmentId,
      if (targetMemberIds != null) 'target_member_ids': targetMemberIds,
    });
    return (data as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> updateAnnouncement({
    required String announcementId,
    required Map<String, dynamic> updates,
  }) async {
    final data = await _client.patch('/announcements/$announcementId', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteAnnouncement(String announcementId) async {
    await _client.delete('/announcements/$announcementId');
  }
}