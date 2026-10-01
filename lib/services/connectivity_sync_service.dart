import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/offline/offline_queue.dart';

/// État de la connexion, pour le bandeau hors ligne et la barre latérale.
///
/// La synchronisation elle-même est assurée par [OfflineQueue], démarrée après
/// la connexion : ce service se contente d'exposer l'état réseau et de
/// relancer la file au retour du réseau.
class ConnectivitySyncService {
  ConnectivitySyncService._();
  static final ConnectivitySyncService instance = ConnectivitySyncService._();

  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true;
  bool _initialized = false;

  bool get isOnline => _isOnline;
  final ValueNotifier<bool> onlineNotifier = ValueNotifier(true);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await refresh();

    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  /// Réévalue l'état réseau et rejoue la file si la connexion est là.
  Future<void> refresh() async {
    _setOnline(await OfflineQueue.instance.isOnline());
    if (_isOnline) {
      await OfflineQueue.instance.sync();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _setOnline(result != ConnectivityResult.none);

    if (!wasOnline && _isOnline) {
      await OfflineQueue.instance.sync();
    }
  }

  void _setOnline(bool value) {
    _isOnline = value;
    onlineNotifier.value = value;
  }
}
