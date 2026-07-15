import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../services/delivery_clustering_service.dart';
import '../../utils/app_theme.dart';
import '../../constants/order_status.dart';

class DeliveryClusterView extends StatefulWidget {
  final String clusterId;

  const DeliveryClusterView({super.key, required this.clusterId});

  @override
  State<DeliveryClusterView> createState() => _DeliveryClusterViewState();
}

class _DeliveryClusterViewState extends State<DeliveryClusterView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeliveryClusteringService _clusteringService = DeliveryClusteringService();

  List<OrderModel> _orders = [];
  final Set<String> _deliveredIds = {};
  final Map<String, bool> _otplessMap = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCluster();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadCluster() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load orders assigned to this agent that are out_for_delivery and
      // belong to this cluster. We store clusterId on the order document
      // at dispatch time.  Fall back to loading by agentId if needed.
      final snap = await _firestore
          .collection('orders')
          .where('clusterId', isEqualTo: widget.clusterId)
          .where('status', isEqualTo: OrderStatus.outForDelivery.toString())
          .get();

      final orders = snap.docs.map((d) => OrderModel.fromMap(d.data())).toList();

      // Pre-check OTP eligibility
      for (final o in orders) {
        _otplessMap[o.customerId] = await _clusteringService.isOtplessEligible(o.customerId);
      }

      setState(() {
        _orders = _clusteringService.optimizeRoute(orders);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cluster: $e';
        _isLoading = false;
      });
    }
  }

  // ── Delivery actions ──────────────────────────────────────────────────────

  Future<void> _markDelivered(OrderModel order) async {
    final otpless = _otplessMap[order.customerId] ?? false;

    if (otpless) {
      await _confirmDelivery(order);
    } else {
      await _showOtpDialog(order);
    }
  }

  Future<void> _confirmDelivery(OrderModel order) async {
    try {
      await _firestore.collection('orders').doc(order.id).update({
        'status': OrderStatus.delivered.toString(),
        'deliveredAt': FieldValue.serverTimestamp(),
        'otpVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _deliveredIds.add(order.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} delivered!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }

      // If all done, show completion dialog
      if (_deliveredIds.length == _orders.length && mounted) {
        _showAllDoneDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark delivered: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _showOtpDialog(OrderModel order) async {
    final ctrl = TextEditingController();
    final correct = order.otp ?? _generateOtp(order.id);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Verify OTP — #${order.orderNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ask ${order.customerName} for the 4-digit OTP sent to their phone.',
              style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Enter OTP', counterText: ''),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim() == correct) {
                Navigator.pop(ctx);
                _confirmDelivery(order);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect OTP. Try again.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  void _showAllDoneDialog() {
    final earnings = _orders.length * 15.0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('All Deliveries Done!', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 64, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text('You delivered ${_orders.length} orders.', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Earnings for this cluster: ₹${earnings.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Return to delivery dashboard
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _openMaps(OrderModel order) async {
    final addr = order.deliveryAddress;
    final query = Uri.encodeComponent(
      addr.fullAddress.isNotEmpty ? addr.fullAddress : addr.village,
    );
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _generateOtp(String orderId) {
    final code = orderId.hashCode.abs() % 10000;
    return code.toString().padLeft(4, '0');
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: Text('Cluster ${widget.clusterId.split('_').last}'),
        actions: [IconButton(onPressed: _loadCluster, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.deliveryAccent))
          : _error != null
          ? _buildError()
          : _orders.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                _buildProgressHeader(),
                Expanded(child: _buildStopList()),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.grey700)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadCluster, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text('No orders in this cluster.', style: TextStyle(color: AppTheme.grey600)),
    );
  }

  Widget _buildProgressHeader() {
    final done = _deliveredIds.length;
    final total = _orders.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$done of $total deliveries complete',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTheme.grey200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, i) => _buildStopCard(_orders[i], i + 1),
    );
  }

  Widget _buildStopCard(OrderModel order, int stopNumber) {
    final done = _deliveredIds.contains(order.id);
    final otpless = _otplessMap[order.customerId] ?? false;
    final isCod = order.paymentMethod == PaymentMethod.cod;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stop number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: done ? AppTheme.success : AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: done
                      ? const Icon(Icons.check, color: AppTheme.white, size: 20)
                      : Text(
                          '$stopNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          if (otpless) _badge('OTP-FREE', AppTheme.success),
                          if (isCod) _badge('COD', AppTheme.warning),
                        ],
                      ),
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isCod)
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.grey500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      order.deliveryAddress.fullAddress,
                      if (order.deliveryAddress.landmark.isNotEmpty)
                        'Near ${order.deliveryAddress.landmark}',
                      order.deliveryAddress.village,
                    ].where((s) => s.isNotEmpty).join(', '),
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey700),
                  ),
                ),
              ],
            ),
            if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.deliveryInstructions!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            if (!done)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openMaps(order),
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Navigate'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markDelivered(order),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Delivered'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    ),
                  ),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Delivered',
                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final done = _deliveredIds.length;
    final total = _orders.length;
    final earnings = total * 15.0;
    final allDone = done == total;

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cluster Earnings',
                    style: TextStyle(color: AppTheme.grey600, fontSize: 12),
                  ),
                  Text(
                    '₹${earnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              if (allDone)
                ElevatedButton.icon(
                  onPressed: _showAllDoneDialog,
                  icon: const Icon(Icons.done_all),
                  label: const Text('All Done'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
