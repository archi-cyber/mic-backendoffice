import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Supabase service for initialization and client access
class SupabaseService {
  static SupabaseClient? _client;
  static bool _initialized = false;

  /// Initialize Supabase
  static Future<void> initialize({
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    if (_initialized) return;

    final url = supabaseUrl ?? AppConfig.supabaseUrl;
    final key = supabaseAnonKey ?? AppConfig.supabaseAnonKey;

    await Supabase.initialize(url: url, anonKey: key);

    _client = Supabase.instance.client;
    _initialized = true;
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
}
