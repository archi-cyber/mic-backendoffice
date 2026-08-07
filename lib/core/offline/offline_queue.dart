import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'offline_operation.dart';

/// File d'opérations en attente de synchronisation.
///
/// Toute écriture faite sans réseau y est déposée, puis rejouée dans l'ordre
/// au retour de la connexion.
///
/// **L'ordre est essentiel** : créer un culte doit précéder l'enregistrement de
/// ses présences. La file est donc traitée séquentiellement, jamais en
/// parallèle, et une opération bloquée arrête celles qui la suivent — sauf si
/// elle est mise de côté après cinq échecs.
///
/// La persistance passe par `SharedPreferences` plutôt que SQLite : la file
/// contient au plus quelques dizaines d'opérations, dont une seule volumineuse
/// — la feuille de présence. Une base de données serait disproportionnée.
class OfflineQueue {
  OfflineQueue._();

  static final OfflineQueue instance = OfflineQueue._();

  static const String _queueKey = 'offline_queue_v2';
  static const String _mappingKey = 'offline_temp_id_map';

  ApiClient? _client;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Timer? _retryTimer;
  bool _syncing = false;

  final _pendingCount = StreamController<int>.broadcast();
  final _syncState = StreamController<SyncResult>.broadcast();

  /// Nombre d'opérations en attente — pour afficher un indicateur.
  Stream<int> get pendingCount => _pendingCount.stream;

  /// Résultat de chaque synchronisation.
  Stream<SyncResult> get syncState => _syncState.stream;

  // ---------------------------------------------------------------------------
  // Cycle de vie
  // ---------------------------------------------------------------------------

  /// Démarre la surveillance réseau.
  ///
  /// À appeler après l'authentification : synchroniser sans jeton valide
  /// produirait des 401 en série et épuiserait le compteur de tentatives.
  Future<void> start(ApiClient client) async {
    _client = client;

    await _connectivitySub?.cancel();

    // `connectivity_plus` 5.x émet un résultat simple ; les versions 6 et
    // suivantes émettent une liste, un appareil pouvant avoir plusieurs
    // interfaces actives. Le code suit la version installée.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final online = result != ConnectivityResult.none;

      if (online) {
        debugPrint('[OfflineQueue] Réseau rétabli : synchronisation...');
        // Court délai avant de synchroniser : le système signale la connexion
        // avant qu'elle ne soit réellement utilisable, et une requête envoyée
        // trop tôt échoue pour rien.
        Future.delayed(const Duration(seconds: 2), sync);
      }
    });

    // Nouvelle tentative périodique : le réseau peut redevenir utilisable sans
    // que le système émette d'événement — passage d'un wifi saturé à la 4G,
    // par exemple.
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());

    await _emitCount();
    await sync();
  }

  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _connectivitySub = null;
    _retryTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Dépôt
  // ---------------------------------------------------------------------------

  /// Ajoute une opération à la file.
  ///
  /// Renvoie l'opération créée, dont l'identifiant permet de la retrouver.
  Future<OfflineOperation> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? tempId,
    String? label,
  }) async {
    final operation = OfflineOperation(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      method: method,
      path: path,
      body: body,
      createdAt: DateTime.now(),
      tempId: tempId,
      label: label,
    );

    final queue = await _read();
    queue.add(operation);
    await _write(queue);

    debugPrint('[OfflineQueue] En attente : ${label ?? '$method $path'}');

    return operation;
  }

  Future<List<OfflineOperation>> pending() => _read();

  Future<int> count() async => (await _read()).length;

  /// Retire une opération — après succès, ou sur décision de l'utilisateur.
  Future<void> remove(String operationId) async {
    final queue = await _read();
    queue.removeWhere((op) => op.id == operationId);
    await _write(queue);
  }

  /// Vide la file.
  ///
  /// Les saisies non synchronisées sont **perdues** : à ne proposer qu'avec un
  /// avertissement explicite.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    await prefs.remove(_mappingKey);
    await _emitCount();
  }

  // ---------------------------------------------------------------------------
  // Synchronisation
  // ---------------------------------------------------------------------------

  /// Rejoue les opérations en attente.
  ///
  /// Sans effet si une synchronisation est déjà en cours : deux passages
  /// simultanés rejoueraient les mêmes opérations, et bien qu'elles soient
  /// idempotentes côté serveur, cela doublerait le trafic pour rien.
  Future<SyncResult> sync() async {
    if (_syncing) {
      return const SyncResult(synced: 0, failed: 0, remaining: 0);
    }

    final client = _client;
    if (client == null) {
      return const SyncResult(synced: 0, failed: 0, remaining: 0);
    }

    if (!await isOnline()) {
      final remaining = await count();
      return SyncResult(synced: 0, failed: 0, remaining: remaining);
    }

    _syncing = true;

    var synced = 0;
    var failed = 0;
    final errors = <String>[];

    try {
      var queue = await _read();
      var mappings = await _readMappings();

      // Traitement séquentiel : créer un culte doit précéder l'enregistrement
      // de ses présences.
      for (final original in List<OfflineOperation>.from(queue)) {
        // Substitution des identifiants temporaires déjà résolus.
        var operation = original;
        for (final entry in mappings.entries) {
          operation = operation.resolveTempId(entry.key, entry.value);
        }

        // Une opération encore liée à un identifiant temporaire non résolu ne
        // peut pas partir : son parent a échoué. On la laisse en file.
        if (operation.path.contains('temp_') ||
            (operation.body != null &&
                jsonEncode(operation.body).contains('temp_'))) {
          continue;
        }

        try {
          final response = await _send(client, operation);

          // Si l'opération a créé une entité, on retient la correspondance
          // pour les suivantes.
          if (operation.tempId != null && response is Map) {
            final realId = response['id']?.toString();
            if (realId != null) {
              mappings[operation.tempId!] = realId;
              await _writeMappings(mappings);
            }
          }

          await remove(operation.id);
          synced += 1;
        } on ApiException catch (error) {
          if (error.isRetryable) {
            // Erreur transitoire : on incrémente le compteur et on s'arrête
            // là. Continuer traiterait les opérations suivantes dans le
            // désordre.
            await _bumpAttempts(operation, error.message);
            break;
          }

          // Refus définitif — validation, permission, conflit. Réessayer
          // produirait le même résultat.
          failed += 1;
          errors.add('${operation.label ?? operation.path} : ${error.message}');

          final updated = await _bumpAttempts(operation, error.message);

          if (!updated.isRetryable) {
            debugPrint(
              '[OfflineQueue] Abandon après ${OfflineOperation.maxAttempts} '
              'tentatives : ${operation.label ?? operation.path}',
            );
          }
        } catch (error) {
          await _bumpAttempts(operation, error.toString());
          break;
        }
      }

      queue = await _read();

      // Les correspondances ne servent plus une fois la file vidée, et les
      // conserver ferait grossir le stockage indéfiniment.
      if (queue.isEmpty) {
        await _writeMappings({});
      }

      final result = SyncResult(
        synced: synced,
        failed: failed,
        remaining: queue.length,
        errors: errors,
      );

      _syncState.add(result);
      await _emitCount();

      if (synced > 0) {
        debugPrint('[OfflineQueue] $synced opération(s) synchronisée(s)');
      }

      return result;
    } finally {
      _syncing = false;
    }
  }

  /// Indique si l'appareil a une connexion.
  ///
  /// Attention : avoir une connexion ne garantit pas que le serveur soit
  /// joignable. Un wifi captif — hôtel, salle de conférence — répond au test
  /// sans laisser passer le trafic. C'est pourquoi l'échec d'une requête reste
  /// le signal qui fait basculer une opération en file, pas ce test.
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ---------------------------------------------------------------------------
  // Interne
  // ---------------------------------------------------------------------------

  Future<dynamic> _send(ApiClient client, OfflineOperation operation) {
    switch (operation.method) {
      case 'POST':
        return client.post(operation.path, body: operation.body);
      case 'PATCH':
        return client.patch(operation.path, body: operation.body);
      case 'PUT':
        return client.put(operation.path, body: operation.body);
      case 'DELETE':
        return client.delete(operation.path, body: operation.body);
      default:
        throw UnsupportedError('Méthode inconnue : ${operation.method}');
    }
  }

  Future<OfflineOperation> _bumpAttempts(
    OfflineOperation operation,
    String error,
  ) async {
    final queue = await _read();
    final index = queue.indexWhere((op) => op.id == operation.id);

    if (index == -1) return operation;

    final updated = queue[index].copyWith(
      attempts: queue[index].attempts + 1,
      lastError: error,
    );

    queue[index] = updated;
    await _write(queue);

    return updated;
  }

  Future<List<OfflineOperation>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      return (jsonDecode(raw) as List)
          .map((e) => OfflineOperation.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      // File corrompue : mieux vaut repartir de zéro que boucler sur une
      // erreur de lecture à chaque synchronisation.
      debugPrint('[OfflineQueue] File illisible, réinitialisation : $e');
      await prefs.remove(_queueKey);
      return [];
    }
  }

  Future<void> _write(List<OfflineOperation> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(queue.map((op) => op.toJson()).toList()),
    );
    await _emitCount();
  }

  Future<Map<String, String>> _readMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mappingKey);

    if (raw == null || raw.isEmpty) return {};

    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMappings(Map<String, String> mappings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mappingKey, jsonEncode(mappings));
  }

  Future<void> _emitCount() async {
    _pendingCount.add(await count());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _pendingCount.close();
    _syncState.close();
  }
}