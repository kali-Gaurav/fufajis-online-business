import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class RiderEarningsScreen extends StatelessWidget {
  const RiderEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Total Earnings Header
          _buildTotalEarningsCard(),
          
          const SizedBox(height: 24),
          
          const Text('TODAY\'S BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey600)),
          const SizedBox(height: 12),
          
          // Section 2: Detailed Breakdown
          _buildEarningBreakdownItem('Delivery #ORD1022', 45.0, 15.0, 10.0, 0.0),
          _buildEarningBreakdownItem('Delivery #ORD1023', 45.0, 20.0, 15.0, 0.0),
          _buildEarningBreakdownItem('Delivery #ORD1024', 45.0, 10.0, 0.0, -10.0, penaltyReason: 'Late Pickup'),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.info],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Today\'s Earnings',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '₹180.00',
            style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Deliveries', '3'),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildMiniStat('Time Online', '4h 12m'),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildMiniStat('Distance', '12.5 km'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEarningBreakdownItem(String title, double base, double distance, double surge, double penalty, {String? penaltyReason}) {
    final total = base + distance + surge + penalty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Tap for transparency breakdown', style: TextStyle(fontSize: 12)),
          trailing: Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.success)),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildBreakdownRow('Base Pay', base),
            _buildBreakdownRow('Distance Bonus', distance),
            if (surge > 0) _buildBreakdownRow('Surge Bonus', surge, isPositive: true),
            if (penalty < 0) _buildBreakdownRow('Penalty (${penaltyReason ?? "N/A"})', penalty, isNegative: true),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Earned', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount, {bool isPositive = false, bool isNegative = false}) {
    Color color = Colors.black87;
    String prefix = '';
    
    if (isPositive) {
      color = AppTheme.success;
      prefix = '+';
    } else if (isNegative) {
      color = AppTheme.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text('$prefix₹${amount.abs().toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
