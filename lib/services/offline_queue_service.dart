import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/offline/offline_operation.dart';
import '../core/offline/offline_queue.dart';

/// File d'attente hors ligne.
///
/// Signatures conservées pour ne pas casser les appels existants. L'ancienne
/// implémentation ne gérait que deux types d'opérations — présence à une
/// formation, assignation de tâche — codés en dur dans un `switch`. Elle ne
/// couvrait donc pas la présence aux cultes.
///
/// La nouvelle file est **générique** : elle enregistre méthode, chemin et
/// corps, et rejoue la requête telle quelle. Ajouter un cas d'usage ne demande
/// plus de la modifier.
///
/// Voir `OfflineQueue` pour l'implémentation.
class OfflineQueueService {
  /// Indique si l'appareil a une connexion.
  ///
  /// Attention : avoir une connexion ne garantit pas que le serveur soit
  /// joignable. Un wifi captif — hôtel, salle de conférence — répond au test
  /// sans laisser passer le trafic.
  static Future<bool> isOnline() => OfflineQueue.instance.isOnline();

  /// Dépose une opération.
  ///
  /// [type] est conservé comme libellé lisible ; il ne détermine plus le
  /// traitement.
  static Future<void> queueOperation({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final method = data['method'] as String? ?? 'POST';
    final path = data['path'] as String?;

    if (path == null) {
      throw ArgumentError(
        'Le champ « path » est requis : la file rejoue la requête telle '
        'quelle, elle ne devine plus la route depuis un type.',
      );
    }

    await OfflineQueue.instance.enqueue(
      method: method,
      path: path,
      body: (data['body'] as Map?)?.cast<String, dynamic>(),
      tempId: data['temp_id'] as String?,
      label: data['label'] as String? ?? type,
    );
  }

  /// Opérations en attente.
  static Future<List<Map<String, dynamic>>> getQueuedOperations() async {
    final operations = await OfflineQueue.instance.pending();
    return operations.map((op) => op.toJson()).toList();
  }

  static Future<void> removeOperation(String operationId) =>
      OfflineQueue.instance.remove(operationId);

  /// Vide la file.
  ///
  /// Les saisies non synchronisées sont **perdues**. À ne proposer qu'avec un
  /// avertissement explicite.
  static Future<void> clearQueue() => OfflineQueue.instance.clear();

  /// Rejoue les opérations en attente.
  static Future<void> processQueue() => OfflineQueue.instance.sync();

  /// Nombre d'opérations en attente — pour un badge.
  static Future<int> pendingCount() => OfflineQueue.instance.count();

  /// Flux du nombre d'opérations en attente.
  static Stream<int> get pendingCountStream => OfflineQueue.instance.pendingCount;

  /// Flux des résultats de synchronisation.
  static Stream<SyncResult> get syncStream => OfflineQueue.instance.syncState;

  static Stream<ConnectivityResult> connectivityStream() {
    return Connectivity().onConnectivityChanged;
  }
}