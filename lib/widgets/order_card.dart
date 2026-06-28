import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import '../constants/order_status.dart';

/// A compact card widget that displays a summary of an order.
///
/// Shows: order number, date, status badge (colored), total amount,
/// item count, and a "Track" button when the order is out for delivery.
class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStr = order.status.toString();
    final statusColor = getOrderStatusColor(statusStr);
    final statusIcon = getOrderStatusIcon(statusStr);
    final isInTransit = order.status == OrderStatus.outForDelivery;
    final itemCount = order.items.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Row: order number + status badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDateTime(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey500,
                        ),
                      ),
                    ],
                  ),
                  _StatusBadge(
                    label: order.status.displayName,
                    color: statusColor,
                    icon: statusIcon,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingSm),
              const Divider(color: AppTheme.grey100, height: 1),
              const SizedBox(height: AppTheme.spacingSm),

              // ── Bottom Row: item count + amount + track button ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Item count
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: AppTheme.grey500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),

                  // Total amount
                  Text(
                    formatCurrency(order.totalAmount.toDouble()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),

                  // Track button (only when out for delivery)
                  if (isInTransit)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.location_on_outlined, size: 14),
                        label: const Text(
                          'Track',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: AppTheme.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          elevation: 0,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.grey400,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
