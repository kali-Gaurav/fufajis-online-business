import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/realtime_database_service.dart';
import '../../utils/app_theme.dart';

class RiderPulseHeatmapScreen extends StatefulWidget {
  const RiderPulseHeatmapScreen({super.key});

  @override
  State<RiderPulseHeatmapScreen> createState() => _RiderPulseHeatmapScreenState();
}

class _RiderPulseHeatmapScreenState extends State<RiderPulseHeatmapScreen> {
  final MapController _mapController = MapController();

  // Default store location (Jaipur)
  final LatLng _storeLocation = const LatLng(26.9124, 75.7873);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Pulse Heatmap', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _mapController.move(_storeLocation, 13.0),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _storeLocation, initialZoom: 13.0),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.fufaji.online',
              ),
              // Pulse Circles (Visual "Heat")
              StreamBuilder<DatabaseEvent>(
                stream: RealtimeDatabaseService.instance.getAllRidersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                    return const SizedBox.shrink();
                  }

                  final ridersData = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );
                  final markers = <Marker>[];
                  final circles = <CircleMarker>[];

                  ridersData.forEach((riderId, data) {
                    final riderMap = Map<String, dynamic>.from(data as Map);
                    final lat = (riderMap['lat'] as num).toDouble();
                    final lng = (riderMap['lng'] as num).toDouble();
                    final pos = LatLng(lat, lng);

                    // Simulate load (in production, fetch from active orders RTDB path)
                    final activeOrders = (riderMap['active_orders'] ?? 0) as int;
                    final Color pulseColor = _getRiderColor(activeOrders);

                    // Add Pulse Circle
                    circles.add(
                      CircleMarker(
                        point: pos,
                        radius: 200, // meters
                        useRadiusInMeter: true,
                        color: pulseColor.withValues(alpha: 0.2),
                        borderColor: pulseColor.withValues(alpha: 0.5),
                        borderStrokeWidth: 2,
                      ),
                    );

                    // Add Rider Marker
                    markers.add(
                      Marker(
                        point: pos,
                        width: 40,
                        height: 40,
                        child: _RiderMarkerWidget(
                          riderId: riderId,
                          activeOrders: activeOrders,
                          color: pulseColor,
                        ),
                      ),
                    );
                  });

                  return Stack(
                    children: [
                      CircleLayer(circles: circles),
                      MarkerLayer(markers: markers),
                    ],
                  );
                },
              ),
              // Store Marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _storeLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.store, color: AppTheme.primary, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // Legend
          Positioned(bottom: 20, left: 20, child: _buildLegend()),

          // Statistics Overlay
          Positioned(top: 20, right: 20, child: _buildStatsOverlay()),
        ],
      ),
    );
  }

  Color _getRiderColor(int load) {
    if (load == 0) return Colors.green;
    if (load <= 2) return Colors.orange;
    return Colors.red;
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Rider Load', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          _legendItem(Colors.green, 'Idle (0 Orders)'),
          _legendItem(Colors.orange, 'Active (1-2 Orders)'),
          _legendItem(Colors.red, 'Busy (3+ Orders)'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return StreamBuilder<DatabaseEvent>(
      stream: RealtimeDatabaseService.instance.getAllRidersStream(),
      builder: (context, snapshot) {
        int active = 0;
        int idle = 0;
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
          active = data.length;
          idle = data.values
              .where((v) => (v as Map)['active_orders'] == 0 || v['active_orders'] == null)
              .length;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Text(
                '$active',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Text('Riders Online', style: TextStyle(color: Colors.white70, fontSize: 10)),
              const Divider(color: Colors.white24),
              Text(
                '$idle',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Text('Idle', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        );
      },
    );
  }
}

class _RiderMarkerWidget extends StatefulWidget {
  final String riderId;
  final int activeOrders;
  final Color color;

  const _RiderMarkerWidget({
    required this.riderId,
    required this.activeOrders,
    required this.color,
  });

  @override
  State<_RiderMarkerWidget> createState() => _RiderMarkerWidgetState();
}

class _RiderMarkerWidgetState extends State<_RiderMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing Background
            Container(
              width: 40 * _controller.value,
              height: 40 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 1 - _controller.value),
              ),
            ),
            // Rider Icon
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: widget.color, width: 2),
                boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 5)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.motorcycle, color: widget.color, size: 20),
              ),
            ),
            // Badge
            if (widget.activeOrders > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  child: Text(
                    '${widget.activeOrders}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
