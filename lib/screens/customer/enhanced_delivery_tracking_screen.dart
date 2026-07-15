import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class EnhancedDeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const EnhancedDeliveryTrackingScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<EnhancedDeliveryTrackingScreen> createState() =>
      _EnhancedDeliveryTrackingScreenState();
}

class _EnhancedDeliveryTrackingScreenState
    extends State<EnhancedDeliveryTrackingScreen> {
  late DeliveryOrder _order;

  @override
  void initState() {
    super.initState();
    _loadDeliveryInfo();
  }

  Future<void> _loadDeliveryInfo() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _order = DeliveryOrder(
        orderId: widget.orderId,
        status: 'in_delivery',
        currentStatus: 'Out for Delivery',
        estimatedDelivery: DateTime.now().add(const Duration(minutes: 18)),
        deliveryAgent: DeliveryAgent(
          id: '1',
          name: 'Raj Kumar',
          phone: '+91 98765 43210',
          rating: 4.8,
          vehicle: 'Bike',
          licensePlate: 'KA01AB1234',
        ),
        currentLocation: Location(latitude: 12.9352, longitude: 77.6245),
        deliveryAddress: 'Apartment 5B, Green Park, Whitefield, Bangalore 560066',
        timeline: [
          TimelineEvent(
            status: 'confirmed',
            title: 'Order Confirmed',
            time: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
            completed: true,
          ),
          TimelineEvent(
            status: 'processing',
            title: 'Being Packed',
            time: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
            completed: true,
          ),
          TimelineEvent(
            status: 'picked_up',
            title: 'Picked Up by Delivery Agent',
            time: DateTime.now().subtract(const Duration(minutes: 45)),
            completed: true,
          ),
          TimelineEvent(
            status: 'in_delivery',
            title: 'Out for Delivery',
            time: DateTime.now().subtract(const Duration(minutes: 5)),
            completed: true,
          ),
          TimelineEvent(
            status: 'delivered',
            title: 'Delivered',
            time: null,
            completed: false,
          ),
        ],
        issues: [
          DeliveryIssue(
            id: '1',
            type: 'item_missing',
            description: 'Item appears to be missing from order',
            severity: 'high',
            status: 'open',
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Order #${_order.orderId.substring(0, 8)}'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeliveryETA(),
            const SizedBox(height: 24),
            _buildDeliveryAgentCard(),
            const SizedBox(height: 24),
            _buildLiveMap(),
            const SizedBox(height: 24),
            _buildDeliveryTimeline(),
            const SizedBox(height: 24),
            if (_order.issues.isNotEmpty) ...[
              _buildIssuesSection(),
              const SizedBox(height: 24),
            ],
            _buildDeliveryActions(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryETA() {
    final now = DateTime.now();
    final eta = _order.estimatedDelivery;
    final minutesRemaining = eta.difference(now).inMinutes;
    final isDelayed = minutesRemaining < 0;

    return Card(
      elevation: 0,
      color: isDelayed ? Colors.red[50] : Colors.green[50],
      border: Border.all(color: isDelayed ? Colors.red[200]! : Colors.green[200]!),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Delivery',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDelayed ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDelayed ? 'DELAYED' : 'ON TIME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDelayed ? Colors.red[700] : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(eta),
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      minutesRemaining.abs().toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: isDelayed ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDelayed ? 'Minutes Late' : 'Minutes Away',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (minutesRemaining.clamp(0, 30) / 30).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDelayed ? Colors.red : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAgentCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Agent',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _order.deliveryAgent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            _order.deliveryAgent.rating.toString(),
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.two_wheeler, size: 12, color: AppTheme.grey600),
                          const SizedBox(width: 4),
                          Text(
                            _order.deliveryAgent.vehicle,
                            style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _callDeliveryAgent(),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _chatWithAgent(),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMap() {
    return Card(
      elevation: 0,
      color: Colors.grey[200],
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'Live Map View',
                style: TextStyle(color: AppTheme.grey600),
              ),
              const SizedBox(height: 4),
              Text(
                '${_order.currentLocation.latitude.toStringAsFixed(2)}, ${_order.currentLocation.longitude.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Timeline',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _order.timeline.length,
          itemBuilder: (_, index) => _buildTimelineItem(_order.timeline[index], index),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, int index) {
    final isLast = index == _order.timeline.length - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.completed ? AppTheme.primary : Colors.grey[300],
                ),
                child: event.completed
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : const SizedBox.shrink(),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: event.completed ? AppTheme.primary : Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: event.completed ? AppTheme.grey900 : AppTheme.grey600,
                  ),
                ),
                const SizedBox(height: 4),
                if (event.time != null)
                  Text(
                    _formatTime(event.time!),
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Order Issues',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_order.issues.length} Issue',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: _order.issues
              .map((issue) => _buildIssueCard(issue))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildIssueCard(DeliveryIssue issue) {
    final severityColor = issue.severity == 'high' ? Colors.red : Colors.orange;

    return Card(
      elevation: 0,
      color: severityColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    issue.description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    issue.severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reported ${_formatTime(issue.createdAt)}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
                ),
                ElevatedButton(
                  onPressed: () => _escalateIssue(issue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: severityColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: const Text('Escalate', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _reportIssue(),
          icon: const Icon(Icons.error_outline),
          label: const Text('Report Issue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _shareLocation(),
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('Share My Location'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  void _callDeliveryAgent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling delivery agent...')),
    );
  }

  void _chatWithAgent() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening chat with agent...')),
    );
  }

  void _reportIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: const TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe the issue...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Issue reported successfully')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _escalateIssue(DeliveryIssue issue) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Issue escalated to support team')),
    );
  }

  void _shareLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location shared with delivery agent')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class DeliveryOrder {
  final String orderId;
  final String status;
  final String currentStatus;
  final DateTime estimatedDelivery;
  final DeliveryAgent deliveryAgent;
  final Location currentLocation;
  final String deliveryAddress;
  final List<TimelineEvent> timeline;
  final List<DeliveryIssue> issues;

  DeliveryOrder({
    required this.orderId,
    required this.status,
    required this.currentStatus,
    required this.estimatedDelivery,
    required this.deliveryAgent,
    required this.currentLocation,
    required this.deliveryAddress,
    required this.timeline,
    required this.issues,
  });
}

class DeliveryAgent {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final String vehicle;
  final String licensePlate;

  DeliveryAgent({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.vehicle,
    required this.licensePlate,
  });
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});
}

class TimelineEvent {
  final String status;
  final String title;
  final DateTime? time;
  final bool completed;

  TimelineEvent({
    required this.status,
    required this.title,
    required this.time,
    required this.completed,
  });
}

class DeliveryIssue {
  final String id;
  final String type;
  final String description;
  final String severity;
  final String status;
  final DateTime createdAt;

  DeliveryIssue({
    required this.id,
    required this.type,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
  });
}
