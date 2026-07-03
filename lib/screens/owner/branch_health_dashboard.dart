import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/operational_status.dart';
import '../../models/operational_health_model.dart';

class BranchHealthDashboard extends StatelessWidget {
  final OperationalHealthModel health;

  const BranchHealthDashboard({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Text(
          '${health.branchId} Health',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Score
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: health.overallScore / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade300,
                      color: _getColor(health.overallScore),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        health.overallScore.toInt().toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _getColor(health.overallScore),
                        ),
                      ),
                      const Text('Overall Score', style: TextStyle(color: AppTheme.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Detailed Breakdown
            const Text(
              'HEALTH BREAKDOWN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            _buildHealthCategory('Inventory Health', health.inventoryHealth, Icons.inventory),
            _buildHealthCategory(
              'Delivery Operations',
              health.deliveryHealth,
              Icons.local_shipping,
            ),
            _buildHealthCategory('Workforce & Staffing', health.employeeHealth, Icons.people),
            _buildHealthCategory('Supplier Reliability', health.supplierHealth, Icons.business),
            _buildHealthCategory('Customer Satisfaction', health.customerHealth, Icons.favorite),
            _buildHealthCategory(
              'Financial Performance',
              health.financialHealth,
              Icons.attach_money,
            ),

            const SizedBox(height: 32),
            const Text(
              'RECOMMENDED ACTIONS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            if (health.inventoryHealth < 80)
              _buildActionCard(
                context,
                'Inventory Low',
                'Audit top 10 fast-moving SKUs. Order pending PRs.',
                OperationalStatus.critical,
              ),
            if (health.deliveryHealth < 80)
              _buildActionCard(
                context,
                'SLA Breaches',
                'Rebalance riders. 3 riders have > 5 tasks.',
                OperationalStatus.warning,
              ),
            if (health.employeeHealth < 80)
              _buildActionCard(
                context,
                'Staff Absenteeism',
                'Contact 2 employees currently marked as absent.',
                OperationalStatus.warning,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCategory(String title, double score, IconData icon) {
    Color color = _getColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppTheme.grey600, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${score.toInt()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade300,
              color: color,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    OperationalStatus status,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: status.color.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(status.icon, color: status.color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Contact Manager tapped')));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: status.color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Fix'),
        ),
      ),
    );
  }

  Color _getColor(double score) {
    if (score < 70) return OperationalStatus.critical.color;
    if (score < 85) return OperationalStatus.warning.color;
    return OperationalStatus.healthy.color;
  }
}
