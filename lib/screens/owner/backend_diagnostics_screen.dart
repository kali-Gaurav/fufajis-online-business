import 'package:flutter/material.dart';
import '../../services/workflow_verification_service.dart';
import '../../utils/app_theme.dart';

/// Owner-only screen showing the health of the hybrid backend:
/// Firebase, Razorpay, Supabase, Redis, Gemini, plus AWS RDS / S3 / Bedrock
/// (proxied through Cloud Functions).
class BackendDiagnosticsScreen extends StatefulWidget {
  const BackendDiagnosticsScreen({super.key});

  @override
  State<BackendDiagnosticsScreen> createState() => _BackendDiagnosticsScreenState();
}

class _BackendDiagnosticsScreenState extends State<BackendDiagnosticsScreen> {
  final WorkflowVerificationService _verifier = WorkflowVerificationService();

  Map<String, bool>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runChecks(includeBackendHealth: false);
  }

  Future<void> _runChecks({bool includeBackendHealth = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _verifier.verifyWorkflow(includeBackendHealth: includeBackendHealth);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Backend Diagnostics', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Run live backend health check',
            onPressed: _loading ? null : () => _runChecks(includeBackendHealth: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: () => _runChecks(includeBackendHealth: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSectionHeader('Core Services'),
                      _buildStatusTile('Environment loaded', _results?['env_initialized']),
                      _buildStatusTile('Firebase initialized', _results?['firebase_initialized']),
                      _buildStatusTile('Razorpay (public key)', _results?['razorpay_configured']),
                      _buildStatusTile('Supabase', _results?['supabase_configured']),
                      _buildStatusTile('Upstash Redis cache', _results?['redis_configured']),
                      _buildStatusTile('Gemini AI', _results?['gemini_configured']),
                      _buildStatusTile('Sentry error tracking', _results?['sentry_configured']),
                      const SizedBox(height: 16),
                      _buildSectionHeader('AWS Hybrid Backend (via Cloud Functions proxy)'),
                      _buildStatusTile(
                        'RDS PostgreSQL — configured',
                        _results?['rds_configured'],
                        subtitle: _results?.containsKey('rds_reachable') == true
                            ? (_results!['rds_reachable'] == true ? 'Live connection OK' : 'Configured but unreachable')
                            : 'Tap refresh for a live check',
                      ),
                      _buildStatusTile(
                        'S3 Object Storage — configured',
                        _results?['s3_configured'],
                        subtitle: _results?.containsKey('s3_reachable') == true
                            ? (_results!['s3_reachable'] == true ? 'Live connection OK' : 'Configured but unreachable')
                            : 'Tap refresh for a live check',
                      ),
                      _buildStatusTile(
                        'Bedrock AI — configured',
                        _results?['bedrock_configured'],
                        subtitle: _results?.containsKey('bedrock_reachable') == true
                            ? (_results!['bedrock_reachable'] == true ? 'Live connection OK' : 'Configured but unreachable')
                            : 'Tap refresh for a live check',
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader('Build'),
                      _buildStatusTile('Release mode', _results?['is_release']),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'AWS credentials are never bundled in the app. RDS, S3 and Bedrock '
                          'are accessed only through Firebase Cloud Functions '
                          '(rdsQuery, getS3UploadUrl/getS3DownloadUrl, bedrockGenerate, '
                          'verifyBackendHealth), which require an admin/owner account.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
      ),
    );
  }

  Widget _buildStatusTile(String title, bool? status, {String? subtitle}) {
    final IconData icon;
    final Color color;

    if (status == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
    } else if (status) {
      icon = Icons.check_circle;
      color = AppTheme.success;
    } else {
      icon = Icons.cancel;
      color = AppTheme.error;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
      ),
    );
  }
}
