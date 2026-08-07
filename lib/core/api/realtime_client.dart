import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../config/app_config.dart';
import 'token_storage.dart';

/// Événements émis par le serveur.
///
/// Ces noms sont un contrat avec le backend : les modifier romprait la
/// réception. Ils correspondent aux constantes `EVENTS` de `realtime.types.ts`.
abstract final class RealtimeEvents {
  static const notificationNew = 'notification:new';
  static const attendanceUpdated = 'attendance:updated';
  static const taskAssigned = 'task:assigned';
  static const taskUpdated = 'task:updated';
  static const announcementNew = 'announcement:new';
  static const penaltyUpdated = 'penalty:updated';
  static const memberUpdated = 'member:updated';
}

/// Connexion temps réel.
///
/// Remplace les abonnements Realtime de Supabase. La différence tient au
/// modèle d'accès : Supabase diffusait les changements de table, filtrés par
/// les politiques RLS. Ici, le serveur décide quoi envoyer et à qui — le
/// client ne voit que ce qui le concerne, sans que la structure de la base ne
/// transparaisse.
///
/// Usage :
/// ```dart
/// final realtime = RealtimeClient(tokenStorage: AuthService.client.tokens);
/// await realtime.connect();
///
/// realtime.on(RealtimeEvents.notificationNew, (data) {
///   // Rafraîchir le badge de notifications
/// });
/// ```
class RealtimeClient {
  RealtimeClient({required TokenStorage tokenStorage})
      : _tokens = tokenStorage;

  final TokenStorage _tokens;
  io.Socket? _socket;

  /// Écouteurs enregistrés avant la connexion.
  ///
  /// Les écrans s'abonnent souvent avant que la connexion ne soit établie.
  /// Conserver les écouteurs permet de les rebrancher à la connexion, et
  /// surtout après une reconnexion — sinon un écran ouvert cesserait
  /// silencieusement de recevoir après une coupure réseau.
  final Map<String, List<void Function(dynamic)>> _listeners = {};

  final _connectionState = StreamController<bool>.broadcast();

  /// Flux d'état de la connexion, pour afficher un indicateur.
  Stream<bool> get connectionState => _connectionState.stream;

  bool get isConnected => _socket?.connected ?? false;

  // ---------------------------------------------------------------------------
  // Connexion
  // ---------------------------------------------------------------------------

  /// Établit la connexion.
  ///
  /// Sans jeton valide, la connexion n'est pas tentée : le serveur la
  /// refuserait immédiatement, et insister ferait boucler la reconnexion
  /// automatique.
  Future<void> connect() async {
    final token = await _tokens.getAccessToken();

    if (token == null) {
      debugPrint('[Realtime] Aucun jeton : connexion non tentée.');
      return;
    }

    await disconnect();

    _socket = io.io(
      '${AppConfig.realtimeUrl}${AppConfig.realtimeNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          // La reconnexion est gérée par la librairie, avec un délai
          // croissant : indispensable en mobilité, où le réseau se coupe
          // régulièrement.
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .disableAutoConnect()
          .build(),
    );

    _bindCoreEvents();
    _rebindListeners();

    _socket!.connect();
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _connectionState.add(false);
  }

  /// Reconnecte avec un jeton rafraîchi.
  ///
  /// Le jeton est validé à l'ouverture de la connexion, pas à chaque message :
  /// une connexion établie survit à l'expiration de son jeton. Mais une
  /// reconnexion après coupure échouerait avec l'ancien — d'où cette méthode,
  /// à appeler après un rafraîchissement.
  Future<void> reconnectWithFreshToken() => connect();

  // ---------------------------------------------------------------------------
  // Écouteurs
  // ---------------------------------------------------------------------------

  /// Enregistre un écouteur.
  ///
  /// Fonctionne avant comme après la connexion.
  void on(String event, void Function(dynamic data) handler) {
    _listeners.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  /// Retire un écouteur.
  ///
  /// À appeler dans `dispose()` des écrans : un écouteur qui survit à son
  /// widget provoque une fuite mémoire, et pire, tente de rafraîchir un état
  /// détruit.
  void off(String event, [void Function(dynamic data)? handler]) {
    if (handler != null) {
      _listeners[event]?.remove(handler);
      _socket?.off(event, handler);
    } else {
      _listeners.remove(event);
      _socket?.off(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Salons de culte
  // ---------------------------------------------------------------------------

  /// Rejoint le salon d'un culte pour suivre la saisie en direct.
  ///
  /// À appeler à l'ouverture de l'écran de pointage. C'est le cas d'usage
  /// principal du temps réel : plusieurs responsables pointent le même culte,
  /// et chacun doit voir les modifications des autres.
  void joinService(String churchServiceId) {
    _socket?.emit('service:join', {'churchServiceId': churchServiceId});
  }

  /// Quitte le salon, à appeler dans `dispose()` de l'écran.
  void leaveService(String churchServiceId) {
    _socket?.emit('service:leave', {'churchServiceId': churchServiceId});
  }

  // ---------------------------------------------------------------------------
  // Interne
  // ---------------------------------------------------------------------------

  void _bindCoreEvents() {
    final socket = _socket;
    if (socket == null) return;

    socket.onConnect((_) => debugPrint('[Realtime] Transport établi.'));

    // `connected` est émis par le serveur APRÈS validation du jeton.
    // `onConnect` ne signale que l'ouverture du transport : à ce stade,
    // l'authentification peut encore échouer.
    socket.on('connected', (data) {
      debugPrint('[Realtime] Authentifié. Salons : ${data?['rooms']}');
      _connectionState.add(true);
    });

    socket.on('unauthorized', (data) {
      debugPrint('[Realtime] Refusé : ${data?['message']}');
      _connectionState.add(false);
      // Inutile d'insister : le jeton est invalide, la reconnexion
      // automatique échouerait autant de fois qu'elle est tentée.
      socket.disconnect();
    });

    socket.onDisconnect((reason) {
      debugPrint('[Realtime] Déconnecté : $reason');
      _connectionState.add(false);
    });

    socket.onConnectError((error) {
      debugPrint('[Realtime] Erreur de connexion : $error');
      _connectionState.add(false);
    });
  }

  /// Rebranche les écouteurs sur la nouvelle socket.
  void _rebindListeners() {
    final socket = _socket;
    if (socket == null) return;

    _listeners.forEach((event, handlers) {
      for (final handler in handlers) {
        socket.on(event, handler);
      }
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _listeners.clear();
    _connectionState.close();
  }
}