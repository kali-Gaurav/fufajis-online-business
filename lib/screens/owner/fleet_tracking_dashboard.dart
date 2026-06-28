import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/delivery_model.dart';
import '../../utils/app_theme.dart';

class FleetTrackingDashboard extends StatefulWidget {
  const FleetTrackingDashboard({super.key});

  @override
  State<FleetTrackingDashboard> createState() => _FleetTrackingDashboardState();
}

class _FleetTrackingDashboardState extends State<FleetTrackingDashboard> {
  final Map<String, Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Fleet Monitor')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deliveries')
            .where('status', whereIn: ['accepted', 'picked_up', 'on_the_way'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));

          final deliveries = snapshot.data!.docs
              .map((doc) => DeliveryModel.fromMap(doc.data() as Map<String, dynamic>))
              .toList();

          _updateMarkers(deliveries);

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(26.9124, 75.7873), // Jaipur Store
                  zoom: 12,
                ),
                markers: _markers.values.toSet(),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    '${deliveries.length} Active Riders',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateMarkers(List<DeliveryModel> deliveries) {
    for (var delivery in deliveries) {
      final markerId = MarkerId(delivery.deliveryId);
      final marker = Marker(
        markerId: markerId,
        position: LatLng(delivery.currentLatitude, delivery.currentLongitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: delivery.customerName,
          snippet: 'Status: ${delivery.status.displayName}',
        ),
      );
      _markers[delivery.deliveryId] = marker;
    }
  }
}

extension on DeliveryModel {
  String get deliveryId => id;
}
