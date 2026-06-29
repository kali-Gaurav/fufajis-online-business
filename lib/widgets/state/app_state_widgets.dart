import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Reusable State Widgets for consistent UX across screens
/// Use these for: Empty, Error, Offline, Loading states

// ─────────────────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────

class EmptyProductsState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const EmptyProductsState({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppTheme.grey300,
          ),
          const SizedBox(height: 24),
          Text(
            title ?? 'No products available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.grey900,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? 'We are restocking. Check back soon!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(120, 48),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  NETWORK ERROR STATE
// ─────────────────────────────────────────────────────────────────────────

class NetworkErrorState extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const NetworkErrorState({
    super.key,
    this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 80,
            color: AppTheme.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            title ?? 'No internet connection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.grey900,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? 'Please check your connection and try again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(120, 48),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  OFFLINE INDICATOR (Top banner)
// ─────────────────────────────────────────────────────────────────────────

class OfflineIndicatorBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineIndicatorBanner({
    super.key,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.warning.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            size: 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Text(
            'You are offline. Browsing cached products.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  SHOP CLOSED STATE (Full screen)
// ─────────────────────────────────────────────────────────────────────────

class ShopClosedState extends StatelessWidget {
  final DateTime? reopensAt;
  final VoidCallback? onNotifyMe;

  const ShopClosedState({
    super.key,
    this.reopensAt,
    this.onNotifyMe,
  });

  @override
  Widget build(BuildContext context) {
    final reopensText = reopensAt != null
        ? 'Opens at ${reopensAt!.hour}:${reopensAt!.minute.toString().padLeft(2, '0')}'
        : 'We will reopen soon';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            size: 80,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 24),
          Text(
            'Shop is Closed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.grey900,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            reopensText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onNotifyMe,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 48),
              side: const BorderSide(color: AppTheme.primary, width: 2),
            ),
            child: const Text(
              'Notify Me',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
