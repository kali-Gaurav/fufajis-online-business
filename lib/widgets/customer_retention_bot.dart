import 'package:flutter/material.dart';

class CustomerRetentionBot extends StatelessWidget {
  const CustomerRetentionBot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[700]!, Colors.teal[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_search, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Churn Warning',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '3 regular customers haven\'t ordered this week',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCustomerItem('Mahendra Singh (Bassi)', 'Last ordered: 10 days ago'),
          const SizedBox(height: 8),
          _buildCustomerItem('Vikram Yadav (Shahpura)', 'Last ordered: 8 days ago'),
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Suggestion: Send a "Personal Discount" WhatsApp note?',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📲 Personal discount vouchers sent to 3 customers via WhatsApp.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                },
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Send All', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal[700],
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(String name, String detail) {
    return Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('Call Now', style: TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.underline)),
        ),
      ],
    );
  }
}
