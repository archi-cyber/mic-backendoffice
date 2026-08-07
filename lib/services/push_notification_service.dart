import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Envoi de notifications push.
///
/// **Ce service n'envoie plus rien.** L'ancienne version appelait une fonction
/// Edge Supabase, qui contactait Firebase avec les jetons d'appareil fournis
/// par le client.
///
/// Ce modèle posait un problème de fond : n'importe quel client authentifié
/// pouvait envoyer une notification à n'importe quel appareil, en fournissant
/// simplement les jetons. Le serveur n'avait aucun moyen de vérifier que
/// l'expéditeur avait le droit de notifier ces destinataires.
///
/// L'envoi relève désormais du backend, qui résout lui-même les destinataires
/// à partir de l'action : assigner une tâche notifie les assignés, publier une
/// annonce notifie son public. Le client déclenche l'action, pas l'envoi.
///
/// Les méthodes sont conservées pour ne pas casser les appels existants. Elles
/// journalisent et renvoient un résultat neutre.
class PushNotificationService {
  static ApiClient get _client => AuthService.client;

  /// Envoi direct à des appareils — n'est plus possible.
  ///
  /// Fournir des jetons d'appareil depuis le client reviendrait à laisser
  /// n'importe qui notifier n'importe qui.
  static Future<Map<String, dynamic>> sendPushNotification({
    required List<String> deviceTokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint(
      '[PushNotification] Envoi direct non disponible : le serveur résout '
      'lui-même les destinataires. Utilisez la route de l\'action concernée.',
    );

    return {
      'success': false,
      'sent': 0,
      'reason': 'server_side_only',
    };
  }

  /// Notifie l'assemblée d'une nouvelle annonce.
  ///
  /// L'envoi est déjà déclenché par `POST /announcements` : publier une
  /// annonce crée les notifications et les diffuse. Cette méthode n'a donc
  /// plus rien à faire.
  ///
  /// [excludeUserId] n'a plus d'objet non plus : le serveur exclut l'auteur
  /// de ses propres destinataires.
  static Future<Map<String, dynamic>> sendAnnouncementPushNotification({
    required String title,
    required String message,
    required String announcementId,
    String? excludeUserId,
  }) async {
    debugPrint(
      '[PushNotification] Sans objet : la publication de l\'annonce a déjà '
      'notifié ses destinataires.',
    );

    return {'success': true, 'sent': 0, 'reason': 'already_sent_by_server'};
  }

  /// Rappelle les assignés d'une tâche.
  ///
  /// Route dédiée : le serveur connaît les destinataires et refuse les tâches
  /// terminées, annulées ou archivées.
  static Future<Map<String, dynamic>> remindTask(String taskId) async {
    try {
      final result = await _client.post('/tasks/$taskId/remind');
      return (result as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('[PushNotification] Rappel impossible : $e');
      return {'success': false, 'sent': 0};
    }
  }

  /// Rappelle toutes les tâches en attente.
  ///
  /// Une notification par membre, pas par tâche : quelqu'un ayant cinq tâches
  /// en retard reçoit un récapitulatif.
  static Future<Map<String, dynamic>> remindAllPendingTasks({
    String? departmentId,
  }) async {
    try {
      final result = await _client.post('/tasks/remind-pending', body: {
        if (departmentId != null) 'department_id': departmentId,
      });
      return (result as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('[PushNotification] Rappel groupé impossible : $e');
      return {'success': false, 'sent': 0};
    }
  }
}