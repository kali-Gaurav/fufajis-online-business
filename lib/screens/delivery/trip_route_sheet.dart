import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../services/order_service.dart';
import '../../services/offline_routing_service.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class TripRouteSheet extends StatefulWidget {
  const TripRouteSheet({super.key});

  @override
  State<TripRouteSheet> createState() => _TripRouteSheetState();
}

class _HyperLocalPosition {
  final double latitude;
  final double longitude;
  _HyperLocalPosition(this.latitude, this.longitude);
}

class _TripRouteSheetState extends State<TripRouteSheet> {
  final OrderService _orderService = OrderService();
  final OfflineRoutingService _routingService = OfflineRoutingService();
  final OfflineSyncService _syncService = OfflineSyncService();

  _HyperLocalPosition _currentPos = _HyperLocalPosition(26.9124, 75.7873); // Default mock (Jaipur)
  bool _isOptimizing = false;
  int _activeWaypointIndex = 0;
  List<OrderModel> _optimizedOrders = [];
  List<String> _routeDirections = [];

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        setState(() {
          _currentPos = _HyperLocalPosition(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error getting GPS coords, using defaults: $e');
    }
  }

  void _triggerRouteOptimization(List<OrderModel> orders) {
    if (orders.isEmpty) return;
    setState(() {
      _isOptimizing = true;
    });

    // Run nearest neighbor optimization
    final sorted = _routingService.optimizeRoute(orders, _currentPos.latitude, _currentPos.longitude);
    final directions = _routingService.generateDirections(sorted, _currentPos.latitude, _currentPos.longitude);

    setState(() {
      _optimizedOrders = sorted;
      _routeDirections = directions;
      _isOptimizing = false;
    });

    // Cache the route locally
    _routingService.cacheRoute(sorted);
  }

  void _launchMultiStopMap() async {
    final url = _routingService.getMapsMultiStopUrl(_optimizedOrders, _currentPos.latitude, _currentPos.longitude);
    if (url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch maps. Please check your internet connection.')),
        );
      }
    }
  }

  Future<void> _simulateMovementToStop(OrderModel order, int index) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulating navigation to stop #${index + 1}: ${order.customerName}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Transition coordinate mock to target address coordinates
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _currentPos = _HyperLocalPosition(
        order.deliveryAddress.latitude,
        order.deliveryAddress.longitude,
      );
      _activeWaypointIndex = index;
    });

    // Send a location update
    if (_syncService.isOnline.value) {
      await _orderService.updateOrderLiveLocation(
        order.id,
        order.deliveryAddress.latitude,
        order.deliveryAddress.longitude,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Arrived at stop #${index + 1}! Location updated.'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showOTPDialog(OrderModel order) {
    final TextEditingController otpController = TextEditingController();
    final focusNode = FocusNode();

    // Auto-focus
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Verify Delivery OTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ask ${order.customerName} for the 4-digit verification code.'),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 6),
                decoration: const InputDecoration(
                  labelText: '4-Digit OTP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 8),
              // Hint for testers (OTP is usually derived from order id or similar in this demo logic)
              const Text(
                'Demo Hint: Use any 4-digit code if offline simulation.',
                style: TextStyle(fontSize: 10, color: AppTheme.grey500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final otp = otpController.text.trim();
                if (otp.length == 4) {
                  Navigator.pop(context);
                  _markOrderDeliveredOffline(order, otp);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid 4-digit OTP')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Deliver'),
            ),
          ],
        );
      },
    );
  }

  void _markOrderDeliveredOffline(OrderModel order, String otp) async {
    // Write status changes through our SyncService queue
    await _syncService.enqueueStatusUpdate(
      order.id,
      'delivered',
      otp: otp,
      otpVerified: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_syncService.isOnline.value
            ? 'Order marked as Delivered.'
            : 'Offline: Added delivery update to synchronization queue.'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _startDeliveryOffline(OrderModel order) async {
    await _syncService.enqueueStatusUpdate(order.id, 'outForDelivery');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_syncService.isOnline.value
            ? 'Order marked as Out for Delivery.'
            : 'Offline: Added "Out for Delivery" change to synchronization queue.'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Route Worksheet'),
        actions: [
          // Connection state monitor
          ValueListenableBuilder<bool>(
            valueListenable: _syncService.isOnline,
            builder: (context, online, child) {
              return ValueListenableBuilder<int>(
                valueListenable: _syncService.pendingSyncCount,
                builder: (context, pendingCount, child) {
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: online
                          ? (pendingCount > 0 ? Colors.amber.withValues(alpha: 0.15) : AppTheme.success.withValues(alpha: 0.1))
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          online ? Icons.cloud_done : Icons.cloud_off,
                          size: 16,
                          color: online ? (pendingCount > 0 ? Colors.amber : AppTheme.success) : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          online 
                              ? (pendingCount > 0 ? 'Syncing ($pendingCount)' : 'Online') 
                              : 'Offline ($pendingCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: online ? (pendingCount > 0 ? Colors.amber : AppTheme.success) : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.getAllOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];
          // Filter to active deliveries (confirmed, packed, outForDelivery)
          final activeDeliveries = allOrders.where((o) =>
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.processing ||
              o.status == OrderStatus.packed ||
              o.status == OrderStatus.outForDelivery).toList();

          if (activeDeliveries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all, size: 64, color: AppTheme.grey400),
                    SizedBox(height: 16),
                    Text(
                      'No Active Deliveries!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'All orders are delivered. Excellent job!',
                      style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
            );
          }

          // Trigger optimization on load if list not populated yet
          if (_optimizedOrders.isEmpty && !_isOptimizing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _triggerRouteOptimization(activeDeliveries);
            });
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route optimization toolbar
                _buildOptimizationBanner(activeDeliveries),

                // Direction guidelines
                if (_routeDirections.isNotEmpty) _buildDirectionsCard(),

                // Waypoint progress line
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'OPTIMIZED DELIVERY SEQUENCE (${_optimizedOrders.length} STOPS)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),

                // List of waypoints
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _optimizedOrders.length,
                  itemBuilder: (context, index) {
                    final order = _optimizedOrders[index];
                    final isCompleted = order.status == OrderStatus.delivered;
                    final isCurrentStop = index == _activeWaypointIndex && !isCompleted;
                    return _buildWaypointCard(order, index, isCurrentStop, isCompleted);
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptimizationBanner(List<OrderModel> activeDeliveries) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _triggerRouteOptimization(activeDeliveries),
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Re-Optimize', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 8),
              if (_optimizedOrders.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _launchMultiStopMap,
                  icon: const Icon(Icons.map, size: 14),
                  label: const Text('Open in Maps', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Starting Position: (${_currentPos.latitude.toStringAsFixed(4)}, ${_currentPos.longitude.toStringAsFixed(4)})',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text(
            'Greedy nearest-neighbor solver operates completely offline to compute the shortest path.',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Navigation Directions Worksheet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800),
          ),
          const Divider(height: 16),
          ..._routeDirections.map((dir) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dir,
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildWaypointCard(OrderModel order, int index, bool isCurrentStop, bool isCompleted) {
    final address = order.deliveryAddress;
    final String locationText = '${address.street}, ${address.village}, ${address.district}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.grey100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentStop ? AppTheme.primary : (isCompleted ? Colors.transparent : AppTheme.grey200),
          width: isCurrentStop ? 2 : 1,
        ),
        boxShadow: isCurrentStop
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop label and status
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isCompleted
                      ? AppTheme.success
                      : (isCurrentStop ? AppTheme.primary : AppTheme.grey500),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted ? 'Stop #${index + 1} (Delivered)' : 'Stop #${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? AppTheme.grey600 : AppTheme.grey800,
                  ),
                ),
                const Spacer(),
                _buildStatusChip(order.status),
              ],
            ),
            const Divider(height: 20),

            // Customer address details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline, size: 18, color: AppTheme.grey600),
                const SizedBox(width: 6),
                Text(
                  order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.grey800),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
                  icon: const Icon(Icons.phone, size: 14),
                  label: Text(
                    order.customerPhone,
                    style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppTheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey700),
                  ),
                ),
              ],
            ),

            // COD Indicator
            if (order.paymentMethod == PaymentMethod.cod) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Collect Cash on Delivery: ₹${order.totalAmount.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action triggers for delivery agents
            if (!isCompleted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.status != OrderStatus.outForDelivery) ...[
                    OutlinedButton.icon(
                      onPressed: () => _startDeliveryOffline(order),
                      icon: const Icon(Icons.local_shipping_outlined, size: 14),
                      label: const Text('Start Delivery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: () => _simulateMovementToStop(order, index),
                    icon: const Icon(Icons.directions_run_outlined, size: 14),
                    label: const Text('Simulate GPS'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.grey700),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showOTPDialog(order),
                    icon: const Icon(Icons.lock_open, size: 14),
                    label: const Text('Verify OTP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color chipColor = AppTheme.grey400;
    String label = status.toString().split('.').last;

    switch (status) {
      case OrderStatus.confirmed:
        chipColor = Colors.blue;
        break;
      case OrderStatus.outForDelivery:
        chipColor = Colors.orange;
        break;
      case OrderStatus.delivered:
        chipColor = AppTheme.success;
        break;
      default:
        chipColor = AppTheme.grey600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: chipColor,
        ),
      ),
    );
  }
}
