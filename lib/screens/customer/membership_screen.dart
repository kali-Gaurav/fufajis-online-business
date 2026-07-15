import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Customer Membership / Premium plans screen.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Fufaji Membership', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PlanCard(
            name: 'Basic',
            price: 'Free',
            color: Colors.grey.shade700,
            benefits: const ['Standard delivery times', 'Basic customer support', 'Order tracking'],
            isCurrent: true,
          ),
          const SizedBox(height: 12),
          const _PlanCard(
            name: 'Silver',
            price: 'Rs. 99 / month',
            color: AppTheme.infoGrey,
            benefits: [
              'Priority delivery',
              '5% cashback on orders',
              'Dedicated support',
              'Early access to offers',
            ],
          ),
          const SizedBox(height: 12),
          const _PlanCard(
            name: 'Gold',
            price: 'Rs. 199 / month',
            color: Color(0xFFB8860B),
            benefits: [
              'Express delivery (30 min)',
              '10% cashback on orders',
              '24/7 priority support',
              'Exclusive member deals',
              'Free delivery on all orders',
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final Color color;
  final List<String> benefits;
  final bool isCurrent;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.color,
    required this.benefits,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Current Plan',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...benefits.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
          if (!isCurrent) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Upgrading to $name — coming soon!'),
                    backgroundColor: color,
                  ),
                ),
                child: Text('Upgrade to $name'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
