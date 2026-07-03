import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/scan_qr_widget.dart';
import '../employee/dispatch_scanner_screen.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../constants/order_status.dart';
import '../../services/order_service.dart';

class OrdersManagementScreen extends StatefulWidget {
  const OrdersManagementScreen({super.key});

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['New', 'Processing', 'Out for Delivery', 'Completed'];
  final OrderService _orderService = OrderService();

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
                'Orders',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push('/owner/packing-terminal'),
                    icon: const Icon(Icons.inventory),
                    label: const Text('Packing Terminal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.ownerAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('View Order Details tapped')));
                    },
                    icon: const Icon(Icons.filter_list),
                  ),
                ],
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
                        color: _selectedTab == index ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
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
          // Orders Stream
          StreamBuilder<List<OrderModel>>(
            stream: _orderService.getAllOrdersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final allOrders = snapshot.data ?? [];

              // Filter orders by tab
              final filteredOrders = allOrders.where((order) {
                switch (_selectedTab) {
                  case 0:
                    return order.status == OrderStatus.pending ||
                        order.status == OrderStatus.confirmed;
                  case 1:
                    return order.status == OrderStatus.processing ||
                        order.status == OrderStatus.packed;
                  case 2:
                    return order.status == OrderStatus.outForDelivery;
                  case 3:
                    return order.status == OrderStatus.delivered;
                  default:
                    return false;
                }
              }).toList();

              if (filteredOrders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text('No orders in this category.'),
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
    final timeString = DateFormat('hh:mm a').format(order.createdAt);

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
              Text(
                '#${order.orderNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
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
          const SizedBox(height: 12),
          // Customer Info
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              const Icon(Icons.phone, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(order.customerPhone, style: const TextStyle(color: AppTheme.grey600)),
            ],
          ),
          const SizedBox(height: 8),
          // Address
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${order.deliveryAddress.street}, ${order.deliveryAddress.village}, ${order.deliveryAddress.district}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Items & Time
          Row(
            children: [
              const Icon(Icons.shopping_bag, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(
                '${order.items.length} items',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 16, color: AppTheme.grey500),
              const SizedBox(width: 8),
              Text(timeString, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: order.paymentMethod == PaymentMethod.cod
                      ? AppTheme.info.withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.paymentMethod.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: order.paymentMethod == PaymentMethod.cod
                        ? AppTheme.info
                        : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          if (order.paymentMethod != PaymentMethod.cod && order.paymentStatus != 'paid') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ONLINE PAYMENT MANUAL VERIFICATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment ID: ${order.paymentId ?? "N/A"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Please verify that funds have reached your account.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          // Total & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                  ),
                  Text(
                    '₹${order.totalAmount}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              if (order.status == OrderStatus.pending)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await _orderService.updateOrderStatus(order.id, 'cancelled');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        side: const BorderSide(color: AppTheme.error),
                      ),
                      child: const Text('Reject', style: TextStyle(color: AppTheme.error)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        if (order.paymentMethod != PaymentMethod.cod &&
                            order.paymentStatus != 'paid') {
                          await Provider.of<OrderProvider>(
                            context,
                            listen: false,
                          ).approveOrderAndPayment(order.id);
                        } else {
                          await _orderService.updateOrderStatus(
                            order.id,
                            'confirmed',
                            employeeId: auth.currentUser?.id,
                            employeeName: auth.currentUser?.name,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        order.paymentMethod != PaymentMethod.cod && order.paymentStatus != 'paid'
                            ? 'Accept & Verify'
                            : 'Accept',
                      ),
                    ),
                  ],
                ),
              if (order.status == OrderStatus.confirmed) ...[
                // Show ORDER QR — employee scans to open packing screen
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Color(0xFF6A1B9A)),
                  tooltip: 'Show ORDER QR for packing',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Packing QR',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Employee scans this to open order packing',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ScanQrWidget.order(
                              orderId: order.id,
                              orderNumber: order.orderNumber,
                              size: 200,
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.push('/owner/packing/${order.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.info,
                    foregroundColor: AppTheme.white,
                  ),
                  child: const Text('Start Packing'),
                ),
              ],
              if (order.status == OrderStatus.processing)
                ElevatedButton(
                  onPressed: () => context.push('/owner/packing/${order.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: AppTheme.white,
                  ),
                  child: const Text('Continue Packing'),
                ),
              if (order.status == OrderStatus.packed) ...[
                // Show DISPATCH QR — dispatch employee scans this
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Color(0xFFE65100)),
                  tooltip: 'Show DISPATCH QR',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Dispatch QR',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Dispatch employee scans to verify & dispatch',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ScanQrWidget.dispatch(
                              orderId: order.id,
                              orderNumber: order.orderNumber,
                              size: 200,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                                  label: const Text('Scan to Dispatch'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DispatchScannerScreen(orderId: order.id),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _orderService.updateOrderStatus(order.id, 'outForDelivery');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: AppTheme.white,
                  ),
                  child: const Text('Assign to Delivery'),
                ),
              ],
            ],
          ),
        ],
      ),
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
        return AppTheme.info;
      case OrderStatus.delivered:
        return AppTheme.success;
      default:
        return AppTheme.grey500;
    }
  }
}
