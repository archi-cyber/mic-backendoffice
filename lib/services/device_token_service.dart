import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/utils/permission_helper.dart';
import 'auth_service.dart';

/// Jetons d'appareil pour les notifications push.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// La résolution de l'utilisateur disparaît : l'ancienne version cherchait
/// l'identifiant dans la table `users`, avec un repli sur l'e-mail au cas où
/// la synchronisation aurait échoué. Le serveur déduit désormais le
/// destinataire du jeton d'authentification — aucun identifiant ne transite,
/// et aucun ne serait accepté.
///
/// Firebase reste **optionnel**. Sans configuration, l'initialisation renvoie
/// `null` sans erreur : les notifications arrivent de toute façon en temps réel
/// par Socket.IO tant que l'application est ouverte. Le push ne sert qu'à
/// prévenir un utilisateur dont l'application est fermée.
class DeviceTokenService {
  static ApiClient get _client => AuthService.client;

  static FirebaseMessaging? _firebaseMessaging;
  static String? _currentToken;

  /// Instance Firebase, initialisée à la demande.
  static FirebaseMessaging? get _messaging {
    if (_firebaseMessaging == null) {
      try {
        if (Firebase.apps.isNotEmpty) {
          _firebaseMessaging = FirebaseMessaging.instance;
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }
    return _firebaseMessaging;
  }

  /// Plateforme de l'appareil, telle que l'attend l'API.
  static String? get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {
      // Platform lève sur certaines cibles : la plateforme reste indéterminée.
    }
    return null;
  }

  /// Initialise les notifications push et enregistre le jeton.
  ///
  /// Renvoie `null` si Firebase n'est pas configuré ou si l'utilisateur refuse
  /// les notifications — deux situations normales, qui ne doivent pas
  /// interrompre le démarrage de l'application.
  static Future<String?> initialize() async {
    final messaging = _messaging;

    if (messaging == null) {
      debugPrint('[DeviceToken] Firebase absent : push désactivé.');
      return null;
    }

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint(
          '[DeviceToken] Notifications refusées : ${settings.authorizationStatus}',
        );
        return null;
      }

      final token = await messaging.getToken();
      _currentToken = token;

      // Le jeton n'est plus tracé en entier : il identifie l'appareil de façon
      // unique et n'a pas à figurer dans les journaux, y compris en
      // développement.
      debugPrint('[DeviceToken] Jeton obtenu (${token?.length ?? 0} caractères)');

      if (PermissionHelper.userId != null) {
        await saveDeviceToken(token);
      } else {
        debugPrint('[DeviceToken] Session absente : enregistrement différé.');
      }

      // Un jeton FCM est régénéré périodiquement par le système, sans que
      // l'application en soit prévenue autrement que par ce flux.
      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        debugPrint('[DeviceToken] Jeton renouvelé.');

        if (PermissionHelper.userId != null) {
          saveDeviceToken(newToken).catchError((e) {
            debugPrint('[DeviceToken] Enregistrement impossible : $e');
          });
        }
      });

      return token;
    } catch (e) {
      // L'échec du push ne doit pas empêcher l'application de fonctionner.
      debugPrint('[DeviceToken] Initialisation impossible : $e');
      return null;
    }
  }

  /// Enregistre le jeton auprès du serveur.
  ///
  /// Réenregistrer le même jeton met simplement à jour la plateforme : le
  /// serveur traite le couple (utilisateur, jeton) comme unique.
  static Future<void> saveDeviceToken(String? token) async {
    if (token == null || token.isEmpty) return;

    if (PermissionHelper.userId == null) {
      debugPrint('[DeviceToken] Session absente : jeton non enregistré.');
      return;
    }

    try {
      await _client.post('/users/me/devices', body: {
        'device_token': token,
        if (_platform != null) 'platform': _platform,
      });

      debugPrint('[DeviceToken] Jeton enregistré.');
    } catch (e) {
      debugPrint('[DeviceToken] Enregistrement échoué : $e');
    }
  }

  /// Enregistre le jeton courant, ou en obtient un si nécessaire.
  ///
  /// À appeler après la connexion : le jeton peut avoir été obtenu avant que
  /// l'utilisateur ne s'authentifie, auquel cas il n'a pas encore été envoyé.
  static Future<void> registerCurrentDeviceToken() async {
    final token = _currentToken ?? await _messaging?.getToken();
    await saveDeviceToken(token);
  }

  /// Appareils enregistrés de l'utilisateur connecté.
  ///
  /// [userId] est ignoré : le serveur déduit le compte du jeton
  /// d'authentification. Accepter un identifiant fourni par le client
  /// permettrait de lire les appareils d'autrui.
  static Future<List<String>> getDeviceTokensForUser(String userId) async {
    try {
      final devices = await _client.getList('/users/me/devices');
      return devices
          .map((d) => d['device_token']?.toString())
          .whereType<String>()
          .toList();
    } catch (e) {
      debugPrint('[DeviceToken] Lecture impossible : $e');
      return const [];
    }
  }

  /// Jetons de plusieurs utilisateurs.
  ///
  /// N'est plus accessible depuis le client : l'envoi de notifications relève
  /// du serveur, qui résout lui-même les destinataires. Renvoie une liste vide.
  ///
  /// Conservée pour ne pas casser les appels existants — les écrans qui
  /// l'utilisaient pour envoyer des notifications doivent passer par les
  /// routes dédiées, comme `POST /tasks/:id/remind`.
  static Future<List<String>> getDeviceTokensForUsers(
    List<String> userIds,
  ) async {
    debugPrint(
      '[DeviceToken] Sans objet : les destinataires sont résolus côté serveur.',
    );
    return const [];
  }

  /// Retire un jeton d'appareil.
  ///
  /// À appeler à la déconnexion : sans cela, l'appareil continuerait de
  /// recevoir les notifications de la personne précédente.
  static Future<void> removeDeviceToken(String token) async {
    if (token.isEmpty) return;

    try {
      await _client.delete('/users/me/devices/$token');
      if (_currentToken == token) _currentToken = null;

      debugPrint('[DeviceToken] Jeton retiré.');
    } catch (e) {
      debugPrint('[DeviceToken] Retrait impossible : $e');
    }
  }

  /// Retire le jeton courant — raccourci pour la déconnexion.
  static Future<void> clearCurrentDeviceToken() async {
    final token = _currentToken;
    if (token != null) await removeDeviceToken(token);
  }
}