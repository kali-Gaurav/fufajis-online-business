import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  String _address = "Loading address...";
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
    _reverseGeocode(_selectedLocation);
  }

  Future<void> _reverseGeocode(LatLng location) async {
    setState(() {
      _isReverseGeocoding = true;
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _address = "${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}";
        });
      }
    } catch (e) {
      setState(() {
        _address = "Error fetching address";
      });
    } finally {
      setState(() {
        _isReverseGeocoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Your Location'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 16,
            ),
            onMapCreated: (controller) {},
            onCameraMove: (position) {
              setState(() {
                _selectedLocation = position.target;
              });
            },
            onCameraIdle: () {
              _reverseGeocode(_selectedLocation);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35),
              child: Icon(
                Icons.location_on,
                size: 50,
                color: AppTheme.primary,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: AppTheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isReverseGeocoding ? "Fetching address..." : _address,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, {
                            'lat': _selectedLocation.latitude,
                            'lng': _selectedLocation.longitude,
                            'address': _address,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Location', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
