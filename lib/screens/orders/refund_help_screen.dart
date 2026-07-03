import 'package:flutter/material.dart';

class RefundHelpScreen extends StatelessWidget {
  const RefundHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund & Returns'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ExpansionTile(
            title: Text('When can I request a refund?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You can request a refund for:\n\n'
                  '• Food quality issues (cold, wrong item, spoiled)\n'
                  '• Delivery issues (very late, damaged packaging)\n'
                  '• Missing items from your order\n\n'
                  'Refunds cannot be requested for:\n'
                  '• Change of mind (after 1 minute of order)\n'
                  '• Allergies (you didn\'t inform shop)\n'
                  '• Taste preferences',
                  style: TextStyle(height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const ExpansionTile(
            title: Text('How long does refund take?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '💚 Instant refund to your Fufaji wallet (5 seconds)\n\n'
                  '🏦 Withdraw to bank: 2-3 business days\n\n'
                  'Chat support can approve refunds while you wait.',
                  style: TextStyle(height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const ExpansionTile(
            title: Text('How do I request a refund?'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Open your order', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('2. Tap "Return/Refund"'),
                    SizedBox(height: 8),
                    Text('3. Select reason & upload photo (optional)'),
                    SizedBox(height: 8),
                    Text('4. Submit request'),
                    SizedBox(height: 16),
                    Text(
                      'Most refunds approved within 5 minutes. '
                      'If not approved instantly, chat with support.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('Request Refund for This Order'),
            onPressed: () => _showRefundRequest(context),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat),
            label: const Text('Chat with Support'),
            onPressed: () => _openChat(context),
          ),
        ],
      ),
    );
  }

  void _showRefundRequest(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Refund request submitted')));
  }

  void _openChat(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening chat with support team')));
  }
}
