import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/security_event_service.dart';
import '../../services/security_risk_score_service.dart';
import '../../utils/app_theme.dart';

class SecurityHealthDashboard extends StatefulWidget {
  const SecurityHealthDashboard({super.key});

  @override
  _SecurityHealthDashboardState createState() => _SecurityHealthDashboardState();
}

class _SecurityHealthDashboardState extends State<SecurityHealthDashboard> {
  final SecurityRiskScoreService _riskService = SecurityRiskScoreService();
  final SecurityEventService _eventService = SecurityEventService();

  int _systemRiskScore = 100;
  int _transactionAnomaliesCount = 0;
  bool _isLoadingScore = true;

  @override
  void initState() {
    super.initState();
    _loadRiskScore();
  }

  Future<void> _loadRiskScore() async {
    setState(() => _isLoadingScore = true);
    final score = await _riskService.calculateSystemRiskScore(hours: 24);

    int anomalies = 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('transaction_integrity_events')
          .where('status', isEqualTo: 'UNRESOLVED')
          .count()
          .get();
      anomalies = snap.count ?? 0;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _systemRiskScore = score;
        _transactionAnomaliesCount = anomalies;
        _isLoadingScore = false;
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return AppTheme.success;
    if (score >= 70) return AppTheme.warning;
    return AppTheme.error;
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return 'Healthy';
    if (score >= 70) return 'Elevated Risk';
    return 'Critical Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Health NOC', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRiskScore)],
      ),
      body: Column(
        children: [
          _buildScoreCard(),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Recent Security Events (Last 24h)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildEventsList()),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: _isLoadingScore
            ? const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent))
            : Column(
                children: [
                  const Text('System Security Risk Score', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    '$_systemRiskScore / 100',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(_systemRiskScore),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getScoreLabel(_systemRiskScore),
                    style: TextStyle(
                      fontSize: 20,
                      color: _getScoreColor(_systemRiskScore),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _transactionAnomaliesCount > 0 ? AppTheme.error : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_transactionAnomaliesCount Unresolved Transaction Anomalies',
                        style: TextStyle(
                          fontSize: 16,
                          color: _transactionAnomaliesCount > 0 ? AppTheme.error : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _eventService.getSecurityEventsStream(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No recent security events.'));
        }

        final events = snapshot.data!;

        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final eventType = event['event'] as String? ?? 'Unknown';
            final userId = event['userId'] as String? ?? 'Unknown User';
            final deviceName = event['deviceName'] as String? ?? 'Unknown Device';
            final timestamp = event['timestamp'];

            DateTime dt = DateTime.now();
            if (timestamp != null && timestamp is Timestamp) {
              try {
                dt = timestamp.toDate();
              } catch (_) {}
            }

            return ListTile(
              leading: Icon(_getEventIcon(eventType), color: _getEventColor(eventType)),
              title: Text(eventType),
              subtitle: Text('User: $userId\nDevice: $deviceName'),
              trailing: Text(
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey),
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }

  IconData _getEventIcon(String type) {
    if (type.contains('failed') || type.contains('Failure')) return Icons.error_outline;
    if (type.contains('Lockout')) return Icons.lock;
    if (type.contains('root')) return Icons.warning;
    if (type.contains('newDevice')) return Icons.device_unknown;
    if (type.contains('Success')) return Icons.check_circle_outline;
    return Icons.security;
  }

  Color _getEventColor(String type) {
    if (type.contains('root') || type.contains('Lockout')) return AppTheme.error;
    if (type.contains('failed') || type.contains('Failure') || type.contains('Revoked'))
      return AppTheme.warning;
    if (type.contains('Success')) return AppTheme.success;
    return AppTheme.adminAccent;
  }
}
