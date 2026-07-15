// ============================================================
//  EmptyStateWidget — Professional empty states
//
//  Usage:
//    EmptyStateWidget.orders(onAction: () => ...)
//    EmptyStateWidget.search(query: 'rice')
//    EmptyStateWidget.cart(onAction: () => ...)
//    EmptyStateWidget(icon: ..., title: ..., subtitle: ..., ...)
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppTheme.primary,
    this.actionLabel,
    this.onAction,
    this.illustration,
  });

  // ── Preset factories ───────────────────────────────────────

  factory EmptyStateWidget.orders({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      iconColor: AppTheme.primary,
      title: 'No Orders Yet',
      subtitle: 'Your orders will appear here.\nStart shopping now!',
      actionLabel: 'Browse Products',
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.cart({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.shopping_cart_outlined,
      iconColor: AppTheme.primary,
      title: 'Your Cart is Empty',
      subtitle: 'Add items to your cart to\nget started with an order.',
      actionLabel: 'Start Shopping',
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.search({String? query, VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.search_off_rounded,
      iconColor: AppTheme.grey500,
      title: query != null && query.isNotEmpty ? 'No results for "$query"' : 'Search for Products',
      subtitle: query != null && query.isNotEmpty
          ? 'Try a different keyword or\nbrowse our categories.'
          : 'Type a product name to find what\nyou\'re looking for.',
      actionLabel: query != null ? 'Clear Search' : null,
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.notifications({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.notifications_none_rounded,
      iconColor: AppTheme.grey400,
      title: 'No Notifications',
      subtitle: 'You\'re all caught up!\nWe\'ll notify you of new deals.',
      actionLabel: null,
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.inventory({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      iconColor: AppTheme.warning,
      title: 'No Products Found',
      subtitle: 'Add products to your inventory\nto get started.',
      actionLabel: 'Add Product',
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.deliveries({VoidCallback? onAction}) {
    return const EmptyStateWidget(
      icon: Icons.local_shipping_outlined,
      iconColor: AppTheme.info,
      title: 'No Deliveries Assigned',
      subtitle: 'New deliveries will appear here.\nCheck back soon.',
    );
  }

  factory EmptyStateWidget.tasks() {
    return const EmptyStateWidget(
      icon: Icons.task_alt_rounded,
      iconColor: AppTheme.info,
      title: 'All Tasks Done!',
      subtitle: 'Great work! No pending\ntasks for your shift.',
    );
  }

  factory EmptyStateWidget.noInternet({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_rounded,
      iconColor: AppTheme.error,
      title: 'No Internet Connection',
      subtitle: 'Please check your connection\nand try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: iconColor),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.grey900,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.grey500, height: 1.6),
            ),

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
