import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/audit_logger.dart';
import '../../utils/app_theme.dart';

class SystemHealthDashboard extends StatefulWidget {
  const SystemHealthDashboard({super.key});

  @override
  State<SystemHealthDashboard> createState() => _SystemHealthDashboardState();
}

class _SystemHealthDashboardState extends State<SystemHealthDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuditLoggerService _auditService = AuditLoggerService();

  // Health Statuses
  bool _firestoreHealth = false;
  bool _authHealth = false;
  bool _apiHealth = false; // Mocking third-party APIs
  bool _functionsHealth = false; // Mocking Cloud Functions
  bool _isCheckingHealth = true;

  @override
  void initState() {
    super.initState();
    _runHealthChecks();
  }

  Future<void> _runHealthChecks() async {
    setState(() => _isCheckingHealth = true);

    // Check Firestore
    try {
      await _firestore
          .collection('system_config')
          .limit(1)
          .get(const GetOptions(source: Source.server));
      _firestoreHealth = true;
    } catch (_) {
      _firestoreHealth = false;
    }

    // Check Auth
    _authHealth = _auth.currentUser != null;

    // Simulate third-party checks (Twilio, Razorpay, etc.)
    await Future.delayed(const Duration(milliseconds: 500));
    _apiHealth = true;
    _functionsHealth = true;

    if (mounted) {
      setState(() => _isCheckingHealth = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enterprise Command Center',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _runHealthChecks)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Live Operations Stream'),
            const SizedBox(height: 16),
            _buildLiveMetricsPanel(),

            const SizedBox(height: 32),
            _buildSectionTitle('System Health Overview'),
            const SizedBox(height: 16),
            _buildHealthGrid(),

            const SizedBox(height: 32),
            _buildSectionTitle('Security Command Center'),
            const SizedBox(height: 16),
            _buildSecurityPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildLiveMetricsPanel() {
    return Row(
      children: [
        Expanded(child: _buildLiveOrderCount()),
        const SizedBox(width: 16),
        Expanded(child: _buildLiveEmployeeCount()),
      ],
    );
  }

  Widget _buildLiveOrderCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }
        return _buildMetricCard(
          title: 'Live Pending Orders',
          value: count.toString(),
          icon: Icons.shopping_bag,
          color: AppTheme.warning,
        );
      },
    );
  }

  Widget _buildLiveEmployeeCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'UserRole.employee')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }
        return _buildMetricCard(
          title: 'Active Employees',
          value: count.toString(),
          icon: Icons.badge,
          color: AppTheme.info,
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthGrid() {
    if (_isCheckingHealth) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: [
            _buildHealthIndicator('Firestore DB', _firestoreHealth),
            _buildHealthIndicator('Authentication', _authHealth),
            _buildHealthIndicator('Cloud Functions', _functionsHealth),
            _buildHealthIndicator('3rd Party APIs', _apiHealth),
          ],
        );
      },
    );
  }

  Widget _buildHealthIndicator(String serviceName, bool isHealthy) {
    return Container(
      decoration: BoxDecoration(
        color: isHealthy
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHealthy ? AppTheme.success : AppTheme.error, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.error,
            color: isHealthy ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              serviceName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isHealthy ? AppTheme.success : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityPanel() {
    return FutureBuilder<List<AuditLog>>(
      future: _auditService.getRecentLogs(limit: 5, filterType: AuditActionType.securityEvent),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (snapshot.hasError) {
          return const Text('Failed to load security events.');
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shield, size: 48, color: AppTheme.success),
                    SizedBox(height: 16),
                    Text(
                      'No recent security threats detected',
                      style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: const Icon(Icons.warning, color: AppTheme.error),
                title: Text(
                  log.action,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error),
                ),
                subtitle: Text('User ID: ${log.userId} • Device: ${log.deviceInfo}'),
                trailing: Text(
                  _formatTimeAgo(log.timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
