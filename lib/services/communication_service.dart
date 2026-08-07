import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Annonces et notifications.
///
/// Les deux sont regroupés parce qu'ils sont liés : publier une annonce génère
/// une notification pour chaque destinataire.
class CommunicationService {

  static ApiClient get _client => AuthService.client;

  // ---------------------------------------------------------------------------
  // Annonces
  // ---------------------------------------------------------------------------

  /// Annonces visibles par l'utilisateur connecté.
  ///
  /// Le serveur cumule trois cas : les annonces globales, celles des
  /// départements de l'utilisateur, et celles qui le visent nommément. Aucun
  /// filtrage n'est à faire côté client.
  static Future<List<Map<String, dynamic>>> getAnnouncements({
    int page = 1,
    int limit = 20,
    String? search,
    String? departmentId,
    bool? isGlobal,
  }) {
    return _client.getList('/announcements', query: {
        'page': page,
        'limit': limit,
        'search': search,
        'departmentId': departmentId,
        'isGlobal': isGlobal,
      });
  }

  static Future<Map<String, dynamic>> getAnnouncementById(String id) async {
    final data = await _client.get('/announcements/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// Publie une annonce.
  ///
  /// Trois portées possibles :
  ///   - globale : `isGlobal: true` ;
  ///   - départementale : `departmentId` renseigné ;
  ///   - ciblée : `targetMemberIds` renseigné.
  ///
  /// Une annonce non globale doit avoir un public, faute de quoi le serveur
  /// renvoie `ANNOUNCEMENT_AUDIENCE_REQUIRED` — sans destinataire, elle
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
      'isGlobal': isGlobal,
      if (departmentId != null) 'departmentId': departmentId,
      if (targetMemberIds != null) 'targetMemberIds': targetMemberIds,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Modifie une annonce. Réservé à son auteur ou à un administrateur.
  static Future<Map<String, dynamic>> updateAnnouncement(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await _client.patch('/announcements/$id', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteAnnouncement(String id) async {
    await _client.delete('/announcements/$id');
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// Mes notifications.
  ///
  /// Le filtrage porte sur le membre lié au compte connecté, déduit du jeton :
  /// aucun identifiant n'est à fournir, et aucun ne serait accepté. Les
  /// notifications destinées à toute l'assemblée sont incluses.
  ///
  /// Le compteur `unreadCount` figure dans `meta`.
  static Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 30,
    bool? isRead,
    String? type,
  }) {
    return _client.getList('/notifications', query: {'page': page, 'limit': limit, 'isRead': isRead, 'type': type});
  }

  /// Nombre de notifications non lues — route légère, pour le badge.
  static Future<int> getUnreadCount() async {
    final data = await _client.get('/notifications/unread-count');
    return (data as Map)['count'] as int? ?? 0;
  }

  /// Marque des notifications comme lues.
  ///
  /// Sans liste d'identifiants, toutes le sont.
  static Future<Map<String, dynamic>> markAsRead({
    List<String>? notificationIds,
  }) async {
    final data = await _client.post(
      '/notifications/read',
      body: {if (notificationIds != null) 'notificationIds': notificationIds},
    );
    return (data as Map).cast<String, dynamic>();
  }

  static Future<void> deleteNotification(String id) async {
    await _client.delete('/notifications/$id');
  }
}