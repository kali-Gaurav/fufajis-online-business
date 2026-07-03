import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/order_workflow_engine.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';

/// Task #91 — Delivery Rescheduling Screen (Rider/Dispatcher)
///
/// When a delivery attempt fails, the rider marks the reason and
/// proposes a new delivery slot. Dispatcher or system then updates the order.
class DeliveryRescheduleScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerId;

  const DeliveryRescheduleScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
  });

  @override
  State<DeliveryRescheduleScreen> createState() => _DeliveryRescheduleScreenState();
}

class _DeliveryRescheduleScreenState extends State<DeliveryRescheduleScreen> {
  final _reasonController = TextEditingController();
  DateTime? _rescheduledFor;
  String _selectedReason = 'Customer not available';
  bool _isSaving = false;

  final List<String> _failureReasons = [
    'Customer not available',
    'Wrong address',
    'Building/gate locked',
    'Customer refused delivery',
    'Damaged goods — rejected',
    'Weather/safety conditions',
    'Vehicle breakdown',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 4)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      _rescheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_rescheduledFor == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rescheduled delivery time')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Mark order as delivery_failed with reschedule info
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': 'OrderStatus.delivery_failed',
        'deliveryFailedReason': _selectedReason == 'Other'
            ? _reasonController.text.trim()
            : _selectedReason,
        'rescheduledFor': Timestamp.fromDate(_rescheduledFor!),
        'rescheduleCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final engine = OrderWorkflowEngine();
      await engine.transition(
        orderId: widget.orderId,
        fromStatus: 'out_for_delivery',
        toStatus: 'delivery_failed',
        changedByUserId: 'rider',
        reason: _selectedReason,
      );

      // Notify customer
      await NotificationService().sendOrderStatusNotification(
        userId: widget.customerId,
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        status: 'delivery_failed',
        message:
            'Delivery of order #${widget.orderNumber} was unsuccessful. '
            'Rescheduled for ${DateFormat("dd MMM 'at' HH:mm").format(_rescheduledFor!)}.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery failure recorded & customer notified'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reschedule #${widget.orderNumber}'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why did the delivery fail?',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...(_failureReasons.map(
              (r) => RadioListTile<String>(
                title: Text(r, style: const TextStyle(fontSize: 14)),
                value: r,
                groupValue: _selectedReason,
                contentPadding: EdgeInsets.zero,
                dense: true,
                onChanged: (v) => setState(() => _selectedReason = v!),
              ),
            )),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Describe the reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Rescheduled Delivery Time',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateTime,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppTheme.ownerAccent),
                    const SizedBox(width: 12),
                    Text(
                      _rescheduledFor != null
                          ? DateFormat("EEE, dd MMM 'at' HH:mm").format(_rescheduledFor!)
                          : 'Select new delivery date & time',
                      style: TextStyle(
                        color: _rescheduledFor != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text(
                        'Record Failure & Reschedule',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
