// ============================================================
//  KpiCard — Metric display cards for all dashboards
//
//  Variants:
//    KpiCard        — standard card with icon, value, label
//    KpiCard.alert  — red/orange variant for urgent counts
//    KpiCard.success— green variant for positive metrics
//    KpiCard.wide   — full-width horizontal layout
//    KpiRow         — scrollable row of KpiCards
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class KpiCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool compact;
  final String? trend; // e.g. "+12%" or "↑ 3"
  final bool trendPositive;

  const KpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppTheme.primary,
    this.backgroundColor,
    this.onTap,
    this.compact = false,
    this.trend,
    this.trendPositive = true,
  });

  factory KpiCard.revenue({required String value, String? trend, VoidCallback? onTap}) {
    return KpiCard(
      value: value,
      label: 'Revenue Today',
      icon: Icons.currency_rupee_rounded,
      color: const Color(0xFF2E7D32),
      backgroundColor: const Color(0xFFE8F5E9),
      trend: trend,
      trendPositive: true,
      onTap: onTap,
    );
  }

  factory KpiCard.orders({required String value, String? trend, VoidCallback? onTap}) {
    return KpiCard(
      value: value,
      label: 'Orders Today',
      icon: Icons.shopping_bag_outlined,
      color: AppTheme.primary,
      backgroundColor: const Color(0xFFFFF3E0),
      trend: trend,
      trendPositive: true,
      onTap: onTap,
    );
  }

  factory KpiCard.alert({
    required String value,
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return KpiCard(
      value: value,
      label: label,
      icon: icon,
      color: AppTheme.error,
      backgroundColor: const Color(0xFFFFEBEE),
      onTap: onTap,
    );
  }

  factory KpiCard.pending({required String value, VoidCallback? onTap}) {
    return KpiCard(
      value: value,
      label: 'Pending',
      icon: Icons.pending_outlined,
      color: AppTheme.warning,
      backgroundColor: const Color(0xFFFFF8E1),
      onTap: onTap,
    );
  }

  factory KpiCard.delivered({required String value, VoidCallback? onTap}) {
    return KpiCard(
      value: value,
      label: 'Delivered',
      icon: Icons.check_circle_outline_rounded,
      color: AppTheme.info,
      backgroundColor: const Color(0xFFE8F5E9),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withOpacity(0.10);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: compact ? 90 : 110),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: compact ? 32 : 38,
              height: compact ? 32 : 38,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: compact ? 16 : 20),
            ),
            SizedBox(height: compact ? 8 : 10),

            // Value
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.grey900,
                height: 1,
              ),
            ),

            // Trend
            if (trend != null) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trendPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 11,
                    color: trendPositive ? AppTheme.info : AppTheme.error,
                  ),
                  Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: trendPositive ? AppTheme.info : AppTheme.error,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),

            // Label
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: AppTheme.grey500,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scrollable KPI row ─────────────────────────────────────

class KpiRow extends StatelessWidget {
  final List<KpiCard> cards;
  final EdgeInsetsGeometry? padding;

  const KpiRow({super.key, required this.cards, this.padding});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(width: 115, child: cards[index]),
      ),
    );
  }
}

// ── 2-column KPI grid ──────────────────────────────────────

class KpiGrid extends StatelessWidget {
  final List<KpiCard> cards;

  const KpiGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }
}
