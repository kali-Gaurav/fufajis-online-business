import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/realtime_database_service.dart';
import '../../utils/app_theme.dart';
import 'package:lottie/lottie.dart';

/// A real-time widget that shows the packing progress of an order.
/// Customers see items being scanned by the godown staff in real-time.
class LivePackingTracker extends StatelessWidget {
  final String orderId;

  const LivePackingTracker({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: RealtimeDatabaseService.instance.getPackingProgressStream(orderId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const SizedBox.shrink();
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final String packerName = data['packer_name'] ?? 'Staff';
        final double progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        final int itemsPacked = data['items_packed'] ?? 0;
        final int totalItems = data['total_items'] ?? 0;
        final String lastItem = data['last_item'] ?? '';
        final bool isDone = progress >= 1.0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDone
                ? AppTheme.success.withValues(alpha: 0.05)
                : AppTheme.warning.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDone
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : AppTheme.warning.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isDone)
                    Lottie.asset(
                      'assets/lottie/packing_animation.json',
                      height: 32,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.inventory_2, color: AppTheme.warning),
                    )
                  else
                    const Icon(Icons.check_circle, color: AppTheme.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDone ? 'Order Fully Packed!' : '$packerName is packing your order...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (!isDone && lastItem.isNotEmpty)
                          Text(
                            'Just added: $lastItem',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$itemsPacked/$totalItems',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone ? AppTheme.success : AppTheme.warning,
                  ),
                  minHeight: 8,
                ),
              ),
              if (!isDone)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Watch items update as they are scanned in our godown',
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
