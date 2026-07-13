import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class InventoryAutomationWidget extends StatelessWidget {
  const InventoryAutomationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Automation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'SMART',
                  style: TextStyle(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTask('Voice-to-Stock', 'Ready', Icons.mic),
          const SizedBox(height: 12),
          _buildTask('Auto-Discounts', '3 items markdown', Icons.trending_down),
          const SizedBox(height: 12),
          _buildTask('Supplier POs', 'Pending approval', Icons.request_quote),
        ],
      ),
    );
  }

  Widget _buildTask(String title, String status, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.grey500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(status, style: const TextStyle(fontSize: 11, color: AppTheme.grey600)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, size: 16, color: AppTheme.grey400),
      ],
    );
  }
}
