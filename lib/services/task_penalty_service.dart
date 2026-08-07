import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Pénalités de retard.
///
/// Le calcul quotidien relève désormais du serveur : une tâche planifiée
/// tourne chaque nuit à 2 h. L'application n'a plus à le déclencher, ni à
/// reproduire la cascade du montant journalier — tâche, puis département,
/// puis paramètre global.
class TaskPenaltyService {
  static ApiClient get _client => AuthService.client;

  /// Paramètres globaux.
  static Future<Map<String, dynamic>> getSettings() =>
      _client.getOne('/penalties/settings');

  static Future<Map<String, dynamic>> updateSettings(
    Map<String, dynamic> updates,
  ) async {
    final data = await _client.patch('/penalties/settings', body: updates);
    return (data as Map).cast<String, dynamic>();
  }

  /// Membres ayant un solde impayé, du plus élevé au plus faible.
  static Future<List<Map<String, dynamic>>> getUnpaidBalances() =>
      _client.getList('/penalties/balances');

  /// Détail des pénalités d'un membre.
  static Future<Map<String, dynamic>> getMemberPenalties(String memberId) =>
      _client.getOne('/penalties/member/$memberId');

  /// Enregistre un versement.
  ///
  /// La réponse contient le solde recalculé : un membre repassé sous le seuil
  /// peut à nouveau recevoir des tâches.
  static Future<Map<String, dynamic>> recordPayment({
    required String memberId,
    required int amount,
    String? note,
  }) async {
    final data = await _client.post(
      '/penalties/member/$memberId/payment',
      body: {'amount': amount, if (note != null) 'note': note},
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Complète une liste de membres avec leur solde de pénalités.
  ///
  /// Les soldes sont récupérés en **une seule requête**, puis appariés en
  /// mémoire. Interroger le serveur membre par membre multiplierait les
  /// allers-retours sur un écran qui en affiche parfois plusieurs centaines.
  static Future<List<Map<String, dynamic>>> annotateMembersWithPenalties(
    List<Map<String, dynamic>> members,
  ) async {
    try {
      final balances = await getUnpaidBalances();

      final byMember = {
        for (final row in balances) row['member_id'] as String: row,
      };

      return members.map((member) {
        final balance = byMember[member['id']];
        return {
          ...member,
          'penalty_balance': balance?['balance'] ?? 0,
          'penalty_is_blocked': balance?['is_blocked'] ?? false,
        };
      }).toList();
    } catch (error) {
      debugPrint('[TaskPenalty] Soldes indisponibles : $error');
      // La liste est renvoyée sans annotation : afficher les membres sans
      // leur solde vaut mieux que de ne rien afficher du tout.
      return members;
    }
  }

  /// Déclenche le calcul des pénalités.
  ///
  /// Conservée pour compatibilité. Le calcul est automatique côté serveur ;
  /// cet appel ne sert qu'à rattraper une journée manquée. L'opération est
  /// idempotente : relancer sur une date déjà traitée ne crée aucun doublon.
  static Future<Map<String, dynamic>> calculatePenaltiesOnStartup() async {
    try {
      final data = await _client.post('/penalties/run', body: {});
      return (data as Map).cast<String, dynamic>();
    } catch (error) {
      // Réservé aux administrateurs : un échec est attendu pour les autres et
      // ne doit pas remonter jusqu'à l'utilisateur.
      debugPrint('[TaskPenalty] Calcul non déclenché : $error');
      return {'penalties_created': 0};
    }
  }
}