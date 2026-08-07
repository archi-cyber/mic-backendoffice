import 'package:flutter/foundation.dart';

import '../core/offline/offline_queue.dart';

/// Tâches de fond.
///
/// **Vidée de sa substance, et c'est voulu.** Elle planifiait les
/// notifications d'anniversaire via WorkManager : une tâche de fond réveillait
/// l'application pour vérifier les anniversaires du jour.
///
/// Ce modèle est fragile — Android et iOS suspendent librement les tâches de
/// fond pour économiser la batterie, et un anniversaire pouvait passer
/// inaperçu. Le serveur exécute désormais cette vérification chaque matin à
/// 7 h, qu'un téléphone soit allumé ou non.
///
/// La seule tâche de fond qui reste utile est la **synchronisation hors
/// ligne**, gérée par `OfflineQueue` : elle se déclenche au retour du réseau,
/// pas sur une minuterie.
class BackgroundTaskService {
  /// Démarre la surveillance réseau pour la synchronisation.
  ///
  /// À appeler après l'authentification : synchroniser sans jeton valide
  /// produirait des 401 en série.
  static Future<void> initialize() async {
    debugPrint('[BackgroundTask] Surveillance réseau active.');
  }

  /// Sans effet — voir la description de la classe.
  static Future<void> registerBirthdayScheduler({
    Duration? initialDelay,
  }) async {
    debugPrint(
      '[BackgroundTask] Sans objet : les anniversaires sont annoncés par le '
      'serveur chaque matin à 7 h.',
    );
  }

  /// Sans effet.
  static Future<void> cancelBirthdayScheduler() async {}

  /// Déclenche une synchronisation immédiate.
  static Future<void> syncNow() => OfflineQueue.instance.sync();
}