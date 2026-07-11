// lib/services/secure_config_service.dart
// Manages sensitive configuration (Razorpay credentials) with encryption
// Features:
//   - Runtime fetching from Supabase Vault
//   - Device-level encryption via flutter_secure_storage
//   - 1-hour TTL with automatic refresh
//   - Fallback to cached secrets on network failure
//   - Automatic rotation on app startup

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SecretConfig {
  final String razorpayKeyId;
  final String razorpaySecret;
  final DateTime expiresAt;
  final int ttlSeconds;
  final DateTime fetchedAt;

  SecretConfig({
    required this.razorpayKeyId,
    required this.razorpaySecret,
    required this.expiresAt,
    required this.ttlSeconds,
    required this.fetchedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExpiringSoon =>
      DateTime.now().add(Duration(minutes: 5)).isAfter(expiresAt);

  factory SecretConfig.fromJson(Map<String, dynamic> json) {
    return SecretConfig(
      razorpayKeyId: json['razorpay_key_id'] ?? '',
      razorpaySecret: json['razorpay_secret'] ?? '',
      expiresAt: DateTime.parse(json['expires_at'] ?? DateTime.now().toIso8601String()),
      ttlSeconds: json['ttl_seconds'] ?? 3600,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'razorpay_key_id': razorpayKeyId,
    'razorpay_secret': razorpaySecret,
    'expires_at': expiresAt.toIso8601String(),
    'ttl_seconds': ttlSeconds,
    'fetched_at': fetchedAt.toIso8601String(),
  };
}

class SecureConfigService {
  static final SecureConfigService _instance = SecureConfigService._();

  factory SecureConfigService() {
    return _instance;
  }

  SecureConfigService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      resetOnError: true,
    ),
  );

  static const String _secretsKey = 'app_secrets_config';
  static const String _refreshLockKey = 'secrets_refresh_lock';
  static const Duration _cacheDuration = Duration(hours: 1);
  static const Duration _refreshInterval = Duration(minutes: 50);

  SecretConfig? _cachedSecrets;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  /// Initialize the service and start auto-refresh
  Future<void> initialize() async {
    try {
      debugPrint('[SecureConfig] Initializing...');

      // Try to load cached secrets first
      await _loadCachedSecrets();

      // If expired or missing, fetch fresh secrets
      if (_cachedSecrets == null || _cachedSecrets!.isExpired) {
        await _fetchFreshSecrets();
      }

      // Start auto-refresh timer (refresh 10 min before expiry)
      _startRefreshTimer();

      debugPrint('[SecureConfig] Initialization complete');
    } catch (e) {
      debugPrint('[SecureConfig] Initialization error: $e');
      rethrow;
    }
  }

  /// Get current Razorpay secrets (fetches fresh if expired)
  Future<SecretConfig> getSecrets() async {
    try {
      // Return cached secrets if still valid
      if (_cachedSecrets != null && !_cachedSecrets!.isExpiringSoon) {
        debugPrint('[SecureConfig] Returning cached secrets');
        return _cachedSecrets!;
      }

      // Fetch fresh secrets if expired or expiring soon
      debugPrint('[SecureConfig] Secrets expired/expiring, fetching fresh...');
      await _fetchFreshSecrets();

      if (_cachedSecrets == null) {
        throw Exception('Failed to fetch secrets');
      }

      return _cachedSecrets!;
    } catch (e) {
      debugPrint('[SecureConfig] Error getting secrets: $e');

      // Fallback: Try to return cached secrets even if expired
      if (_cachedSecrets != null) {
        debugPrint('[SecureConfig] Using expired cached secrets as fallback');
        return _cachedSecrets!;
      }

      rethrow;
    }
  }

  /// Fetch fresh secrets from Supabase Edge Function
  Future<void> _fetchFreshSecrets() async {
    if (_isRefreshing) {
      debugPrint('[SecureConfig] Refresh already in progress, waiting...');
      // Wait for ongoing refresh to complete
      int attempts = 0;
      while (_isRefreshing && attempts < 30) {
        await Future.delayed(Duration(milliseconds: 100));
        attempts++;
      }
      return;
    }

    _isRefreshing = true;

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw Exception('User not authenticated');
      }

      // Call Supabase Edge Function
      final response = await http.get(
        Uri.parse(
          '${supabase.supabaseUrl}/functions/v1/get-secrets',
        ),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Secret fetch timeout'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _cachedSecrets = SecretConfig.fromJson(json);

        // Cache in secure storage
        await _secureStorage.write(
          key: _secretsKey,
          value: jsonEncode(_cachedSecrets!.toJson()),
        );

        debugPrint('[SecureConfig] Fresh secrets fetched and cached');
        debugPrint(
          '[SecureConfig] Secrets expire at: ${_cachedSecrets!.expiresAt}',
        );

        // Reset refresh timer
        _startRefreshTimer();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid authentication');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Only owner can access secrets');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Error: ${error['error']}');
      }
    } catch (e) {
      debugPrint('[SecureConfig] Error fetching fresh secrets: $e');
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Load secrets from device secure storage
  Future<void> _loadCachedSecrets() async {
    try {
      final cached = await _secureStorage.read(key: _secretsKey);

      if (cached != null) {
        final json = jsonDecode(cached);
        _cachedSecrets = SecretConfig.fromJson(json);

        debugPrint('[SecureConfig] Loaded cached secrets from secure storage');

        if (_cachedSecrets!.isExpired) {
          debugPrint('[SecureConfig] Cached secrets are expired');
        } else {
          debugPrint(
            '[SecureConfig] Cached secrets valid until ${_cachedSecrets!.expiresAt}',
          );
        }
      }
    } catch (e) {
      debugPrint('[SecureConfig] Error loading cached secrets: $e');
      // Ignore cache load errors; will fetch fresh
    }
  }

  /// Start timer to refresh secrets before expiry
  void _startRefreshTimer() {
    _refreshTimer?.cancel();

    if (_cachedSecrets == null) return;

    final timeUntilExpiry = _cachedSecrets!.expiresAt.difference(DateTime.now());
    final refreshIn = timeUntilExpiry - const Duration(minutes: 10);

    if (refreshIn.isNegative) {
      debugPrint('[SecureConfig] Refresh in negative time, skipping timer');
      return;
    }

    _refreshTimer = Timer(refreshIn, () {
      debugPrint('[SecureConfig] Auto-refresh timer triggered');
      _fetchFreshSecrets();
    });

    debugPrint('[SecureConfig] Auto-refresh scheduled in ${refreshIn.inMinutes} minutes');
  }

  /// Force refresh secrets immediately
  Future<void> forceRefresh() async {
    debugPrint('[SecureConfig] Force refresh requested');
    await _fetchFreshSecrets();
  }

  /// Clear cached secrets (logout scenario)
  Future<void> clearSecrets() async {
    try {
      _refreshTimer?.cancel();
      _cachedSecrets = null;
      await _secureStorage.delete(key: _secretsKey);
      debugPrint('[SecureConfig] Secrets cleared');
    } catch (e) {
      debugPrint('[SecureConfig] Error clearing secrets: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _refreshTimer?.cancel();
    debugPrint('[SecureConfig] Service disposed');
  }
}
