import '../core/offline/offline_cache.dart';

/// Lecture du cache hors ligne et listes de tâches mises de côté.
///
/// Tout passe par [OfflineCache], vidé à la déconnexion : les données d'un
/// utilisateur ne restent pas lisibles par le suivant.
class OfflineStorageService {
  static const String _tasksCachePrefix = '/tasks#list:';

  /// Ancienne initialisation SQLite — sans objet.
  static Future<dynamic> get database async => null;

  static Future<void> clear() => OfflineCache.instance.clear();

  /// Lit une entrée mise en cache.
  static Future<dynamic> read(String key) async {
    final entry = await OfflineCache.instance.get(key);
    return entry?.value;
  }

  static Future<DateTime?> cachedAt(String key) async {
    final entry = await OfflineCache.instance.get(key);
    return entry?.cachedAt;
  }

  static String tasksCacheKey({String? departmentId}) {
    return departmentId ?? 'all';
  }

  static Future<void> cacheTasks(
    String cacheKey,
    List<Map<String, dynamic>> tasks,
  ) =>
      OfflineCache.instance.put('$_tasksCachePrefix$cacheKey', tasks);

  static Future<List<Map<String, dynamic>>?> getCachedTasks(
    String cacheKey,
  ) async {
    final value = await read('$_tasksCachePrefix$cacheKey');
    if (value is! List) return null;
    try {
      return value
          .map((task) => Map<String, dynamic>.from(task as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAllTasksCache() =>
      OfflineCache.instance.removeWhere(_tasksCachePrefix);
}
