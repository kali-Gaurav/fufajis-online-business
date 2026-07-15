import 'package:flutter/material.dart';
import '../models/delivery_task_model.dart';
import '../utils/app_theme.dart';

class DeliveryTaskCard extends StatelessWidget {
  final DeliveryTaskModel delivery;
  final VoidCallback onTap;
  final int? estimatedMinutesToArrival;

  const DeliveryTaskCard({
    super.key,
    required this.delivery,
    required this.onTap,
    this.estimatedMinutesToArrival,
  });

  String _getStatusLabel() {
    switch (delivery.status) {
      case DeliveryTaskStatus.assigned:
        return 'Assigned';
      case DeliveryTaskStatus.inTransit:
        return 'In Transit';
      case DeliveryTaskStatus.arrived:
        return 'Arrived';
      case DeliveryTaskStatus.completed:
        return 'Completed';
      case DeliveryTaskStatus.failed:
        return 'Failed';
      case DeliveryTaskStatus.created:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.accepted:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.picked_up:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.out_for_delivery:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.delivered:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.rejected:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.returned:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Color _getStatusColor() {
    switch (delivery.status) {
      case DeliveryTaskStatus.assigned:
        return AppTheme.info;
      case DeliveryTaskStatus.inTransit:
        return AppTheme.warning;
      case DeliveryTaskStatus.arrived:
        return Colors.purple;
      case DeliveryTaskStatus.completed:
        return AppTheme.success;
      case DeliveryTaskStatus.failed:
        return AppTheme.error;
      case DeliveryTaskStatus.created:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.accepted:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.picked_up:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.out_for_delivery:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.delivered:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.rejected:
        // TODO: Handle this case.
        throw UnimplementedError();
      case DeliveryTaskStatus.returned:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${delivery.orderNumber}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer name and phone
              Text(
                delivery.customerName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(delivery.customerPhone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 12),

              // Address (truncated)
              Text(
                delivery.customerAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),

              // ETA and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (estimatedMinutesToArrival != null)
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$estimatedMinutesToArrival mins away',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
