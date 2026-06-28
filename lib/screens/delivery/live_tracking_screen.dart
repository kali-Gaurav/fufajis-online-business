import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../models/delivery_model.dart';
import '../../services/fleet_service.dart';
import '../../services/delivery_tracking_service.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String deliveryId;
  const LiveTrackingScreen({super.key, required this.deliveryId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  final FleetService _fleetService = FleetService();
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  final TextEditingController _otpController = TextEditingController();
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    // Start background tracking when this screen is opened if it's on the way
    _trackingService.initializeService().then((_) {
      _trackingService.startTracking(widget.deliveryId);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _completeDelivery(DeliveryModel delivery) async {
    if (_otpController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid OTP')),
      );
      return;
    }

    setState(() => _isCompleting = true);
    try {
      await _fleetService.completeDelivery(widget.deliveryId, _otpController.text);
      _trackingService.stopTracking();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Completed Successfully!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeliveryModel?>(
      stream: _fleetService.getDeliveryStream(widget.deliveryId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.deliveryAccent)));
        }
        
        final delivery = snapshot.data!;
        final riderPos = LatLng(delivery.currentLatitude, delivery.currentLongitude);
        final destPos = LatLng(delivery.destinationLocation.latitude, delivery.destinationLocation.longitude);

        // Move camera to follow rider
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(riderPos));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Order #${delivery.orderId.substring(0, 8)}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () => launchUrl(Uri.parse('tel:${delivery.customerPhone}')),
              ),
            ],
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
                    infoWindow: const InfoWindow(title: 'You'),
                  ),
                  Marker(
                    markerId: const MarkerId('destination'),
                    position: destPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Customer Location'),
                  ),
                },
              ),
              
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildStatusPanel(delivery),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPanel(DeliveryModel delivery) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.customerName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(delivery.deliveryAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.grey600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('ETA', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                  Text(delivery.estimatedArrival != null ? '${delivery.estimatedArrival!.hour}:${delivery.estimatedArrival!.minute.toString().padLeft(2, '0')}' : '15 mins', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          
          if (delivery.status == DeliveryStatus.assigned)
            ElevatedButton(
              onPressed: () => _fleetService.pickupOrder(widget.deliveryId),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Pickup Order from Shop'),
            )
          else if (delivery.status == DeliveryStatus.pickedUp)
            ElevatedButton(
              onPressed: () => _fleetService.startDelivery(widget.deliveryId),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info, foregroundColor: Colors.white),
              child: const Text('Start Navigation'),
            )
          else if (delivery.status == DeliveryStatus.outForDelivery)
            Column(
              children: [
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Customer OTP',
                    hintText: 'Ask customer for code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isCompleting ? null : () => _completeDelivery(delivery),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isCompleting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Confirm Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
