import '../core/offline/offline_cache.dart';


class OfflineStorageService {
  
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
}