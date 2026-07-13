import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class QualityComplianceScreen extends StatefulWidget {
  const QualityComplianceScreen({Key? key}) : super(key: key);

  @override
  State<QualityComplianceScreen> createState() =>
      _QualityComplianceScreenState();
}

class _QualityComplianceScreenState
    extends State<QualityComplianceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _audits = [
    {
      'id': 'audit_001',
      'type': 'Warehouse Quality',
      'date': DateTime(2026, 7, 11, 9, 30),
      'inspector': 'Rajesh Kumar',
      'score': 95,
      'status': 'completed',
      'issues': 1,
      'items_checked': 250,
    },
    {
      'id': 'audit_002',
      'type': 'Food Safety Compliance',
      'date': DateTime(2026, 7, 10, 14, 0),
      'inspector': 'Priya Singh',
      'score': 92,
      'status': 'completed',
      'issues': 2,
      'items_checked': 180,
    },
    {
      'id': 'audit_003',
      'type': 'Packaging Standards',
      'date': DateTime(2026, 7, 12, 10, 0),
      'inspector': 'Amit Patel',
      'score': 0,
      'status': 'scheduled',
      'issues': 0,
      'items_checked': 0,
    },
  ];

  final List<Map<String, dynamic>> _issues = [
    {
      'id': 'issue_001',
      'title': 'Temperature Deviation Zone A',
      'severity': 'high',
      'date': DateTime(2026, 7, 11, 11, 0),
      'status': 'open',
      'description': 'Temperature exceeded 15°C in produce zone',
      'assignedTo': 'Rajesh Kumar',
      'dueDate': DateTime(2026, 7, 12),
    },
    {
      'id': 'issue_002',
      'title': 'Missing Labels on Dairy Products',
      'severity': 'medium',
      'date': DateTime(2026, 7, 10, 15, 30),
      'status': 'in_progress',
      'description': 'Some dairy items missing expiry date labels',
      'assignedTo': 'Priya Singh',
      'dueDate': DateTime(2026, 7, 13),
    },
    {
      'id': 'issue_003',
      'title': 'Hygiene Violation in Packing Area',
      'severity': 'high',
      'date': DateTime(2026, 7, 9, 13, 0),
      'status': 'resolved',
      'description': 'Staff not following hand-washing protocol',
      'assignedTo': 'Amit Patel',
      'dueDate': DateTime(2026, 7, 11),
    },
  ];

  final List<Map<String, dynamic>> _certifications = [
    {
      'id': 'cert_001',
      'name': 'FSSAI Certification',
      'issueDate': DateTime(2024, 6, 15),
      'expiryDate': DateTime(2027, 6, 14),
      'status': 'active',
      'authority': 'Food Safety Authority of India',
    },
    {
      'id': 'cert_002',
      'name': 'ISO 9001:2015',
      'issueDate': DateTime(2023, 3, 20),
      'expiryDate': DateTime(2026, 3, 19),
      'status': 'active',
      'authority': 'International Organization for Standardization',
    },
    {
      'id': 'cert_003',
      'name': 'Cold Chain Management',
      'issueDate': DateTime(2025, 1, 10),
      'expiryDate': DateTime(2026, 1, 9),
      'status': 'expiring_soon',
      'authority': 'Department of Food Safety',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Quality & Compliance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(child: Text('Generate Report')),
              const PopupMenuItem(child: Text('Schedule Audit')),
              const PopupMenuItem(child: Text('View History')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Audits'),
            Tab(text: 'Issues'),
            Tab(text: 'Certifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAuditsTab(),
          _buildIssuesTab(),
          _buildCertificationsTab(),
        ],
      ),
    );
  }

  Widget _buildAuditsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComplianceStats(),
          const SizedBox(height: 20),
          const Text(
            'Recent Audits',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._audits.map((audit) => _buildAuditCard(audit)).toList(),
        ],
      ),
    );
  }

  Widget _buildComplianceStats() {
    final avgScore = _audits
        .where((a) => a['score'] > 0)
        .fold<double>(0, (sum, a) => sum + (a['score'] as int)) /
        _audits.where((a) => a['score'] > 0).length;
    final completed = _audits.where((a) => a['status'] == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Avg Score',
            value: avgScore.toStringAsFixed(1),
            icon: Icons.trending_up,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Completed',
            value: completed.toString(),
            icon: Icons.check_circle,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Issues',
            value: _issues.where((i) => i['status'] != 'resolved').length.toString(),
            icon: Icons.warning,
            color: AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Compliance',
            value: '${(avgScore / 100 * 100).toStringAsFixed(0)}%',
            icon: Icons.verified,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> audit) {
    final isCompleted = audit['status'] == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit['type'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(audit['date']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${audit['score']}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SCHEDULED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inspector',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          audit['inspector'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Items Checked',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${audit['items_checked']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issues Found',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.grey600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${audit['issues']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: audit['issues'] > 0
                                ? AppTheme.error
                                : AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: audit['score'] / 100,
                  minHeight: 6,
                  backgroundColor: AppTheme.grey200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    audit['score'] >= 90
                        ? AppTheme.success
                        : (audit['score'] >= 80 ? Colors.orange : AppTheme.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIssueStats(),
          const SizedBox(height: 20),
          const Text(
            'Issues Log',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._issues.map((issue) => _buildIssueCard(issue)).toList(),
        ],
      ),
    );
  }

  Widget _buildIssueStats() {
    final open = _issues.where((i) => i['status'] == 'open').length;
    final inProgress = _issues.where((i) => i['status'] == 'in_progress').length;
    final resolved = _issues.where((i) => i['status'] == 'resolved').length;
    final high = _issues.where((i) => i['severity'] == 'high').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Open',
            value: open.toString(),
            icon: Icons.error,
            color: AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'In Progress',
            value: inProgress.toString(),
            icon: Icons.sync,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Resolved',
            value: resolved.toString(),
            icon: Icons.check_circle,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'High Priority',
            value: high.toString(),
            icon: Icons.priority_high,
            color: AppTheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildIssueCard(Map<String, dynamic> issue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd').format(issue['date']),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSeverityBadge(issue['severity']),
                const SizedBox(width: 8),
                _buildStatusBadge(issue['status']),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                issue['description'],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned to',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        issue['assignedTo'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Due Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd').format(issue['dueDate']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color bgColor;
    Color textColor;
    IconData icon;

    if (severity == 'high') {
      bgColor = AppTheme.error.withOpacity(0.1);
      textColor = AppTheme.error;
      icon = Icons.error;
    } else {
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange[700]!;
      icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 2),
          Text(
            severity.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'open':
        bgColor = AppTheme.error.withOpacity(0.1);
        textColor = AppTheme.error;
        label = 'Open';
        break;
      case 'in_progress':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange[700]!;
        label = 'Progress';
        break;
      case 'resolved':
        bgColor = AppTheme.success.withOpacity(0.1);
        textColor = AppTheme.success;
        label = 'Resolved';
        break;
      default:
        bgColor = AppTheme.grey200;
        textColor = AppTheme.grey600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCertificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Certifications & Licenses',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._certifications.map((cert) => _buildCertificateCard(cert)).toList(),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(Map<String, dynamic> cert) {
    final daysUntilExpiry = cert['expiryDate'].difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry <= 90 && daysUntilExpiry > 0;
    final isExpired = daysUntilExpiry < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cert['authority'],
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? AppTheme.error.withOpacity(0.1)
                        : (isExpiringSoon
                            ? Colors.amber.withOpacity(0.1)
                            : AppTheme.success.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExpired
                        ? 'EXPIRED'
                        : (isExpiringSoon ? 'EXPIRING SOON' : 'ACTIVE'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isExpired
                          ? AppTheme.error
                          : (isExpiringSoon ? Colors.amber : AppTheme.success),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Issue Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy').format(cert['issueDate']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expiry Date',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy').format(cert['expiryDate']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Days Left',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isExpired ? 'Expired' : '$daysUntilExpiry days',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isExpired
                              ? AppTheme.error
                              : (isExpiringSoon
                                  ? Colors.orange
                                  : AppTheme.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
