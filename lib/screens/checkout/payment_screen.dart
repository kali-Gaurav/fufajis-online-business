import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'upi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Payment Method'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Security Assurance Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user, color: Colors.green, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🔒 Your payment is safe. Razorpay handles all payments (PCI certified).',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // UPI Method
            _buildPaymentMethodCard(
              icon: '₹',
              title: 'UPI',
              subtitle: 'PhonePe, Google Pay, BHIM, Paytm',
              isSelected: selectedMethod == 'upi',
              onTap: () => setState(() => selectedMethod = 'upi'),
            ),
            const SizedBox(height: 12),

            // Card Method
            _buildPaymentMethodCard(
              icon: '💳',
              title: 'Credit/Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
              badges: ['🔒 Encrypted', '✓ PCI-DSS', '🏦 Razorpay'],
              isSelected: selectedMethod == 'card',
              onTap: () => setState(() => selectedMethod = 'card'),
            ),
            const SizedBox(height: 12),

            // Wallet Method
            _buildPaymentMethodCard(
              icon: '👛',
              title: 'Fufaji Wallet',
              subtitle: 'Use your wallet balance',
              isSelected: selectedMethod == 'wallet',
              onTap: () => setState(() => selectedMethod = 'wallet'),
            ),
            const SizedBox(height: 12),

            // COD Method
            _buildPaymentMethodCard(
              icon: '🚚',
              title: 'Cash on Delivery',
              subtitle: 'Pay when food arrives',
              isSelected: selectedMethod == 'cod',
              onTap: () => setState(() => selectedMethod = 'cod'),
            ),
            const SizedBox(height: 24),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _processPayment(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        'Complete Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '💚 Money-back guarantee if order doesn\'t arrive',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required String icon,
    required String title,
    required String subtitle,
    List<String>? badges,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            if (badges != null && badges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: badges
                    .map(
                      (badge) => Chip(
                        label: Text(badge, style: const TextStyle(fontSize: 10)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _processPayment() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Processing payment via $selectedMethod')));
  }
}
