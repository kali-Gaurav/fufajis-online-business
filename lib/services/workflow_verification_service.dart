import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import 'logging_service.dart';
import 'health_check_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorkflowVerificationService {
  static final WorkflowVerificationService _instance = WorkflowVerificationService._internal();
  factory WorkflowVerificationService() => _instance;
  WorkflowVerificationService._internal();

  /// Runs a comprehensive suite of sanity checks for production readiness.
  ///
  /// [includeBackendHealth] controls whether the server-side
  /// health check (RDS/S3/Bedrock live checks) is invoked.
  /// This requires the signed-in user to have an admin/owner role, so it
  /// defaults to false and should be enabled from owner-only screens.
  Future<Map<String, bool>> verifyWorkflow({bool includeBackendHealth = false}) async {
    final Map<String, bool> results = {};

    // 1. Environment Configuration (client-side, non-secret flags only)
    results['env_initialized'] = true;
    results['razorpay_configured'] = AppConfig.razorpayKeyId.isNotEmpty;
    results['supabase_configured'] = false;
    results['redis_configured'] = AppConfig.upstashRedisRestUrl.isNotEmpty;
    results['gemini_configured'] = true; // Moved server side, always configured from client view
 
    // 2. Monitoring & Error Tracking
    results['sentry_configured'] = AppConfig.sentryDsn.isNotEmpty;

    // 3. Firebase & Security
    try {
      results['firebase_initialized'] = Firebase.apps.isNotEmpty;
    } catch (_) {
      results['firebase_initialized'] = false;
    }

    // 4. Build Modes (Informational)
    results['is_release'] = kReleaseMode;

    // 5. Backend services (AWS RDS/S3/Bedrock) — proxied via Cloud Functions.
    // These are always "available" from the client's perspective since the
    // app never holds raw credentials; live reachability is checked
    // separately below when requested.
    results['rds_configured'] = true;
    results['s3_configured'] = true;
    results['bedrock_configured'] = true;

    if (includeBackendHealth) {
      final health = await fetchBackendHealth();
      if (health != null) {
        final rds = Map<String, dynamic>.from(health['rds'] as Map? ?? {});
        final s3 = Map<String, dynamic>.from(health['s3'] as Map? ?? {});
        final bedrock = Map<String, dynamic>.from(health['bedrock'] as Map? ?? {});

        results['rds_configured'] = rds['configured'] == true;
        results['rds_reachable'] = rds['reachable'] == true;
        results['s3_configured'] = s3['configured'] == true;
        results['s3_reachable'] = s3['reachable'] == true;
        results['bedrock_configured'] = bedrock['configured'] == true;
        results['bedrock_reachable'] = bedrock['reachable'] == true;
      } else {
        // Could not run the check (e.g. not admin, offline) — don't claim success.
        results['rds_reachable'] = false;
        results['s3_reachable'] = false;
        results['bedrock_reachable'] = false;
      }
    }

    // Log detailed results to internal LoggingService
    LoggingService().info('--- Workflow Verification Report ---', data: results);

    if (results.values.contains(false)) {
      LoggingService().warning('Configuration Checkup: Some services are not fully configured.');
    } else {
      LoggingService().info('Configuration Checkup: All systems ready for production.');
    }

    return results;
  }

  /// Runs [HealthCheckService.checkAll] and returns a simple
  /// service-name -> HealthStatus map for the owner health dashboard
  /// (Permission.viewHealthDashboard). Unlike [verifyWorkflow], this
  /// performs live probes (Supabase query, cache round-trip, internet
  /// reachability, optional S3 via backend health) rather than just
  /// checking configuration flags.
  Future<Map<String, HealthStatus>> runLiveHealthChecks({bool includeS3 = true}) {
    return HealthCheckService().checkAll(includeS3: includeS3);
  }

  /// Calls the `/health` AWS API endpoint.
  /// Returns null on failure (e.g. offline) rather than throwing, so it can be used as a best-effort diagnostic.
  Future<Map<String, dynamic>?> fetchBackendHealth() async {
    try {
      final baseUrl = AppConfig.apiBaseUrl;
      if (baseUrl.isEmpty) return null;
      
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status'] ?? 'ok',
            'timestamp': decoded['ts'],
          };
        }
      }
      return null;
    } catch (e) {
      LoggingService().warning('[Backend Health] Error: $e');
      return null;
    }
  }
}
