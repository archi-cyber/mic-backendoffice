import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';

/// Anniversaires.
///
/// L'envoi des notifications relève désormais du serveur : une tâche planifiée
/// tourne chaque matin à 7 h et annonce les anniversaires du jour. Assez tôt
/// pour être vu dans la journée, assez tard pour ne pas réveiller les
/// appareils.
///
/// Ce service se limite donc à la consultation. Les méthodes de planification
/// et d'envoi sont conservées pour compatibilité, mais n'ont plus d'effet —
/// laisser le client déclencher les envois signifiait qu'un anniversaire
/// passait inaperçu si personne n'ouvrait l'application ce jour-là.
class BirthdayNotificationService {
  static ApiClient get _client => AuthService.client;

  /// Anniversaires à venir.
  ///
  /// Exclut les membres ayant désactivé les notifications d'anniversaire.
  static Future<List<Map<String, dynamic>>> getUpcomingBirthdays({
    int days = 30,
  }) =>
      _client.getList('/members/birthdays', query: {'days': days});

  /// Anniversaires du jour.
  static Future<List<Map<String, dynamic>>> getTodayBirthdays() async {
    final upcoming = await getUpcomingBirthdays(days: 1);
    return upcoming.where((row) => row['days_until'] == 0).toList();
  }

  /// Anniversaires du mois courant.
  static Future<List<Map<String, dynamic>>> getMonthBirthdays() async {
    final dashboard = await _client.getOne('/reports/dashboard');
    final birthdays = (dashboard['birthdays_this_month'] as List?) ?? const [];
    return birthdays.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Déclenche l'envoi des notifications du jour.
  ///
  /// Sans effet : la tâche planifiée du serveur s'en charge. Conservée pour ne
  /// pas casser les appels existants.
  static Future<void> sendTodayBirthdayNotifications() async {
    // Volontairement vide.
  }

  /// Planifie les notifications à venir.
  ///
  /// Sans effet, pour la même raison.
  static Future<void> scheduleBirthdayNotifications() async {
    // Volontairement vide.
  }

  /// Traite les anniversaires du jour.
  ///
  /// Sans effet : la tâche planifiée du serveur tourne chaque matin à 7 h.
  /// Elle s exécute que l application soit ouverte ou non, ce qui n était pas
  /// le cas quand le client en avait la charge — un anniversaire passait
  /// inaperçu si personne ne lançait l application ce jour-là.
  ///
  /// Renvoie le nombre d anniversaires du jour, à titre indicatif.
  static Future<int> processBirthdayNotifications() async {
    try {
      final today = await getTodayBirthdays();
      return today.length;
    } catch (_) {
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Clé du réglage dans les paramètres applicatifs.
  static const String _configKey = 'birthday_notifications';

  /// Configuration des notifications d'anniversaire.
  ///
  /// Le réglage vaut pour **toute l'église**, pas pour un appareil : il est
  /// stocké côté serveur. Deux responsables consultant l'écran des paramètres
  /// voient donc la même valeur.
  ///
  /// `target` détermine qui est averti : `all` pour toute l'assemblée,
  /// `workers` pour les seuls ouvriers, `leaders` pour les responsables.
  static Future<Map<String, dynamic>> getNotificationConfig() async {
    try {
      final result = await _client.getOne('/settings/$_configKey');
      final value = result['value'];

      if (value is Map) {
        return value.cast<String, dynamic>();
      }
    } catch (e) {
      debugPrint('[Birthday] Configuration illisible : $e');
    }

    // Valeur de repli au premier démarrage, avant tout réglage.
    return {'target': 'all', 'enabled': true};
  }

  /// Enregistre la configuration.
  ///
  /// Réservé aux administrateurs côté serveur : un réglage commun ne peut pas
  /// être modifié par n'importe qui.
  static Future<void> updateNotificationConfig({
    required String target,
    bool? enabled,
  }) async {
    final current = await getNotificationConfig();

    await _client.put('/settings/$_configKey', body: {
      'value': {
        'target': target,
        'enabled': enabled ?? current['enabled'] ?? true,
      },
    });

    debugPrint('[Birthday] Configuration enregistrée : cible « $target »');
  }
}