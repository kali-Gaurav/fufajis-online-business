import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/offline_order_queue_service.dart';
import '../utils/app_theme.dart';

/// Displays offline order queue status with sync indicator
/// Shows pending sync count, sync progress, and error messages
class OfflineQueueStatusWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onRetryTap;

  const OfflineQueueStatusWidget({super.key, this.showDetails = false, this.onRetryTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final queueService = OfflineOrderQueueService();

        return ValueListenableBuilder<int>(
          valueListenable: queueService.queuedCount,
          builder: (context, queuedCount, _) {
            if (queuedCount == 0) return const SizedBox.shrink();

            return _buildQueueStatusBanner(context, queuedCount, queueService, orderProvider);
          },
        );
      },
    );
  }

  Widget _buildQueueStatusBanner(
    BuildContext context,
    int queuedCount,
    OfflineOrderQueueService queueService,
    OrderProvider orderProvider,
  ) {
    return Container(
      color: AppTheme.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Sync indicator
          ValueListenableBuilder<bool>(
            valueListenable: queueService.isSyncing,
            builder: (context, isSyncing, _) {
              return isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warning),
                      ),
                    )
                  : const Icon(Icons.cloud_upload, color: AppTheme.warning, size: 20);
            },
          ),
          const SizedBox(width: 12),
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$queuedCount order${queuedCount > 1 ? 's' : ''} pending sync',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
                if (showDetails) ...[
                  const SizedBox(height: 4),
                  ValueListenableBuilder<DateTime?>(
                    valueListenable: queueService.lastSyncTime,
                    builder: (context, lastSyncTime, _) {
                      if (lastSyncTime == null) {
                        return const Text(
                          'Syncing will start when you go online',
                          style: TextStyle(fontSize: 12, color: AppTheme.warning),
                        );
                      }
                      final timeAgo = _formatTimeAgo(lastSyncTime);
                      return Text(
                        'Last sync: $timeAgo',
                        style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          // Action buttons
          ValueListenableBuilder<int>(
            valueListenable: queueService.failedCount,
            builder: (context, failedCount, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (failedCount > 0)
                    TextButton.icon(
                      onPressed: onRetryTap ?? () => queueService.syncQueuedOrders(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Retry',
                        style: TextStyle(color: AppTheme.error, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

/// Badge widget for showing offline order count in app bar
class OfflineOrderBadge extends StatelessWidget {
  const OfflineOrderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final queueService = OfflineOrderQueueService();

    return ValueListenableBuilder<int>(
      valueListenable: queueService.queuedCount,
      builder: (context, count, _) {
        if (count == 0) return const SizedBox.shrink();

        return Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

/// Detailed queue status dialog
class QueueStatusDialog extends StatefulWidget {
  final OfflineOrderQueueService queueService;

  const QueueStatusDialog({super.key, required this.queueService});

  @override
  State<QueueStatusDialog> createState() => _QueueStatusDialogState();
}

class _QueueStatusDialogState extends State<QueueStatusDialog> {
  late Future<QueueStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.queueService.getQueueStats();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Order Sync Status'),
      content: FutureBuilder<QueueStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (!snapshot.hasData) {
            return const Text('Failed to load queue status');
          }

          final stats = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow('Queued Orders', stats.queuedCount.toString(), AppTheme.info),
                const SizedBox(height: 8),
                _buildStatRow('Failed Orders', stats.failedCount.toString(), AppTheme.error),
                const SizedBox(height: 8),
                _buildStatRow('Synced Orders', stats.syncedCount.toString(), AppTheme.success),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Size:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '${(stats.totalSize / 1024).toStringAsFixed(2)} KB',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (stats.lastSyncTime != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Sync:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        _formatDateTime(stats.lastSyncTime!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (widget.queueService.failedCount.value > 0)
          ElevatedButton.icon(
            onPressed: () {
              widget.queueService.syncQueuedOrders();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Checkout screen warning banner when offline
class OfflineCheckoutWarning extends StatelessWidget {
  const OfflineCheckoutWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.warning,
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: AppTheme.warning),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You are offline',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.warning),
                ),
                SizedBox(height: 4),
                Text(
                  'This order will be saved locally and synced when you\'re online',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync progress overlay for checkout
class SyncProgressOverlay extends StatelessWidget {
  final OfflineOrderQueueService queueService;

  const SyncProgressOverlay({super.key, required this.queueService});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: queueService.isSyncing,
      builder: (context, isSyncing, _) {
        if (!isSyncing) return const SizedBox.shrink();

        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Syncing ${queueService.queuedCount.value} orders...',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
