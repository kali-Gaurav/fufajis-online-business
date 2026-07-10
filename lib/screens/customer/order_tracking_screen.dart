import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/order_tracking_model.dart';
import '../../models/delivery_agent_model.dart';
import '../../providers/order_tracking_provider.dart';
import '../../services/eta_service.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _mapController;
  final ETAService _etaService = ETAService();
  late Stream<OrderTracking?> _trackingStream;

  @override
  void initState() {
    super.initState();
    _trackingStream = context.read<OrderTrackingProvider>().watchOrderTracking(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        elevation: 0,
      ),
      body: StreamBuilder<OrderTracking?>(
        stream: _trackingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Order not found'));
          }

          final order = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Live Map
                SizedBox(
                  height: 300,
                  child: GoogleMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: order.currentLocation ?? const LatLng(19.0760, 72.8777),
                      zoom: 15,
                    ),
                    markers: _buildMarkers(order),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agent Info Card (if assigned)
                      if (order.deliveryAgentId != null)
                        FutureBuilder<DeliveryAgent?>(
                          future: context.read<OrderTrackingProvider>().getAgent(order.deliveryAgentId!),
                          builder: (context, agentSnapshot) {
                            if (!agentSnapshot.hasData) {
                              return const SizedBox.shrink();
                            }

                            final agent = agentSnapshot.data!;

                            return _AgentInfoCard(agent: agent, order: order);
                          },
                        ),

                      const SizedBox(height: 16),

                      // ETA Section
                      if (order.estimatedDeliveryTime != null)
                        _ETASection(eta: order.estimatedDeliveryTime!),

                      const SizedBox(height: 16),

                      // Delivery Address
                      _DeliveryAddressSection(order: order),

                      const SizedBox(height: 16),

                      // Status Timeline
                      _StatusTimelineSection(order: order),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Call agent
                                if (order.deliveryAgentId != null) {
                                  print('Calling agent: ${order.deliveryAgentId}');
                                }
                              },
                              icon: const Icon(Icons.call),
                              label: const Text('Call Agent'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Report issue
                                Navigator.of(context).pushNamed(
                                  '/report-issue',
                                  arguments: widget.orderId,
                                );
                              },
                              icon: const Icon(Icons.warning),
                              label: const Text('Report Issue'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Set<Marker> _buildMarkers(OrderTracking order) {
    final markers = <Marker>{};

    // Shop location (fixed)
    markers.add(
      const Marker(
        markerId: MarkerId('shop'),
        position: LatLng(19.0760, 72.8777),
        infoWindow: InfoWindow(title: 'Fufajis Shop'),
      ),
    );

    // Current agent location
    if (order.currentLocation != null) {
      markers.add(
        Marker(
          markerId: MarkerId('agent'),
          position: order.currentLocation!,
          infoWindow: const InfoWindow(title: 'Delivery Agent'),
        ),
      );
    }

    // Delivery location
    if (order.deliveryAddressCity != null) {
      // Use a placeholder location for demonstration
      markers.add(
        const Marker(
          markerId: MarkerId('delivery'),
          position: LatLng(19.0900, 72.8700),
          infoWindow: InfoWindow(title: 'Your Address'),
        ),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _AgentInfoCard extends StatelessWidget {
  final DeliveryAgent agent;
  final OrderTracking order;

  const _AgentInfoCard({required this.agent, required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Agent photo
                CircleAvatar(
                  radius: 32,
                  backgroundImage: agent.photoUrl != null
                      ? NetworkImage(agent.photoUrl!)
                      : null,
                  child: agent.photoUrl == null
                      ? Text(agent.name[0], style: const TextStyle(fontSize: 24))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${agent.rating.toStringAsFixed(1)}/5.0',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${agent.totalDeliveries} deliveries',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicle',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      Text(
                        '${agent.vehicleType ?? 'Unknown'} • ${agent.vehiclePlate ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Call
                      print('Calling ${agent.phone}');
                    },
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Send SMS
                      print('Sending SMS to ${agent.phone}');
                    },
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ETASection extends StatelessWidget {
  final DateTime eta;

  const _ETASection({required this.eta});

  @override
  Widget build(BuildContext context) {
    final remaining = eta.difference(DateTime.now());
    final minutes = remaining.inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⏱️ ARRIVING IN: ${minutes > 0 ? '$minutes MINUTES' : 'Soon'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (30 - minutes.clamp(0, 30)) / 30.0,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('h:mm a').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            Text(
              DateFormat('h:mm a').format(eta),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryAddressSection extends StatelessWidget {
  final OrderTracking order;

  const _DeliveryAddressSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📍 DELIVERY LOCATION',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          order.deliveryAddressStreet ?? 'Address not available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        if (order.deliveryAddressCity != null || order.deliveryAddressPostalCode != null)
          Text(
            '${order.deliveryAddressCity ?? ''} ${order.deliveryAddressPostalCode ?? ''}'.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        if (order.deliveryLandmark != null) ...[
          const SizedBox(height: 4),
          Text(
            'Landmark: ${order.deliveryLandmark}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
        if (order.deliveryInstructions != null) ...[
          const SizedBox(height: 4),
          Text(
            'Instructions: ${order.deliveryInstructions}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ],
    );
  }
}

class _StatusTimelineSection extends StatelessWidget {
  final OrderTracking order;

  const _StatusTimelineSection({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUS TIMELINE:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...order.statusHistory.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == order.statusHistory.length - 1;

          return Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.green.shade200,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        DateFormat('h:mm a, MMM d').format(event.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
