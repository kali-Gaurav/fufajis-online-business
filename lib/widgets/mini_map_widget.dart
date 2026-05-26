import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_theme.dart';

class MiniMapWidget extends StatelessWidget {
  final LatLng location;
  final String title;

  const MiniMapWidget({
    super.key,
    required this.location,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: location,
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('source'),
              position: location,
              infoWindow: InfoWindow(title: title),
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
        ),
      ),
    );
  }
}
