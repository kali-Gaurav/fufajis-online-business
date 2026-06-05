import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../services/upi_payment_service.dart';
import '../../utils/app_theme.dart';
import '../employee/delivery_pod_scanner_screen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String orderId;
  const DeliveryDetailScreen({super.key, required this.orderId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final TextEditingController _otpController = TextEditingController();
  OrderModel? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final order = await orderProvider.getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _isLoading = false;
      });
    }
  }

  void _showUPIQRCode(OrderModel order) {
    final upiUri = UpiPaymentService.generateUpiUri(
      orderId: order.orderNumber,
      amount: order.totalAmount,
      note: 'Fufaji Store #${order.orderNumber}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan to Pay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: ₹${order.totalAmount.round()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: upiUri,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Customer can pay using GPay, PhonePe, or Paytm', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _markAsPaid(order.id, 'upi');
            },
            child: const Text('Confirm Received'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(String orderId, String method) async {
    setState(() => _isLoading = true);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.approveOrderAndPayment(orderId, method: method);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully!')));
        _loadOrder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_order == null) {
      return const Scaffold(body: Center(child: Text('Order not found')));
    }

    final order = _order!;
    final isUnpaid = order.paymentStatus != 'paid';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Delivery'), backgroundColor: Colors.white, foregroundColor: AppTheme.grey900),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: AppTheme.primary.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Order #${order.orderNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 8),
                    Text('Total Amount: ₹${order.totalAmount.round()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            if (isUnpaid) ...[
              const Text('PAYMENT COLLECTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAsPaid(order.id, 'cash'),
                      icon: const Icon(Icons.money),
                      label: const Text('Cash Received'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showUPIQRCode(order),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Show QR'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.indigo)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            const Text('DELIVERY VERIFICATION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.grey600)),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: 'Enter Customer OTP',
                hintText: 'Ask customer for 4-digit code',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (isUnpaid) ? null : () async {
                setState(() => _isLoading = true);
                try {
                  final position = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                  );

                  final success = await orderProvider.verifyAndDeliverOrder(
                    orderId: order.id,
                    otp: _otpController.text,
                    riderLatitude: position.latitude,
                    riderLongitude: position.longitude,
                  );

                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Delivered! 🎉')));
                    context.pop();
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(orderProvider.errorMessage ?? 'Invalid OTP or Too far from location'), backgroundColor: AppTheme.error),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: AppTheme.grey300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isUnpaid ? 'Collect Payment First' : 'Confirm Delivery', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),

            // ── Scan QR alternative — recommended for GPS + photo proof ──────
            if (!isUnpaid) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryPodScannerScreen(
                      parcelId: order.id,
                    ),
                    fullscreenDialog: true,
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text(
                  'Scan QR to Confirm (with GPS + Photo)',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
