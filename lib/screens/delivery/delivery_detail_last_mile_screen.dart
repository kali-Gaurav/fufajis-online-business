import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/delivery_task_model.dart';
import '../../providers/delivery_last_mile_provider.dart';
import '../../utils/app_theme.dart';
import 'delivery_proof_screen.dart';

class DeliveryDetailLastMileScreen extends StatefulWidget {
  final DeliveryTaskModel delivery;

  const DeliveryDetailLastMileScreen({
    super.key,
    required this.delivery,
  });

  @override
  State<DeliveryDetailLastMileScreen> createState() =>
      _DeliveryDetailLastMileScreenState();
}

class _DeliveryDetailLastMileScreenState
    extends State<DeliveryDetailLastMileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryLastMileProvider>().selectDelivery(widget.delivery.deliveryId);
    });
  }

  Future<void> _callCustomer() async {
    final url = 'tel:${widget.delivery.customerPhone}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _openMaps() async {
    final url =
        'geo:${widget.delivery.addressLatitude},${widget.delivery.addressLongitude}?q=${widget.delivery.customerAddress}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _startDelivery() async {
    final provider = context.read<DeliveryLastMileProvider>();
    await provider.startDelivery(widget.delivery.deliveryId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery started. Location tracking enabled.')),
      );
    }
  }

  void _completeDelivery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeliveryProofScreen(
          delivery: widget.delivery,
        ),
      ),
    );
  }

  void _failDelivery() {
    showDialog(
      context: context,
      builder: (context) => _DeliveryFailureDialog(
        delivery: widget.delivery,
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(); // Go back to previous screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.delivery.orderNumber}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status card
            Container(
              color: AppTheme.info.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.deliveryAccent,
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Status',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusLabel(widget.delivery.status),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Order details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailItem('Customer', widget.delivery.customerName),
                  _buildDetailItem('Phone', widget.delivery.customerPhone),
                  _buildDetailItem('Address', widget.delivery.customerAddress),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                    'Estimated Arrival',
                    _formatTime(widget.delivery.estimatedArrivalAt),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Quick actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callCustomer,
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openMaps,
                          icon: const Icon(Icons.map),
                          label: const Text('Navigate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            // Primary action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.delivery.status == DeliveryTaskStatus.assigned)
                    ElevatedButton(
                      onPressed: _startDelivery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Start Delivery'),
                    ),
                  if (widget.delivery.status == DeliveryTaskStatus.inTransit ||
                      widget.delivery.status == DeliveryTaskStatus.arrived)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _completeDelivery,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Delivery Complete'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _failDelivery,
                          child: const Text('Unable to Deliver'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(DeliveryTaskStatus status) {
    switch (status) {
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

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _DeliveryFailureDialog extends StatefulWidget {
  final DeliveryTaskModel delivery;
  final VoidCallback onConfirm;

  const _DeliveryFailureDialog({
    required this.delivery,
    required this.onConfirm,
  });

  @override
  State<_DeliveryFailureDialog> createState() => _DeliveryFailureDialogState();
}

class _DeliveryFailureDialogState extends State<_DeliveryFailureDialog> {
  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController();

  final List<String> _reasons = [
    'Address not found',
    'Customer not at address',
    'Customer refused',
    'Package damaged',
    'Other',
  ];

  void _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    final provider = context.read<DeliveryLastMileProvider>();
    await provider.failDelivery(
      widget.delivery.deliveryId,
      _selectedReason!,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    widget.onConfirm();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why could not deliver?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._reasons.map(
              (reason) => RadioListTile(
                title: Text(reason),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Additional notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                  ),
                  child: const Text('Submit & Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
