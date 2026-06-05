import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String orderId;

  const DeliveryTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _riderAnimationController;
  StreamSubscription? _orderSub;
  OrderModel? _realOrder;
  
  // Track Status
  int _etaMinutes = 20;

  // Path coordinates for custom representation
  final Offset _storeOffset = const Offset(100, 300);
  final Offset _customerOffset = const Offset(280, 120);
  late List<Offset> _waypoints;

  Offset _riderOffset = const Offset(100, 300);
  Offset _previousRiderOffset = const Offset(100, 300);
  late AnimationController _interpolationController;
  late Animation<Offset> _riderPositionAnimation;

  @override
  void initState() {
    super.initState();
    
    _waypoints = [
      _storeOffset,
      Offset(_storeOffset.dx + 40, _storeOffset.dy - 30),
      Offset(_storeOffset.dx + 80, _storeOffset.dy - 20),
      Offset(_storeOffset.dx + 110, _storeOffset.dy - 80),
      Offset(_storeOffset.dx + 130, _storeOffset.dy - 120),
      _customerOffset,
    ];

    _riderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _interpolationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _riderPositionAnimation = Tween<Offset>(
      begin: _storeOffset,
      end: _storeOffset,
    ).animate(_interpolationController);

    _listenToOrderUpdates();
  }

  void _listenToOrderUpdates() {
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        final OrderModel order = OrderModel.fromMap(data);
        
        setState(() {
          _realOrder = order;
          if (_realOrder!.status == OrderStatus.outForDelivery) {
            _etaMinutes = 10;
          } else if (_realOrder!.status == OrderStatus.delivered) {
            _etaMinutes = 0;
          }
          
          _updateRiderPosition(order);
        });
      }
    });
  }

  void _updateRiderPosition(OrderModel order) {
    _previousRiderOffset = _riderOffset;
    
    if (order.status == OrderStatus.delivered) {
      _riderOffset = _customerOffset;
    } else if (order.status == OrderStatus.outForDelivery) {
      if (order.liveLocation != null) {
        // Map GPS to screen offsets (Simulation for demo)
        // In real app, use projection or specific logic
        final lat = order.liveLocation!.latitude;
        final lng = order.liveLocation!.longitude;
        
        // Simple linear interpolation between store and customer based on distance
        // This is a demo mapping logic
        const storeLat = 26.9124;
        const storeLng = 75.7873;
        final custLat = order.deliveryAddress.latitude;
        final custLng = order.deliveryAddress.longitude;
        
        final t = _calculateT(lat, lng, storeLat, storeLng, custLat, custLng);
        _riderOffset = Offset.lerp(_storeOffset, _customerOffset, t) ?? _storeOffset;
      } else {
        _riderOffset = Offset(_storeOffset.dx + 150, _storeOffset.dy - 150);
      }
    } else {
      _riderOffset = _storeOffset;
    }

    _riderPositionAnimation = Tween<Offset>(
      begin: _previousRiderOffset,
      end: _riderOffset,
    ).animate(CurvedAnimation(
      parent: _interpolationController,
      curve: Curves.easeInOut,
    ));
    
    _interpolationController.forward(from: 0);
  }

  double _calculateT(double lat, double lng, double sLat, double sLng, double cLat, double cLng) {
    // Distance from store to current
    final dSC = sqrt(pow(lat - sLat, 2) + pow(lng - sLng, 2));
    // Distance from store to customer
    final dST = sqrt(pow(cLat - sLat, 2) + pow(cLng - sLng, 2));
    if (dST == 0) return 1.0;
    return (dSC / dST).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _riderAnimationController.dispose();
    _interpolationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_realOrder == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final OrderModel order = _realOrder!;
    final String orderNum = order.orderNumber;
    final double finalTotal = order.totalAmount;
    final bool isDelivered = order.status == OrderStatus.delivered;

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Track Order #$orderNum'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customer/orders'),
        ),
      ),
      body: Column(
        children: [
          // Real-time Map Representative
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFE8F5E9),
                  child: AnimatedBuilder(
                    animation: _riderPositionAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: MapRoutePainter(
                          store: _storeOffset,
                          customer: _customerOffset,
                          waypoints: _waypoints,
                          riderPosition: _riderPositionAnimation.value,
                          riderAngle: 0.0,
                          pulseAnimation: _riderAnimationController.value,
                        ),
                        child: Container(),
                      );
                    },
                  ),
                ),
                
                Positioned(
                  left: _storeOffset.dx - 45,
                  top: _storeOffset.dy + 15,
                  child: _buildLocationTag("Fufaji Store", Icons.storefront, AppTheme.primary),
                ),
                Positioned(
                  left: _customerOffset.dx - 35,
                  top: _customerOffset.dy - 35,
                  child: _buildLocationTag("Your Home", Icons.home, AppTheme.secondary),
                ),

                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Row(
                        children: [
                          Icon(
                            isDelivered ? Icons.check_circle : Icons.local_shipping,
                            color: isDelivered ? AppTheme.success : Colors.amber, 
                            size: 18
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isDelivered 
                                  ? "Order delivered! Hope you enjoy your purchase."
                                  : "Rider is ${order.status.displayName.toLowerCase()}...",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sliding Status/Detail Panel
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, spreadRadius: 2),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ETA Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDelivered ? "Arrived" : "Estimated Arrival",
                          style: const TextStyle(fontSize: 13, color: AppTheme.grey500, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              isDelivered ? "Delivered" : "$_etaMinutes mins",
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text("₹${finalTotal.round()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Status milestones
                _buildStatusStepper(order.status),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Rider Bio
                if (order.deliveryAgentId != null)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, color: AppTheme.primary, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.deliveryAgentName ?? "Fufaji Rider",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
                          ),
                          const SizedBox(height: 4),
                          const Text("Fufaji Authorized Partner", style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildRoundIconButton(
                          icon: Icons.phone_in_talk_outlined,
                          color: AppTheme.success,
                          onPressed: () => launchUrl(Uri.parse("tel:${order.deliveryAgentPhone}")),
                        ),
                      ],
                    ),
                  ],
                ) else const Text("Waiting for rider assignment...", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.grey500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatusStepper(OrderStatus currentStatus) {
    final List<Map<String, dynamic>> steps = [
      {"title": "Order Placed", "status": OrderStatus.pending},
      {"title": "Packed & Ready", "status": OrderStatus.packed},
      {"title": "Out for Delivery", "status": OrderStatus.outForDelivery},
      {"title": "Delivered", "status": OrderStatus.delivered},
    ];

    int activeIndex = 0;
    if (currentStatus == OrderStatus.packed) {
      activeIndex = 1;
    } else if (currentStatus == OrderStatus.outForDelivery) {
      activeIndex = 2;
    } else if (currentStatus == OrderStatus.delivered) {
      activeIndex = 3;
    }

    return Row(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final bool isCompleted = index <= activeIndex;
        final bool isActive = index == activeIndex;
        
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 0
                          ? Colors.transparent
                          : (isCompleted ? AppTheme.primary : AppTheme.grey300),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppTheme.primary
                          : (isCompleted ? AppTheme.primary.withValues(alpha: 0.2) : Colors.white),
                      border: Border.all(
                        color: isCompleted ? AppTheme.primary : AppTheme.grey300,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.check,
                              size: 14,
                              color: isCompleted ? AppTheme.primary : AppTheme.grey400,
                            ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == steps.length - 1
                          ? Colors.transparent
                          : (index < activeIndex ? AppTheme.primary : AppTheme.grey300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step["title"],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? AppTheme.grey900 : AppTheme.grey500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// Custom Painter to render paths, grids, and nodes on the vector map representation
class MapRoutePainter extends CustomPainter {
  final Offset store;
  final Offset customer;
  final List<Offset> waypoints;
  final Offset riderPosition;
  final double riderAngle;
  final double pulseAnimation;

  MapRoutePainter({
    required this.store,
    required this.customer,
    required this.waypoints,
    required this.riderPosition,
    required this.riderAngle,
    required this.pulseAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw simple grid map layout representing district/village roads
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    const double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw some mock secondary roads for design depth
    final roadPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(20, 150), const Offset(350, 150), roadPaint);
    canvas.drawLine(const Offset(150, 20), const Offset(150, 380), roadPaint);

    // Draw active polyline delivery path
    final pathPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.6)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    if (waypoints.isNotEmpty) {
      path.moveTo(waypoints.first.dx, waypoints.first.dy);
      for (int i = 1; i < waypoints.length; i++) {
        path.lineTo(waypoints[i].dx, waypoints[i].dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    // Highlight path segment traveled by rider
    final traveledPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final Path traveledPath = Path();
    traveledPath.moveTo(store.dx, store.dy);
    // Approximate progress tracking
    double minDistance = double.infinity;
    int closestSegmentIndex = 0;
    
    for (int i = 0; i < waypoints.length; i++) {
      double dist = (waypoints[i] - riderPosition).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestSegmentIndex = i;
      }
    }

    for (int i = 1; i <= closestSegmentIndex; i++) {
      traveledPath.lineTo(waypoints[i].dx, waypoints[i].dy);
    }
    traveledPath.lineTo(riderPosition.dx, riderPosition.dy);
    canvas.drawPath(traveledPath, traveledPaint);

    // Draw Store Marker Pulse
    final storePulsePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.2 * pulseAnimation)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(store, 15.0 + 10.0 * pulseAnimation, storePulsePaint);

    final storePaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(store, 8.0, storePaint);

    // Draw Customer Home Marker Pulse
    final homePulsePaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.2 * pulseAnimation)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(customer, 15.0 + 10.0 * pulseAnimation, homePulsePaint);

    final customerPaint = Paint()
      ..color = AppTheme.secondary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(customer, 8.0, customerPaint);

    // Draw Rider Position Marker
    final riderPulsePaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(riderPosition, 16.0 + 8.0 * sin(pulseAnimation * pi), riderPulsePaint);

    final riderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(riderPosition, 10.0, riderPaint);

    // Rider Icon inner core
    final riderInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(riderPosition, 4.0, riderInnerPaint);
  }

  @override
  bool shouldRepaint(covariant MapRoutePainter oldDelegate) {
    return oldDelegate.riderPosition != riderPosition ||
        oldDelegate.pulseAnimation != pulseAnimation;
  }
}

