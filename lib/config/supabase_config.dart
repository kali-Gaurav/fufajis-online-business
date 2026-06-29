import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/runtime_config_service.dart';

/// Supabase configuration and initialization
class SupabaseConfig {
  static late final SupabaseClient _client;

  /// Initialize Supabase with Flutter
  static Future<void> initialize() async {
    try {
      final url = RuntimeConfig.instance.supabaseUrl;
      final anonKey = RuntimeConfig.instance.supabaseAnonKey;

      if (url.isEmpty || anonKey.isEmpty) {
        print('[Supabase] Warning: URL or Anon Key is empty. Skipping initialization.');
        return;
      }

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        headers: {
          'Content-Type': 'application/json',
        },
      );
      _client = Supabase.instance.client;
      print('[Supabase] Initialized successfully at $url');
    } catch (e) {
      print('[Supabase] Initialization failed: $e');
    }
  }

  /// Get Supabase client instance
  static SupabaseClient get client => _client;

  /// Get Auth client
  static GoTrueClient get auth => _client.auth;

  /// Get Storage client
  static SupabaseStorageClient get storage => _client.storage;

  /// Get current user
  static User? get currentUser => _client.auth.currentUser;

  /// Get current user ID
  static String? get userId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  static bool get isAuthenticated => _client.auth.currentUser != null;

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      print('[Supabase] Signed out successfully');
    } catch (e) {
      print('[Supabase] Sign out failed: $e');
      rethrow;
    }
  }
}
