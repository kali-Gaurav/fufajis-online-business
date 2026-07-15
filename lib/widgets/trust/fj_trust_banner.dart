import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Fufaji's Trust Banner — Core differentiator
/// Displays 3 key trust signals:
/// ✓ Honest Pricing (no fake discounts)
/// 🌾 Farm Direct (fair prices)
/// ⚡ Fresh Daily (restocked)
///
/// This component appears on Home & Product screens.
/// Business Impact: Communicates Fufaji's core value proposition.

class FjTrustBanner extends StatelessWidget {
  final List<TrustBadge> badges;
  final Color backgroundColor;
  final EdgeInsets padding;

  const FjTrustBanner({
    super.key,
    required this.badges,
    this.backgroundColor = AppTheme.cream,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Why Fufaji is Different',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.grey900,
                  ),
                ),
              ],
            ),
          ),

          // Badges Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.7,
            children: badges.map((badge) {
              return _TrustBadgeItem(badge: badge);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Individual Trust Badge
class TrustBadge {
  final String icon; // Emoji
  final String title;
  final String description;
  final Color? accentColor;

  TrustBadge({
    required this.icon,
    required this.title,
    required this.description,
    this.accentColor,
  });
}

class _TrustBadgeItem extends StatelessWidget {
  final TrustBadge badge;

  const _TrustBadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey100, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Text(badge.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),

          // Title
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.grey900,
              height: 1.2,
            ),
          ),

          // Description (optional)
          if (badge.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppTheme.grey600, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pre-configured Fufaji Trust Banner
/// Use this directly on Home Screen
class FufajiTrustBanner extends StatelessWidget {
  const FufajiTrustBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FjTrustBanner(
      badges: [
        TrustBadge(icon: '✓', title: 'Honest Pricing', description: 'No fake discounts'),
        TrustBadge(icon: '🌾', title: 'Farm Direct', description: 'Fair to farmers'),
        TrustBadge(icon: '⚡', title: 'Fresh Daily', description: 'Restocked daily'),
      ],
    );
  }
}
