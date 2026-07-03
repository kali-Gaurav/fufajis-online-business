import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'package:provider/provider.dart';

class PaymentVerificationDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const PaymentVerificationDialog({super.key, required this.orderId, required this.orderNumber});

  @override
  State<PaymentVerificationDialog> createState() => _PaymentVerificationDialogState();
}

class _PaymentVerificationDialogState extends State<PaymentVerificationDialog> {
  StreamSubscription? _subscription;
  bool _isVerifying = true;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _startVerificationPolling();
  }

  void _startVerificationPolling() {
    _subscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;

          final data = snapshot.data()!;
          final status = data['status'];
          final paymentStatus = data['paymentStatus'];

          if (paymentStatus == 'paid' || status == 'OrderStatus.confirmed') {
            _handleSuccess();
          } else if (paymentStatus == 'failed' || status == 'OrderStatus.cancelled') {
            _handleFailure();
          }
        });

    // Timeout after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isVerifying) {
        _handleTimeout();
      }
    });
  }

  void _handleSuccess() {
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _success = true;
    });

    Provider.of<CartProvider>(context, listen: false).clearCart();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go(
          '/customer/order-confirmation?orderId=${widget.orderId}&orderNumber=${widget.orderNumber}',
        );
      }
    });
  }

  void _handleFailure() {
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _success = false;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed. Please try again or contact support.'),
          ),
        );
      }
    });
  }

  void _handleTimeout() {
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _success = false;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification timed out. If money was deducted, your order will confirm automatically.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isVerifying,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isVerifying) ...[
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 24),
                const Text(
                  'Verifying Payment...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please do not close the app or press back.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.grey600),
                ),
              ] else if (_success) ...[
                const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Payment Verified!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ] else ...[
                const Icon(Icons.error, color: AppTheme.error, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Verification Failed or Timed Out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
