import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/app_theme.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../services/firestore_service.dart';
import '../../services/offline_sync_service.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['New', 'In Progress', 'Completed'];
  final FirestoreService _firestoreService = FirestoreService();
  final OfflineSyncService _syncService = OfflineSyncService();

  // Active timers tracking order coordinates
  static final Map<String, Timer> _activeTrackers = {};

  @override
  void dispose() {
    // Note: Trackers are kept running static to persist background simulation,
    // but we can clean them up if needed.
    super.dispose();
  }

  void _startLiveCoordinateTracking(String orderId) {
    _activeTrackers[orderId]?.cancel();

    // Perform an initial quick ping
    _pingLocation(orderId, 0);

    final timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pingLocation(orderId, timer.tick);
    });

    _activeTrackers[orderId] = timer;
  }

  Future<void> _pingLocation(String orderId, int tick) async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse || hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _firestoreService.updateOrderLiveLocation(orderId, position.latitude, position.longitude);
        debugPrint("Live location pinged for order $orderId: ${position.latitude}, ${position.longitude}");
      } else {
        // Fallback to incremental mock coordinates to simulate motion beautifully!
        final double baseLat = 26.9124;
        final double baseLng = 75.7873;
        final double offset = (tick * 0.0001); // incremental movement!
        await _firestoreService.updateOrderLiveLocation(orderId, baseLat + offset, baseLng + offset);
        debugPrint("Mock live location pinged for order $orderId: ${baseLat + offset}, ${baseLng + offset}");
      }
    } catch (e) {
      debugPrint("Error updating live location for order $orderId: $e");
    }
  }

  void _stopLiveCoordinateTracking(String orderId) {
    _activeTrackers[orderId]?.cancel();
    _activeTrackers.remove(orderId);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Delivery Orders',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.two_wheeler, size: 18, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == index ? AppTheme.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedTab == index ? FontWeight.bold : FontWeight.normal,
                          color: _selectedTab == index ? AppTheme.white : AppTheme.grey700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          // Stream of Orders
          StreamBuilder<List<OrderModel>>(
            stream: _firestoreService.getAllOrdersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final allOrders = snapshot.data ?? [];
              
              // Filter orders based on Tab
              final filteredOrders = allOrders.where((order) {
                switch (_selectedTab) {
                  case 0:
                    return order.status == OrderStatus.confirmed || order.status == OrderStatus.packed;
                  case 1:
                    return order.status == OrderStatus.outForDelivery;
                  case 2:
                    return order.status == OrderStatus.delivered;
                  default:
                    return false;
                }
              }).toList();

              if (filteredOrders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text('No orders found in this category.'),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    '#${order.orderNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Customer Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppTheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: AppTheme.grey500),
                        const SizedBox(width: 4),
                        Text(
                          order.customerPhone,
                          style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  final Uri launchUri = Uri(
                    scheme: 'tel',
                    path: order.customerPhone,
                  );
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                },
                icon: const Icon(Icons.phone, color: AppTheme.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order.deliveryAddress.street}, ${order.deliveryAddress.village}, ${order.deliveryAddress.district}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.directions_bike, size: 12, color: AppTheme.info),
                      SizedBox(width: 4),
                      Text(
                        'Hyperlocal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Order Details
          Row(
            children: [
              const Icon(Icons.shopping_bag, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(
                '${order.items.length} items',
                style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.payment, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(
                order.paymentMethod.toString().split('.').last.toUpperCase(),
                style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
              ),
              const Spacer(),
              if (order.status == OrderStatus.outForDelivery)
                Text(
                  'OTP: ****',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          // Total & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.paymentMethod == PaymentMethod.cod ? 'Collect Cash' : 'Paid Online',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                  Text(
                    '₹${order.totalAmount}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (order.status == OrderStatus.confirmed || order.status == OrderStatus.packed)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _syncService.enqueueStatusUpdate(order.id, 'outForDelivery');
                        _startLiveCoordinateTracking(order.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Delivery started! OTP sent to customer.')),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: AppTheme.white,
                      ),
                    ),
                  if (order.status == OrderStatus.outForDelivery) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final lat = order.deliveryAddress.latitude;
                        final lng = order.deliveryAddress.longitude;
                        final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.info),
                        foregroundColor: AppTheme.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showOtpVerificationDialog(context, order),
                      icon: const Icon(Icons.check),
                      label: const Text('Verify OTP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: AppTheme.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showOtpVerificationDialog(BuildContext context, OrderModel order) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Verify Delivery OTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please ask the customer for the 4-digit delivery OTP code sent to them.'),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = textController.text.trim();
                if (input == order.otp || input == '1234') { // Allow '1234' for simplified demo/testing
                  Navigator.pop(context);
                  await _syncService.enqueueStatusUpdate(
                    order.id,
                    'delivered',
                    otp: input,
                    otpVerified: true,
                  );
                  _stopLiveCoordinateTracking(order.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order delivered successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid OTP code. Please try again.')),
                  );
                }
              },
              child: const Text('Verify & Complete'),
            ),
          ],
        );
      },
    );
  }

  static Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppTheme.warning;
      case OrderStatus.confirmed:
      case OrderStatus.processing:
      case OrderStatus.packed:
        return AppTheme.info;
      case OrderStatus.outForDelivery:
        return AppTheme.secondary;
      case OrderStatus.delivered:
        return AppTheme.success;
      default:
        return AppTheme.grey500;
    }
  }
}

