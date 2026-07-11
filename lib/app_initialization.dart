// lib/app_initialization.dart
// Handles all app startup initialization, including secure secret management
// This module ensures Razorpay secrets are loaded from Supabase Vault before any payments

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'services/secure_config_service.dart';

/// Initialize the application with all necessary services
/// This must be called in main() before runApp()
///
/// Order of initialization:
/// 1. Firebase (authentication, Firestore)
/// 2. Supabase (PostgreSQL, Edge Functions, Vault)
/// 3. Secure configuration (fetch Razorpay credentials at runtime)
class AppInitialization {
  static Future<void> initialize() async {
    debugPrint('[AppInit] Starting application initialization...');

    try {
      // Step 1: Initialize Firebase
      debugPrint('[AppInit] Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[AppInit] ✅ Firebase initialized');

      // Step 2: Initialize Supabase
      debugPrint('[AppInit] Initializing Supabase...');
      await Supabase.initialize(
        url: 'YOUR_SUPABASE_URL', // Replace with actual URL
        anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with actual key
      );
      debugPrint('[AppInit] ✅ Supabase initialized');

      // Step 3: Initialize Secure Configuration (Razorpay secrets from Vault)
      // This will:
      //   - Load cached secrets from device secure storage
      //   - Fetch fresh secrets from Supabase Vault if needed
      //   - Start auto-refresh timer (refresh 10 min before expiry)
      debugPrint('[AppInit] Initializing secure configuration...');
      final configService = SecureConfigService();
      await configService.initialize();
      debugPrint('[AppInit] ✅ Secure configuration initialized');

      debugPrint('[AppInit] ✅ All services initialized successfully');
    } catch (e) {
      debugPrint('[AppInit] ❌ Initialization error: $e');

      // Log detailed error for debugging
      if (kDebugMode) {
        debugPrint('[AppInit] Stack trace:');
        debugPrint(e.toString());
      }

      rethrow;
    }
  }

  /// Cleanup on app shutdown
  static void dispose() {
    debugPrint('[AppInit] Cleaning up resources...');
    final configService = SecureConfigService();
    configService.dispose();
    debugPrint('[AppInit] ✅ Cleanup complete');
  }
}
