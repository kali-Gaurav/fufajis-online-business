import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/app_theme.dart';

class RiderNavigationScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String orderId;

  const RiderNavigationScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.orderId,
  });

  @override
  State<RiderNavigationScreen> createState() => _RiderNavigationScreenState();
}

class _RiderNavigationScreenState extends State<RiderNavigationScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Get initial position
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(pos.latitude, pos.longitude);
    });

    _fetchRoute();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // updates every 10 meters
          ),
        ).listen((Position pos) {
          setState(() {
            _currentLocation = LatLng(pos.latitude, pos.longitude);
          });
          _mapController.move(_currentLocation!, 16.0);
        });
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;

    setState(() => _isLoadingRoute = true);

    try {
      // Using OSRM public API for demo routing.
      // In production, use your own GraphHopper or OSRM instance.
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${widget.destLng},${widget.destLat}?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          setState(() {
            _routePoints = geometry.map((coord) {
              return LatLng(coord[1] as double, coord[0] as double);
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigating to ${widget.orderId}'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _currentLocation!, initialZoom: 16.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fufaji.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, color: AppTheme.info, strokeWidth: 4.0),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      child: const Icon(Icons.motorcycle, color: AppTheme.info, size: 30),
                    ),
                    Marker(
                      point: LatLng(widget.destLat, widget.destLng),
                      child: const Icon(Icons.location_on, color: AppTheme.error, size: 30),
                    ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentLocation != null) {
            _mapController.move(_currentLocation!, 16.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
