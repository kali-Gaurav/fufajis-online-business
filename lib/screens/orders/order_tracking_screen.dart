import 'package:flutter/material.dart';
import 'dart:async';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Timer _timer;
  String estimatedDeliveryTime = '3:45 PM';
  int minutesRemaining = 23;
  String currentStatus = 'Preparing';

  @override
  void initState() {
    super.initState();
    _updateETA();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _updateETA());
  }

  void _updateETA() {
    // Fetch from API and update ETA
    if (mounted) {
      setState(() {
        // Update logic here
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Tracking'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Large ETA Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                children: [
                  Text(
                    'Expected Delivery',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    estimatedDeliveryTime,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$minutesRemaining minutes from now',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Order Status Timeline
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem('Order Placed', true),
                  _buildTimelineItem('Confirmed', true),
                  _buildTimelineItem('Preparing', true),
                  _buildTimelineItem('Packed', false),
                  _buildTimelineItem('Out for Delivery', false),
                  _buildTimelineItem('Delivered', false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current Status Progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: 0.6,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStatus,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '4 minutes in progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String status, bool completed) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? Colors.green : Colors.grey[300],
                border: Border.all(
                  color: completed ? Colors.green : Colors.grey,
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                color: completed ? Colors.black : Colors.grey[500],
                fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
        if (status != 'Delivered')
          const Padding(
            padding: EdgeInsets.only(left: 11),
            child: Divider(height: 16),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
