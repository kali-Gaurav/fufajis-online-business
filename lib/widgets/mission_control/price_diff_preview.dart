import 'package:flutter/material.dart';

/// Price Diff Preview Component
/// Shows side-by-side comparison of current price vs. suggested price
class PriceDiffPreview extends StatelessWidget {
  final double currentPrice;
  final double suggestedPrice;
  final double changePercent;

  const PriceDiffPreview({
    super.key,
    required this.currentPrice,
    required this.suggestedPrice,
    required this.changePercent,
  });

  Color get _changeColor {
    if (changePercent > 0) return Colors.green;
    if (changePercent < 0) return Colors.blue;
    return Colors.grey;
  }

  String get _changeLabel {
    if (changePercent > 0) {
      return '+${changePercent.toStringAsFixed(1)}%';
    } else if (changePercent < 0) {
      return '${changePercent.toStringAsFixed(1)}%';
    }
    return 'No change';
  }

  String get _changeArrow {
    if (changePercent > 0) return '↑';
    if (changePercent < 0) return '↓';
    return '→';
  }

  @override
  Widget build(BuildContext context) {
    final priceDifference = suggestedPrice - currentPrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: _changeColor.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Current Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current Price', style: Theme.of(context).textTheme.labelMedium),
              Text(
                '₹${currentPrice.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Arrow with change info
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                // Arrow
                Text(
                  _changeArrow,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _changeColor),
                ),

                const SizedBox(height: 8),

                // Change amount and percent
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: priceDifference >= 0 ? '+' : '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _changeColor,
                        ),
                      ),
                      TextSpan(
                        text: '₹${priceDifference.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _changeColor,
                        ),
                      ),
                      TextSpan(
                        text: ' ($_changeLabel)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _changeColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Suggested Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested Price',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _changeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹${suggestedPrice.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _changeColor,
                  ),
                ),
              ),
            ],
          ),

          // Footer note
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _changeColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: _changeColor.withOpacity(0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    changePercent > 0
                        ? 'Increase applies scarcity or demand premium'
                        : changePercent < 0
                        ? 'Decrease aims to clear inventory or boost velocity'
                        : 'Price remains stable',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _changeColor.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
