import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;
import '../../services/delivery_ledger_service.dart';
import '../../services/route_optimization_service.dart';
import '../../utils/app_theme.dart';

class DispatchControlTowerScreen extends StatefulWidget {
  const DispatchControlTowerScreen({super.key});

  @override
  State<DispatchControlTowerScreen> createState() => _DispatchControlTowerScreenState();
}

class _DispatchControlTowerScreenState extends State<DispatchControlTowerScreen> {
  final DeliveryLedgerService _ledgerService = DeliveryLedgerService();
  final RouteOptimizationService _routeOptimizer = RouteOptimizationService();

  List<Map<String, dynamic>> _unassignedOrders = [];
  List<Map<String, dynamic>> _riders = [];
  final Set<String> _selectedOrderIds = {};
  String? _selectedRiderId;
  bool _isLoading = false;
  bool _isOptimizing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _ledgerService.getUnassignedOrders();
      final ridersList = await _ledgerService.getAvailableRiders();
      setState(() {
        _unassignedOrders = orders;
        _riders = ridersList;
        _selectedOrderIds.clear();
        _selectedRiderId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _optimizeAndCreateRoute() async {
    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one order'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isOptimizing = true);
    try {
      // 1. Get selected waypoints
      final selectedOrders = _unassignedOrders
          .where((o) => _selectedOrderIds.contains(o['id']))
          .toList();

      const origin = google_maps.LatLng(25.1006, 76.5156); // Baran HQ Coordinate
      final waypoints = selectedOrders.map((o) {
        final lat = o['latitude'] as double? ?? 25.1006;
        final lng = o['longitude'] as double? ?? 76.5156;
        return DeliveryWaypoint(
          orderId: o['id'] as String,
          customerName: o['customer_name'] as String? ?? 'Customer',
          location: google_maps.LatLng(lat, lng),
          address: o['address'] as String? ?? '',
        );
      }).toList();

      // 2. Call route optimizer (TSP optimization)
      final routeResult = await _routeOptimizer.getOptimizedRoute(
        origin: origin,
        destinations: waypoints,
      );

      // 3. Map back to tasks ordered by sequence
      final tasks = routeResult.orderedWaypoints.map((wp) {
        final order = selectedOrders.firstWhere((o) => o['id'] == wp.orderId);
        return {
          'orderId': order['id'],
          'customerName': order['customer_name'],
          'address': order['address'],
          'latitude': order['latitude'],
          'longitude': order['longitude'],
        };
      }).toList();

      // 4. Create route manifest
      final routeName =
          'Route - ${DateTime.now().toLocal().toString().substring(0, 16)} - ${tasks.length} stops';
      final routeId = await _ledgerService.createRouteManifest(
        routeName: routeName,
        riderId: _selectedRiderId,
        tasks: tasks,
        totalDistance: routeResult.totalDistanceKm,
        estimatedDurationMinutes: routeResult.estimatedMinutes,
      );

      if (routeId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Created Route Manifest! Distance: ${routeResult.totalDistanceKm.toStringAsFixed(2)} km, ETA: ${routeResult.estimatedMinutes} mins',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadData();
      } else {
        throw Exception('Failed to generate route manifest');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Optimization failed: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isOptimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Control Tower', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : Column(
              children: [
                _buildRiderSelectorCard(),
                Expanded(
                  child: _unassignedOrders.isEmpty
                      ? const Center(child: Text('No unassigned orders available.'))
                      : ListView.builder(
                          itemCount: _unassignedOrders.length,
                          itemBuilder: (context, index) {
                            final order = _unassignedOrders[index];
                            final isSelected = _selectedOrderIds.contains(order['id']);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: CheckboxListTile(
                                activeColor: AppTheme.primary,
                                value: isSelected,
                                title: Text(
                                  'Order #${order['order_number']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Customer: ${order['customer_name'] ?? 'N/A'}'),
                                    Text(
                                      'Address: ${order['address'] ?? 'N/A'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedOrderIds.add(order['id'] as String);
                                    } else {
                                      _selectedOrderIds.remove(order['id'] as String);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
                _buildActionPanel(),
              ],
            ),
    );
  }

  Widget _buildRiderSelectorCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Driver (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedRiderId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Leave unassigned (Draft route)'),
              items: _riders.map((r) {
                final isOnline = r['is_online'] == true;
                return DropdownMenuItem<String>(
                  value: r['id'] as String,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: isOnline ? AppTheme.success : Colors.grey,
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      Text('${r['name']} (${r['phone'] ?? 'No Phone'})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedRiderId = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedOrderIds.length} Orders Selected',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _isOptimizing ? null : _optimizeAndCreateRoute,
            icon: _isOptimizing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.navigation),
            label: const Text('Optimize & Generate Route'),
          ),
        ],
      ),
    );
  }
}
