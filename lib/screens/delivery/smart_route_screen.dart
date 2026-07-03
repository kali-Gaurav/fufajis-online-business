import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import '../../constants/order_status.dart';

// ---------------------------------------------------------------------------
// Data models local to this screen
// ---------------------------------------------------------------------------

class _DeliveryTrip {
  final int tripNumber;
  final List<OrderModel> orders;
  bool isCompleted;

  _DeliveryTrip({required this.tripNumber, required this.orders}) : isCompleted = false;

  double get estimatedEarnings => orders.length * 30.0; // ₹30 per delivery
  String get label => 'Trip $tripNumber';
  String get areaLabel {
    if (orders.isEmpty) return 'Unknown Area';
    final addr = orders.first.deliveryAddress;
    final city = addr.village.isNotEmpty ? addr.village : 'Area $tripNumber';
    return '${orders.length} orders · $city';
  }
}

// ---------------------------------------------------------------------------
// SmartRouteScreen
// ---------------------------------------------------------------------------
class SmartRouteScreen extends StatefulWidget {
  const SmartRouteScreen({super.key});

  @override
  State<SmartRouteScreen> createState() => _SmartRouteScreenState();
}

class _SmartRouteScreenState extends State<SmartRouteScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  List<OrderModel> _todaysOrders = [];
  List<_DeliveryTrip> _trips = [];
  bool _isLoading = true;
  bool _isClustering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndCluster();
  }

  // ── Load today's assigned orders ──────────────────────────────────────
  Future<void> _loadAndCluster() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not logged in.';
          _isLoading = false;
        });
        return;
      }

      // Today's midnight
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Query orders assigned to this delivery agent today
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryAgentId', isEqualTo: user.id)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(midnight))
          .get();

      final orders = snap.docs.map((d) => OrderModel.fromMap(d.data())).toList();

      setState(() => _todaysOrders = orders);

      if (orders.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Cluster them via Cloud Function
      await _clusterOrders(orders.map((o) => o.id).toList());
    } catch (e) {
      debugPrint('[SmartRoute] Error loading orders: $e');
      setState(() {
        _errorMessage = 'Could not load orders: $e';
        _isLoading = false;
      });
    }
  }

  // ── Call clusterDeliveryOrders Cloud Function ─────────────────────────
  Future<void> _clusterOrders(List<String> orderIds) async {
    setState(() => _isClustering = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('clusterDeliveryOrders');
      final result = await callable.call({'orderIds': orderIds});
      final data = result.data as Map<String, dynamic>;
      final rawClusters = (data['clusters'] as List<dynamic>?) ?? [];

      final trips = <_DeliveryTrip>[];
      for (int i = 0; i < rawClusters.length; i++) {
        final clusterIds = List<String>.from(rawClusters[i] as List<dynamic>);
        final clusterOrders = clusterIds
            .map(
              (id) =>
                  _todaysOrders.firstWhere((o) => o.id == id, orElse: () => _todaysOrders.first),
            )
            .toList();
        trips.add(_DeliveryTrip(tripNumber: i + 1, orders: clusterOrders));
      }

      setState(() {
        _trips = trips;
        _isLoading = false;
        _isClustering = false;
      });
    } catch (e) {
      debugPrint('[SmartRoute] Clustering failed, falling back: $e');
      // Fallback: put all orders in one trip
      setState(() {
        _trips = [_DeliveryTrip(tripNumber: 1, orders: _todaysOrders)];
        _isLoading = false;
        _isClustering = false;
      });
    }
  }

  // ── Open Google Maps with all waypoints for a trip ────────────────────
  Future<void> _startTrip(_DeliveryTrip trip) async {
    try {
      final waypoints = trip.orders.map((o) {
        final a = o.deliveryAddress;
        if (a.latitude != 0.0 || a.longitude != 0.0) {
          return '${a.latitude},${a.longitude}';
        }
        return Uri.encodeComponent(a.fullAddress);
      }).toList();

      if (waypoints.isEmpty) {
        _showSnack('No delivery addresses found for this trip.');
        return;
      }

      final destination = waypoints.last;
      final waypointsParam = waypoints.length > 1
          ? waypoints.sublist(0, waypoints.length - 1).join('|')
          : '';

      String url;
      if (waypointsParam.isNotEmpty) {
        url =
            'https://www.google.com/maps/dir/?api=1&destination=$destination&waypoints=$waypointsParam&travelmode=driving';
      } else {
        url = 'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not open Google Maps.');
      }
    } catch (e) {
      _showSnack('Error opening maps: $e');
    }
  }

  // ── Mark all orders in a trip as delivered ────────────────────────────
  Future<void> _markAllDelivered(_DeliveryTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark Trip ${trip.tripNumber} Complete?'),
        content: Text('This will mark ${trip.orders.length} order(s) as delivered.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final order in trip.orders) {
        if (order.status == OrderStatus.delivered) continue;
        batch.update(FirebaseFirestore.instance.collection('orders').doc(order.id), {
          'status': OrderStatus.delivered.toString(),
          'deliveredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      setState(() {
        trip.isCompleted = true;
        _isLoading = false;
      });
      _showSnack('Trip ${trip.tripNumber} marked complete!');
    } catch (e) {
      debugPrint('[SmartRoute] Error marking delivered: $e');
      setState(() => _isLoading = false);
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: AppBar(
        title: const Text('Smart Delivery Route', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndCluster,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.deliveryAccent),
                  const SizedBox(height: 12),
                  Text(
                    _isClustering ? 'Clustering orders by location...' : 'Loading orders...',
                    style: const TextStyle(color: AppTheme.grey600),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? _ErrorView(message: _errorMessage!, onRetry: _loadAndCluster)
          : _todaysOrders.isEmpty
          ? const _EmptyView()
          : _buildTripList(),
    );
  }

  Widget _buildTripList() {
    final totalEarnings = _trips.fold(0.0, (acc, t) => acc + t.estimatedEarnings);
    final completedTrips = _trips.where((t) => t.isCompleted).length;

    return Column(
      children: [
        // Summary banner
        Container(
          color: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(label: 'Orders', value: '${_todaysOrders.length}', icon: Icons.inventory_2),
              _StatChip(label: 'Trips', value: '${_trips.length}', icon: Icons.route),
              _StatChip(
                label: 'Done',
                value: '$completedTrips/${_trips.length}',
                icon: Icons.check_circle,
              ),
              _StatChip(
                label: 'Earnings',
                value: '₹${totalEarnings.round()}',
                icon: Icons.currency_rupee,
              ),
            ],
          ),
        ),

        // Trip list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _trips.length,
            itemBuilder: (ctx, i) => _TripCard(
              trip: _trips[i],
              onStartTrip: () => _startTrip(_trips[i]),
              onMarkDelivered: () => _markAllDelivered(_trips[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Trip card widget
// ---------------------------------------------------------------------------
class _TripCard extends StatefulWidget {
  final _DeliveryTrip trip;
  final VoidCallback onStartTrip;
  final VoidCallback onMarkDelivered;

  const _TripCard({required this.trip, required this.onStartTrip, required this.onMarkDelivered});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final Color cardColor = trip.isCompleted
        ? AppTheme.success.withValues(alpha: 0.08)
        : AppTheme.white;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: trip.isCompleted
            ? const BorderSide(color: AppTheme.success, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          // Trip header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: trip.isCompleted ? AppTheme.success : AppTheme.primary,
              child: Text(
                '${trip.tripNumber}',
                style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(trip.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              trip.areaLabel,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${trip.estimatedEarnings.round()}',
                    style: const TextStyle(
                      color: AppTheme.info,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // Expandable order list
          if (_expanded) ...trip.orders.map((order) => _OrderRow(order: order)),

          // Action buttons
          if (!trip.isCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onStartTrip,
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Start Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onMarkDelivered,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark All Done'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.success,
                        side: const BorderSide(color: AppTheme.success),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Trip Completed',
                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual order row inside a trip
// ---------------------------------------------------------------------------
class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDelivered = order.status == OrderStatus.delivered;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Icon(
            isDelivered ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDelivered ? AppTheme.success : AppTheme.grey400,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  order.deliveryAddress.fullAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
                Text(
                  '${order.items.length} items · ₹${order.totalAmount.round()}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Text(
            '#${order.orderNumber}',
            style: const TextStyle(fontSize: 10, color: AppTheme.grey400),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary chip in banner
// ---------------------------------------------------------------------------
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.white, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / Error views
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined, size: 72, color: AppTheme.grey300),
          SizedBox(height: 16),
          Text(
            'No deliveries assigned today',
            style: TextStyle(color: AppTheme.grey500, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later or contact the shop owner.',
            style: TextStyle(color: AppTheme.grey400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.grey700),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
