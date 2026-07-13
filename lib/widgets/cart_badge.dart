import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Cart badge widget - shows item count on cart icon
/// Positioned at top-right with orange background
class CartBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  final bool animate;

  const CartBadge({super.key, required this.count, required this.onTap, this.animate = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cart Icon
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, size: 24),
          onPressed: onTap,
          tooltip: 'कार्ट',
        ),

        // Badge (only show if count > 0)
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Badge for displaying notification count
class NotificationBadge extends StatelessWidget {
  final int count;
  final Color backgroundColor;
  final Color textColor;

  const NotificationBadge({
    super.key,
    required this.count,
    this.backgroundColor = const Color(0xFFE74C3C),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
