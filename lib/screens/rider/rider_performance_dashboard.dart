import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class RiderPerformanceDashboard extends StatelessWidget {
  const RiderPerformanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERFORMANCE METRICS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: _buildMetricCard('Acceptance Rate', '98%', AppTheme.success)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('On-Time Rate', '94%', AppTheme.info)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Customer Rating', '4.8', AppTheme.warning, icon: Icons.star)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('Total Deliveries', '420', AppTheme.primary)),
            ],
          ),
          
          const SizedBox(height: 32),
          const Text('RECENT INCIDENTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
          const SizedBox(height: 16),
          _buildIncidentCard('Customer Unreachable', 'ORD1011', 'Resolved', AppTheme.success),
          _buildIncidentCard('Vehicle Issue', 'ORD0984', 'Pending Review', AppTheme.warning),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 20),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildIncidentCard(String issue, String orderId, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: AppTheme.error, child: Icon(Icons.warning, color: Colors.white)),
        title: Text(issue, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Order #$orderId'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
