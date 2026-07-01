import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/runtime_config_service.dart';

/// Supabase configuration and initialization
class SupabaseConfig {
  static SupabaseClient? _client;
  static bool _initialized = false;

  /// Initialize Supabase with Flutter
  static Future<void> initialize() async {
    if (_initialized) return;

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
      _initialized = true;
      print('[Supabase] Initialized successfully at $url');
    } catch (e) {
      print('[Supabase] Initialization failed: $e');
    }
  }

  /// Check if Supabase is initialized and available
  static bool get isAvailable => _initialized && _client != null;

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw StateError('Supabase has not been initialized. Check isAvailable first.');
    }
    return _client!;
  }

  /// Get Auth client
  static GoTrueClient get auth => client.auth;

  /// Get Storage client
  static SupabaseStorageClient get storage => client.storage;

  /// Get current user
  static User? get currentUser => isAvailable ? _client?.auth.currentUser : null;

  /// Get current user ID
  static String? get userId => isAvailable ? _client?.auth.currentUser?.id : null;

  /// Check if user is authenticated
  static bool get isAuthenticated => isAvailable && _client?.auth.currentUser != null;

  /// Sign out
  static Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _client?.auth.signOut();
      print('[Supabase] Signed out successfully');
    } catch (e) {
      print('[Supabase] Sign out failed: $e');
      rethrow;
    }
  }
}
