import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/delivery_model.dart';
import '../../services/fleet_service.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  GoogleMapController? _mapController;
  final FleetService _fleetService = FleetService();
  String? _deliveryId;

  @override
  void initState() {
    super.initState();
    _findDeliveryId();
  }

  Future<void> _findDeliveryId() async {
    final snap = await FirebaseFirestore.instance
        .collection('deliveries')
        .where('orderId', isEqualTo: widget.orderId)
        .limit(1)
        .get();
    
    if (snap.docs.isNotEmpty) {
      setState(() {
        _deliveryId = snap.docs.first.id;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_deliveryId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track Order')),
        body: const Center(child: Text('Order is being prepared...')),
      );
    }

    return StreamBuilder<DeliveryModel?>(
      stream: _fleetService.getDeliveryStream(_deliveryId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final delivery = snapshot.data!;
        final riderPos = LatLng(delivery.currentLatitude, delivery.currentLongitude);
        final destPos = LatLng(delivery.destinationLocation.latitude, delivery.destinationLocation.longitude);

        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(riderPos));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Live Tracking'),
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.grey900,
            elevation: 0,
          ),
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(target: riderPos, zoom: 15),
                markers: {
                  Marker(
                    markerId: const MarkerId('rider'),
                    position: riderPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                    infoWindow: const InfoWindow(title: 'Delivery Partner'),
                  ),
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: destPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Your Location'),
                  ),
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildInfoCard(delivery),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(DeliveryModel delivery) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.motorcycle, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.status.displayName, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                    const Text('Delivery Partner is on the way', style: TextStyle(color: AppTheme.grey600)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call, color: AppTheme.success),
                onPressed: () => launchUrl(Uri.parse('tel:911234567890')), // Should get rider phone
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('ETA', delivery.estimatedArrival.isNotEmpty ? delivery.estimatedArrival : '12 mins'),
              _buildStatItem('Distance', '${delivery.distanceRemaining.toStringAsFixed(1)} km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
