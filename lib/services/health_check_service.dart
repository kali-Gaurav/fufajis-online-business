// ============================================================
//  HealthCheckService — lightweight runtime health probes
//
//  Provides a fast, client-side health snapshot of the services
//  Fufaji depends on: Firebase, Supabase (Postgres), Redis
//  (Upstash via CacheService), S3 (via Cloud Functions proxy),
//  and general internet connectivity.
//
//  Intended for an owner-facing health dashboard
//  (Permission.viewHealthDashboard) and for startup diagnostics.
//  Each check is wrapped so a single failing dependency cannot
//  throw or block the others — `checkAll()` always resolves.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';
import 'workflow_verification_service.dart';
import '../config/supabase_config.dart';

enum HealthState { ok, degraded, down }

class HealthStatus {
  final HealthState state;
  final String message;
  final int? latencyMs;

  const HealthStatus({required this.state, required this.message, this.latencyMs});

  bool get isOk => state == HealthState.ok;

  Map<String, dynamic> toMap() => {
        'state': state.name,
        'message': message,
        'latencyMs': latencyMs,
      };
}

class HealthCheckService {
  static final HealthCheckService _instance = HealthCheckService._internal();
  factory HealthCheckService() => _instance;
  HealthCheckService._internal();

  /// Runs all health checks concurrently and returns a map keyed by
  /// service name: firebase, supabase, redis, s3, internet.
  /// Each check is wrapped to prevent any single failure from crashing others.
  Future<Map<String, HealthStatus>> checkAll({bool includeS3 = true}) async {
    try {
      final futures = <String, Future<HealthStatus>>{
        'firebase': _checkFirebase(),
        'supabase': _checkSupabase(),
        'redis': _checkRedis(),
        'internet': _checkInternet(),
      };
      if (includeS3) {
        futures['s3'] = _checkS3();
      }

      final results = <String, HealthStatus>{};
      for (final entry in futures.entries) {
        try {
          results[entry.key] = await entry.value;
        } catch (e) {
          results[entry.key] = HealthStatus(state: HealthState.down, message: 'Check threw: $e');
        }
      }
      return results;
    } catch (e) {
      // Catch-all: if anything goes wrong, return a safe default
      return {
        'error': HealthStatus(state: HealthState.down, message: 'Health check system error: $e'),
      };
    }
  }

  /// Convenience: true only if every checked service is at least
  /// `degraded` (i.e. nothing is fully `down`).
  bool allHealthy(Map<String, HealthStatus> results) {
    return results.values.every((s) => s.state != HealthState.down);
  }

  // ----------------------------------------------------------
  // Individual checks
  // ----------------------------------------------------------

  Future<HealthStatus> _checkFirebase() async {
    final sw = Stopwatch()..start();
    try {
      if (Firebase.apps.isEmpty) {
        return const HealthStatus(state: HealthState.down, message: 'Firebase not initialized');
      }
      return HealthStatus(
        state: HealthState.ok,
        message: 'Firebase initialized (${Firebase.apps.length} app(s))',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return HealthStatus(state: HealthState.down, message: 'Error: $e');
    }
  }

  Future<HealthStatus> _checkSupabase() async {
    final sw = Stopwatch()..start();
    try {
      // CRITICAL: Check isAvailable before accessing client to prevent LateInitializationError
      if (!SupabaseConfig.isAvailable) {
        return const HealthStatus(
          state: HealthState.down,
          message: 'Supabase not configured (missing URL/Anon Key)',
        );
      }

      // Double-check: wrap client access in try-catch to handle any initialization errors
      SupabaseClient? client;
      try {
        client = SupabaseConfig.client;
      } catch (e) {
        return HealthStatus(
          state: HealthState.down,
          message: 'Supabase client unavailable: $e',
        );
      }

      // Cheap reachability probe: select a single row's id from a
      // small table. Errors (including RLS denials) still confirm
      // the API is reachable, so treat PostgrestException as degraded
      // rather than down.
      await client.from('categories').select('id').limit(1);
      sw.stop();
      return HealthStatus(
        state: HealthState.ok,
        message: 'Supabase reachable',
        latencyMs: sw.elapsedMilliseconds,
      );
    } on PostgrestException catch (e) {
      sw.stop();
      return HealthStatus(
        state: HealthState.degraded,
        message: 'Supabase reachable but query failed: ${e.message}',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return HealthStatus(state: HealthState.down, message: 'Supabase unreachable: $e');
    }
  }

  Future<HealthStatus> _checkRedis() async {
    final sw = Stopwatch()..start();
    try {
      final cache = CacheService();
      const probeKey = '__health_check_probe__';
      final ok = await cache.set(probeKey, DateTime.now().toIso8601String());
      final readBack = await cache.get(probeKey);
      sw.stop();

      if (ok && readBack != null) {
        return HealthStatus(
          state: HealthState.ok,
          message: 'Cache read/write succeeded',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      return HealthStatus(
        state: HealthState.degraded,
        message: 'Cache write succeeded but read-back failed (likely on local/Firestore fallback)',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      return HealthStatus(state: HealthState.down, message: 'Cache error: $e');
    }
  }

  Future<HealthStatus> _checkS3() async {
    final sw = Stopwatch()..start();
    try {
      final health = await WorkflowVerificationService().fetchBackendHealth();
      sw.stop();
      if (health == null) {
        return const HealthStatus(
          state: HealthState.degraded,
          message: 'Backend health check unavailable (not admin or offline)',
        );
      }
      final s3 = Map<String, dynamic>.from(health['s3'] as Map? ?? {});
      if (s3['reachable'] == true) {
        return HealthStatus(state: HealthState.ok, message: 'S3 reachable', latencyMs: sw.elapsedMilliseconds);
      }
      return const HealthStatus(state: HealthState.down, message: 'S3 not reachable');
    } catch (e) {
      return HealthStatus(state: HealthState.down, message: 'S3 check error: $e');
    }
  }

  Future<HealthStatus> _checkInternet() async {
    final sw = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 5));
      sw.stop();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return HealthStatus(
          state: HealthState.ok,
          message: 'Internet reachable',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      return HealthStatus(
        state: HealthState.degraded,
        message: 'Unexpected status ${response.statusCode}',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      debugPrint('[HealthCheckService] Internet check failed: $e');
      return const HealthStatus(state: HealthState.down, message: 'No internet connectivity');
    }
  }
}
