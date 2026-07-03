import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Enhanced delivery tracking screen with real-time Firestore listeners
///
/// Features:
/// - Real-time delivery location tracking (updates every 10 seconds when rider in transit)
/// - Live order status updates
/// - Map view with rider location and route
/// - ETA updates
/// - Rider contact information
class DeliveryTrackingScreenEnhanced extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreenEnhanced({super.key, required this.orderId});

  @override
  State<DeliveryTrackingScreenEnhanced> createState() => _DeliveryTrackingScreenEnhancedState();
}

class _DeliveryTrackingScreenEnhancedState extends State<DeliveryTrackingScreenEnhanced> {
  GoogleMapController? _mapController;
  LatLng? _riderLocation;
  LatLng? _deliveryLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, orderSnapshot) {
          if (orderSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (orderSnapshot.hasError) {
            return Center(child: Text('Error: ${orderSnapshot.error}'));
          }

          if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
            return const Center(child: Text('Order not found'));
          }

          final orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
          final deliveryId = orderData['deliveryId'] as String?;

          if (deliveryId == null) {
            return const Center(child: Text('Delivery not yet assigned'));
          }

          // Listen to delivery real-time updates
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('deliveries').doc(deliveryId).snapshots(),
            builder: (context, deliverySnapshot) {
              if (deliverySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }

              if (deliverySnapshot.hasError) {
                return Center(child: Text('Error: ${deliverySnapshot.error}'));
              }

              if (!deliverySnapshot.hasData || !deliverySnapshot.data!.exists) {
                return const Center(child: Text('Delivery not found'));
              }

              final deliveryData = deliverySnapshot.data!.data() as Map<String, dynamic>;

              // Parse delivery information
              final status = deliveryData['status'] as String? ?? 'pending';
              final riderLocationData = deliveryData['riderLocation'];
              final estimatedDeliveryTime = deliveryData['estimatedDeliveryTime'];
              final riderName = deliveryData['riderName'] as String?;
              final riderPhone = deliveryData['riderPhone'] as String?;
              final riderRating = deliveryData['riderRating'] as num?;

              // Update rider location from Firestore GeoPoint
              if (riderLocationData != null && riderLocationData is GeoPoint) {
                _riderLocation = LatLng(riderLocationData.latitude, riderLocationData.longitude);
              }

              // Parse delivery location
              final deliveryAddressData = deliveryData['deliveryLocation'] as Map<String, dynamic>?;
              if (deliveryAddressData != null) {
                final lat = deliveryAddressData['latitude'] as num?;
                final lng = deliveryAddressData['longitude'] as num?;
                if (lat != null && lng != null) {
                  _deliveryLocation = LatLng(lat.toDouble(), lng.toDouble());
                }
              }

              return ListView(
                children: [
                  // Status card with real-time status
                  _buildStatusCard(status),

                  // Map view (if rider location available)
                  if (_riderLocation != null && _deliveryLocation != null) _buildMapView(),

                  // ETA and delivery info
                  _buildDeliveryInfoCard(
                    estimatedDeliveryTime: estimatedDeliveryTime,
                    status: status,
                  ),

                  // Rider info card
                  if (riderName != null)
                    _buildRiderCard(
                      riderName: riderName,
                      riderPhone: riderPhone,
                      riderRating: riderRating,
                    ),

                  // Status timeline
                  _buildStatusTimeline(status),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Waiting for acceptance';
        statusIcon = Icons.schedule;
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusText = 'Rider accepted your order';
        statusIcon = Icons.done_all;
        break;
      case 'picked_up':
        statusColor = Colors.blue;
        statusText = 'Order picked up from shop';
        statusIcon = Icons.inventory_2;
        break;
      case 'in_transit':
        statusColor = Colors.green;
        statusText = 'On the way to your location';
        statusIcon = Icons.delivery_dining;
        break;
      case 'arrived':
        statusColor = AppTheme.success;
        statusText = 'Rider has arrived';
        statusIcon = Icons.location_on;
        break;
      case 'delivered':
        statusColor = AppTheme.success;
        statusText = 'Order delivered';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withAlpha(200), statusColor.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            statusText.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _riderLocation ?? const LatLng(0, 0),
          zoom: 15,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: {
          // Rider marker
          if (_riderLocation != null)
            Marker(
              markerId: const MarkerId('rider'),
              position: _riderLocation!,
              infoWindow: const InfoWindow(title: 'Rider Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          // Delivery marker
          if (_deliveryLocation != null)
            Marker(
              markerId: const MarkerId('delivery'),
              position: _deliveryLocation!,
              infoWindow: const InfoWindow(title: 'Delivery Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
        },
      ),
    );
  }

  Widget _buildDeliveryInfoCard({required dynamic estimatedDeliveryTime, required String status}) {
    String etaText = 'Calculating...';
    if (estimatedDeliveryTime is Timestamp) {
      final eta = estimatedDeliveryTime.toDate();
      final now = DateTime.now();
      if (eta.isAfter(now)) {
        final diff = eta.difference(now);
        if (diff.inMinutes > 0) {
          etaText = '${diff.inMinutes} min • ${DateFormat('h:mm a').format(eta)}';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimated Arrival', style: TextStyle(color: AppTheme.grey600, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            etaText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Status: ${status.replaceAll('_', ' ').toUpperCase()}',
            style: const TextStyle(color: AppTheme.grey700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard({
    required String riderName,
    required String? riderPhone,
    required num? riderRating,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withAlpha(50),
            child: Text(
              riderName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(riderName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                if (riderRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        riderRating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (riderPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primary),
              onPressed: () => launchUrl(Uri.parse('tel:$riderPhone')),
              tooltip: 'Call rider',
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final steps = [
      ('Order Placed', 'pending', Icons.shopping_cart),
      ('Accepted', 'accepted', Icons.done_all),
      ('Picked Up', 'picked_up', Icons.inventory_2),
      ('In Transit', 'in_transit', Icons.delivery_dining),
      ('Arrived', 'arrived', Icons.location_on),
      ('Delivered', 'delivered', Icons.check_circle),
    ];

    // Determine which steps are completed
    int completedIndex = 0;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].$2 == currentStatus) {
        completedIndex = i;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          ...steps.indexed.map((entry) {
            final i = entry.$1;
            final step = entry.$2;
            final isCompleted = i <= completedIndex;
            final isLast = i == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isCompleted ? AppTheme.primary : AppTheme.grey300,
                      child: Icon(step.$3, size: 12, color: Colors.white),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 30,
                        color: isCompleted ? AppTheme.primary : AppTheme.grey300,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    step.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                      color: isCompleted ? AppTheme.primary : AppTheme.grey600,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
