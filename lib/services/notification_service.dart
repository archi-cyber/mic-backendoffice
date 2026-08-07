import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Notifications personnelles.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Le paramètre `memberId` est accepté mais **ignoré** : le serveur déduit le
/// destinataire du jeton d'authentification. Accepter une valeur fournie par
/// le client permettrait de lire ou d'effacer les notifications d'autrui en
/// changeant un identifiant dans la requête.
///
/// Il est conservé pour ne pas casser les appels existants.
class NotificationService {
  static ApiClient get _client => AuthService.client;

  /// Notifications de l'utilisateur connecté.
  ///
  /// Inclut celles destinées à toute l'assemblée — annonces globales,
  /// anniversaires — qui n'ont pas de destinataire nommé.
  static Future<List<Map<String, dynamic>>> getNotifications({
    String? memberId,
    bool? isRead,
    String? type,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 50;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/notifications', query: {
      'page': page,
      'limit': effectiveLimit,
      if (isRead != null) 'is_read': isRead,
      if (type != null) 'type': type,
    });
  }

  /// Nombre de notifications non lues.
  ///
  /// Route légère, destinée au badge de l'interface : elle ne renvoie qu'un
  /// entier, là où charger la liste pour la compter transférerait des
  /// dizaines d'objets.
  static Future<int> getUnreadCount({String? memberId}) async {
    try {
      final data = await _client.getOne('/notifications/unread-count');
      return data['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[Notification] Compteur indisponible : $e');
      return 0;
    }
  }

  /// Marque une notification comme lue.
  static Future<void> markAsRead(String notificationId) async {
    await _client.post('/notifications/read', body: {
      'notification_ids': [notificationId],
    });
  }

  /// Marque toutes les notifications comme lues.
  static Future<void> markAllAsRead({String? memberId}) async {
    await _client.post('/notifications/read', body: <String, dynamic>{});
  }

  /// Supprime une notification.
  ///
  /// Le serveur vérifie qu'elle appartient bien à l'utilisateur : connaître un
  /// identifiant ne suffit pas à effacer la notification d'un autre.
  static Future<void> deleteNotification(String notificationId) async {
    await _client.delete('/notifications/$notificationId');
  }

  // ---------------------------------------------------------------------------
  // Émission
  // ---------------------------------------------------------------------------

  /// Crée une notification.
  ///
  /// L'émission relève désormais du serveur : il notifie automatiquement lors
  /// d'une assignation de tâche, d'une annonce ou d'un anniversaire. Cette
  /// méthode reste disponible pour les cas particuliers.
  static Future<Map<String, dynamic>> createNotification({
    required String memberId,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
  }) async {
    final data = await _client.post('/notifications', body: {
      'member_id': memberId,
      'type': type,
      'title': title,
      'message': message,
      if (relatedId != null) 'related_id': relatedId,
      if (relatedType != null) 'related_type': relatedType,
    });
    return (data as Map).cast<String, dynamic>();
  }

  /// Notifie plusieurs membres en une requête.
  static Future<Map<String, dynamic>> createBulkNotifications({
    required List<String> memberIds,
    required String type,
    required String title,
    required String message,
    String? relatedId,
    String? relatedType,
  }) async {
    final data = await _client.post('/notifications/bulk', body: {
      'member_ids': memberIds,
      'type': type,
      'title': title,
      'message': message,
      if (relatedId != null) 'related_id': relatedId,
      if (relatedType != null) 'related_type': relatedType,
    });
    return (data as Map).cast<String, dynamic>();
  }
}