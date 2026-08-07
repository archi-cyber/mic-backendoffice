import 'birthday_notification_service.dart';

/// Planification des notifications d'anniversaire.
///
/// Vidée de sa substance : le serveur exécute une tâche planifiée chaque matin
/// à 7 h. Faire reposer cet envoi sur le client signifiait qu'un anniversaire
/// passait inaperçu si personne n'ouvrait l'application ce jour-là — ce qui
/// arrive un dimanche matin comme un mardi.
///
/// Les méthodes restent exposées pour ne pas casser les appels existants.
class BirthdaySchedulerService {
  /// Sans effet — voir la description de la classe.
  static Future<void> initialize() async {}

  /// Sans effet.
  static Future<void> scheduleDaily() async {}

  /// Sans effet.
  static Future<void> cancelAll() async {}

  /// Anniversaires à venir, pour affichage.
  static Future<List<Map<String, dynamic>>> getUpcoming({int days = 30}) =>
      BirthdayNotificationService.getUpcomingBirthdays(days: days);
}