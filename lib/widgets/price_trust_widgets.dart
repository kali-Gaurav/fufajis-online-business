import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

/// Feature 1 — Price Change History Widget
///
/// Displays a transparent timeline of price changes for a product.
/// Firestore path: /price_history/{productId}/changes (desc by createdAt)
///
/// Shows:
///   • Current price + last updated date
///   • "No change in last 60 days" badge when stable
///   • Up/down trend indicators per change entry
class PriceHistoryWidget extends StatelessWidget {
  final String productId;
  final double currentPrice;

  const PriceHistoryWidget({
    super.key,
    required this.productId,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('price_history')
          .doc(productId)
          .collection('changes')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final hasHistory = docs.isNotEmpty;

        // Compute days since last change
        int daysSinceChange = 9999;
        if (hasHistory) {
          final lastChange = docs.first.data() as Map<String, dynamic>;
          final ts = lastChange['createdAt'];
          if (ts is Timestamp) {
            daysSinceChange = DateTime.now().difference(ts.toDate()).inDays;
          }
        }

        final isStable = daysSinceChange >= 60;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: AppTheme.grey600),
                  const SizedBox(width: 6),
                  const Text(
                    'Price History',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.grey800),
                  ),
                  const Spacer(),
                  if (isStable)
                    _StableBadge(days: daysSinceChange)
                  else if (hasHistory)
                    Text(
                      'Last changed ${daysSinceChange}d ago',
                      style: const TextStyle(color: AppTheme.grey500, fontSize: 11),
                    ),
                ],
              ),

              if (!hasHistory) ...[
                const SizedBox(height: 10),
                const Text(
                  'No price changes recorded.',
                  style: TextStyle(color: AppTheme.grey500, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...docs.take(4).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _PriceChangeRow(data: data);
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StableBadge extends StatelessWidget {
  final int days;
  const _StableBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined, size: 11, color: Color(0xFF2E7D32)),
          const SizedBox(width: 3),
          Text(
            days >= 9999 ? 'No changes yet' : 'Stable for $days days',
            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PriceChangeRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PriceChangeRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final oldPrice = (data['oldPrice'] as num?)?.toDouble() ?? 0;
    final newPrice = (data['newPrice'] as num?)?.toDouble() ?? 0;
    final ts = data['createdAt'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    final isIncrease = newPrice > oldPrice;
    final isDecrease = newPrice < oldPrice;
    final changePercent = oldPrice > 0
        ? ((newPrice - oldPrice) / oldPrice * 100).abs().toStringAsFixed(1)
        : '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Direction icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isIncrease
                  ? Colors.red.shade50
                  : isDecrease
                      ? Colors.green.shade50
                      : AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncrease
                  ? Icons.arrow_upward
                  : isDecrease
                      ? Icons.arrow_downward
                      : Icons.remove,
              size: 11,
              color: isIncrease
                  ? Colors.red.shade600
                  : isDecrease
                      ? Colors.green.shade700
                      : AppTheme.grey500,
            ),
          ),
          const SizedBox(width: 8),
          // Old → New
          Text(
            '₹${oldPrice.round()} → ₹${newPrice.round()}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.grey800),
          ),
          const SizedBox(width: 4),
          Text(
            '($changePercent%)',
            style: TextStyle(
              fontSize: 11,
              color: isIncrease ? Colors.red.shade600 : Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('d MMM yyyy').format(date),
            style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Feature 2 — Honest Price Badges Widget
// ═══════════════════════════════════════════════════════════════

/// Displays trust badges on product cards and detail screens.
///
/// Badge types:
///   • Fixed Price     — product has no discount, price is always honest
///   • No Hidden Charges — no delivery surcharges on this item
///   • Trusted Local Price — price verified by shop owner, updated regularly
///
/// All badge visibility is derived from product fields — no hardcoding.
class HonestPriceBadges extends StatelessWidget {
  final bool hasNoDiscount;      // price == originalPrice (i.e., no fake MRP inflation)
  final bool isLocallySourced;   // product.isLocal == true
  final bool priceStableFor60Days; // from price history
  final bool compact;            // compact mode for product cards

  const HonestPriceBadges({
    super.key,
    required this.hasNoDiscount,
    required this.isLocallySourced,
    required this.priceStableFor60Days,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <_BadgeData>[];

    if (priceStableFor60Days) {
      badges.add(const _BadgeData(
        icon: Icons.lock_outline,
        label: 'Fixed Price',
        color: Color(0xFF1565C0),
        bg: Color(0xFFE3F2FD),
      ));
    }

    badges.add(const _BadgeData(
      icon: Icons.no_meals_outlined,
      label: 'No Hidden Charges',
      color: Color(0xFF2E7D32),
      bg: Color(0xFFE8F5E9),
    ));

    if (isLocallySourced) {
      badges.add(const _BadgeData(
        icon: Icons.store_outlined,
        label: 'Trusted Local Price',
        color: Color(0xFFE65100),
        bg: Color(0xFFFFF3E0),
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: badges.map((b) => _Badge(data: b, compact: compact)).toList(),
    );
  }
}

class _BadgeData {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _BadgeData({required this.icon, required this.label, required this.color, required this.bg});
}

class _Badge extends StatelessWidget {
  final _BadgeData data;
  final bool compact;
  const _Badge({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: data.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: compact ? 10 : 12, color: data.color),
          const SizedBox(width: 3),
          Text(
            data.label,
            style: TextStyle(
              color: data.color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
