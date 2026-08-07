import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache des réponses de lecture.
///
/// Permet aux écrans de s'afficher sans réseau : liste des membres, cultes
/// récents, feuille de présence. Sans lui, un responsable arrivant dans une
/// salle sans couverture trouverait une application vide — et ne pourrait donc
/// rien pointer, même si la file d'attente sait enregistrer ses saisies.
///
/// Le cache est **volontairement simple** : dernière réponse par chemin,
/// écrasée à chaque lecture réussie. Pas d'invalidation fine, pas de fusion.
/// Une donnée périmée affichée avec sa date vaut mieux qu'un écran vide.
class OfflineCache {
  OfflineCache._();

  static final OfflineCache instance = OfflineCache._();

  static const String _prefix = 'offline_cache:';

  /// Durée au-delà de laquelle une entrée est considérée comme trop ancienne.
  ///
  /// Elle reste servie, mais l'interface peut prévenir l'utilisateur. Sept
  /// jours couvrent le cas d'usage : un responsable qui n'a pas ouvert
  /// l'application depuis une semaine doit se méfier de ce qu'il voit.
  static const Duration staleAfter = Duration(days: 7);

  /// Chemins mis en cache.
  ///
  /// Liste blanche plutôt que tout mettre en cache : les rapports et les
  /// données financières n'ont pas à traîner sur l'appareil, et les mettre en
  /// cache gonflerait le stockage sans servir le hors ligne — on ne consulte
  /// pas un bilan comptable pendant le culte.
  static const List<String> _cacheable = [
    '/members',
    '/departments',
    '/church-services',
    '/sunday-school/children',
    '/visitors',
    '/tasks',
    '/classes',
    '/events',
    '/teachings',
    '/auth/me',
  ];

  static bool isCacheable(String path) {
    return _cacheable.any((prefix) => path.startsWith(prefix));
  }

  /// Enregistre une réponse.
  Future<void> put(String key, dynamic value) async {
    if (!isCacheable(key)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_prefix$key',
        jsonEncode({
          'value': value,
          'cached_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Un échec d'écriture ne doit pas faire échouer la requête : le cache
      // est un confort, la réponse réseau est déjà entre les mains de
      // l'appelant.
      debugPrint('[OfflineCache] Écriture impossible : $e');
    }
  }

  /// Lit une réponse mise en cache, ou `null`.
  Future<CachedEntry?> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');

      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.tryParse(decoded['cached_at'] as String? ?? '');

      return CachedEntry(
        value: decoded['value'],
        cachedAt: cachedAt ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('[OfflineCache] Lecture impossible : $e');
      return null;
    }
  }

  /// Vide le cache — à la déconnexion.
  ///
  /// Indispensable : les données d'un utilisateur ne doivent pas rester
  /// lisibles par le suivant sur un appareil partagé.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();

    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint('[OfflineCache] ${keys.length} entrée(s) effacée(s)');
  }
}

/// Entrée du cache, avec sa date.
class CachedEntry {
  const CachedEntry({required this.value, required this.cachedAt});

  final dynamic value;
  final DateTime cachedAt;

  bool get isStale => DateTime.now().difference(cachedAt) > OfflineCache.staleAfter;

  Duration get age => DateTime.now().difference(cachedAt);
}