import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/product_provider_extensions.dart';
import '../../utils/app_theme.dart';

/// Dynamic Pricing Widget
/// Displays dynamic pricing metrics on the owner dashboard
class DynamicPricingWidget extends StatefulWidget {
  const DynamicPricingWidget({super.key});

  @override
  State<DynamicPricingWidget> createState() => _DynamicPricingWidgetState();
}

class _DynamicPricingWidgetState extends State<DynamicPricingWidget> {
  Map<String, dynamic> _pricingData = {};

  @override
  void initState() {
    super.initState();
    _loadPricingData();
  }

  Future<void> _loadPricingData() async {
    try {
      final provider = context.read<ProductProvider>();
      final rules = await provider.getPricingRules();
      final pendingChanges = await provider.getPendingPriceChanges();

      setState(() {
        _pricingData = {
          'strategy': rules['strategy'] ?? 'Match',
          'pendingChanges': pendingChanges.length,
          'revenueImpact': rules['revenueImpact'] ?? 0.0,
        };
      });
    } catch (e) {
      debugPrint('Error loading pricing data: $e');
    }
  }

  Color _getStrategyColor(String strategy) {
    switch (strategy) {
      case 'Beat':
        return AppTheme.success;
      case 'Match':
        return AppTheme.info;
      case 'Premium':
        return Colors.purple;
      case 'Cost+':
        return AppTheme.warning;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String strategy = _pricingData['strategy'] as String? ?? 'Match';
    final int pendingChanges = (_pricingData['pendingChanges'] as num? ?? 0).toInt();
    final double revenueImpact = (_pricingData['revenueImpact'] as num? ?? 0.0).toDouble();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStrategyColor(strategy).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.trending_up, color: _getStrategyColor(strategy), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Dynamic Pricing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _loadPricingData,
                  child: Icon(Icons.refresh, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Current Strategy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStrategyColor(strategy).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStrategyColor(strategy),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Strategy: $strategy',
                    style: TextStyle(
                      color: _getStrategyColor(strategy),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Changes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pendingChanges.toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Revenue Impact', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      '${revenueImpact > 0 ? '+' : ''}${revenueImpact.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: revenueImpact > 0 ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/pricing-rules');
                    },
                    child: const Text('Rules'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/pending-price-changes');
                    },
                    child: const Text('Changes'),
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
