import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Annonces.
///
/// Conservé comme classe distincte : les écrans l'importent sous ce nom, et le
/// fusionner ailleurs aurait imposé de modifier chacun d'eux sans bénéfice.
class ChatService {
  static ApiClient get _client => AuthService.client;

  static Future<List<Map<String, dynamic>>> getAnnouncements({
    int? limit,
    int? offset,
    String? departmentId,
    bool? isGlobal,
  }) {
    final effectiveLimit = limit ?? 50;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/announcements', query: {
      'page': page,
      'limit': effectiveLimit,
      if (departmentId != null) 'department_id': departmentId,
      if (isGlobal != null) 'is_global': isGlobal,
    });
  }

  static Future<Map<String, dynamic>> getAnnouncementById(String id) =>
      _client.getOne('/announcements/$id');

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