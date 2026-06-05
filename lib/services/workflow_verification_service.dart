import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'logging_service.dart';

class WorkflowVerificationService {
  static final WorkflowVerificationService _instance = WorkflowVerificationService._internal();
  factory WorkflowVerificationService() => _instance;
  WorkflowVerificationService._internal();

  /// Runs a comprehensive suite of sanity checks for production readiness
  Future<Map<String, bool>> verifyWorkflow() async {
    final Map<String, bool> results = {};
    
    // 1. Check .env configuration
    results['env_loaded'] = dotenv.isInitialized;
    results['gemini_api_key'] = dotenv.get('GEMINI_API_KEY', fallback: '').isNotEmpty;
    results['razorpay_key'] = dotenv.get('RAZORPAY_KEY_ID', fallback: '').isNotEmpty;
    results['sentry_dsn'] = const String.fromEnvironment('SENTRY_DSN').isNotEmpty || dotenv.get('SENTRY_DSN', fallback: '').isNotEmpty;

    // 2. Check Platform Settings
    results['debug_mode'] = kDebugMode;
    results['profile_mode'] = kProfileMode;
    results['release_mode'] = kReleaseMode;

    // 3. Log results
    LoggingService().info('Workflow Verification Complete', data: results);
    
    if (results.values.contains(false)) {
      LoggingService().warning('Workflow Verification found missing configurations!');
    }

    return results;
  }
}
