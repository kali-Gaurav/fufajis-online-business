import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cancellation_fee_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/invoice_service.dart';
import '../../constants/order_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/weight_verification_service.dart';
import '../../widgets/customer/live_packing_tracker.dart';
import 'track_order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderModel? _order;
  Map<String, dynamic>? _rawOrderData;
  List<WeightProofRecord> _weightProofs = [];

  @override
  void initState() {
    super.initState();
    _loadWeightProofs();
  }

  /// Load weight proofs once (one-time fetch)
  Future<void> _loadWeightProofs() async {
    try {
      final proofs = await WeightVerificationService().getOrderWeightProofs(
        widget.orderId,
      );
      if (mounted) {
        setState(() {
          _weightProofs = proofs;
        });
      }
    } catch (e) {
      debugPrint('[OrderDetail] Error loading weight proofs: $e');
    }
  }




  @override
  Widget build(BuildContext context) {
    // StreamBuilder for real-time order updates from Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        if (orderSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: Center(
              child: Text('Error: ${orderSnapshot.error}'),
            ),
          );
        }

        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Order not found')),
          );
        }

        _rawOrderData = orderSnapshot.data!.data() as Map<String, dynamic>?;

        // Parse order from Firestore document
        // This converts the raw Firestore data to OrderModel for display
        _order = OrderModel.fromMap(_rawOrderData ?? {});

        // Show loading if order parsing failed
        if (_order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order Details')),
            body: const Center(child: Text('Unable to load order')),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.grey50,
          appBar: AppBar(
            title: Text('Order #${_order!.orderNumber}'),
            backgroundColor: AppTheme.cream,
            foregroundColor: AppTheme.grey900,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () => InvoiceService().generateAndPrintInvoice(_order!),
                icon: const Icon(Icons.download),
                tooltip: 'Download Invoice',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatusHeader(),
                if (_order!.status == OrderStatus.pending ||
                    _order!.status == OrderStatus.confirmed ||
                    _order!.status == OrderStatus.processing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LivePackingTracker(orderId: _order!.id),
                  ),
                _buildItemsList(),
                _buildPackingAndWeightProofSection(),
                _buildShopSection(),
                _buildDeliverySection(),
                _buildPriceDetails(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader() {
    final canPayOnline = _order!.paymentStatus != 'paid' && 
                         _order!.status != OrderStatus.cancelled &&
                         _order!.status != OrderStatus.delivered;
    final canTrack = _order!.status == OrderStatus.outForDelivery;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _order!.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _order!.status.displayName.toUpperCase(),
              style: TextStyle(
                color: _order!.statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(_order!.createdAt),
            style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
          ),
          if (canTrack) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrackOrderScreen(orderId: _order!.id)),
              ),
              icon: const Icon(Icons.location_on, size: 20),
              label: const Text('Track Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          if (canPayOnline) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleOnlinePayment,
              icon: const Icon(Icons.payment, size: 20),
              label: const Text('Pay Online Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Switch from COD to Online Payment',
              style: TextStyle(fontSize: 12, color: AppTheme.grey600, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  void _handleOnlinePayment() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await orderProvider.convertToOnlinePayment(
      order: _order!,
      email: authProvider.currentUser?.email ?? 'customer@fufaji.online',
      onPaymentStarted: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening secure payment gateway...')),
        );
      },
      onPaymentError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.error),
        );
      },
    );
    
    // Refresh order state
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          ..._order!.items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item.productImage,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.image),
                ),
              ),
              title: Text(item.productName),
              subtitle: Text('${item.quantity} x ₹${item.price.round()}'),
              trailing: Text(
                '₹${item.totalPrice.round()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    Color color = AppTheme.grey900,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.grey700,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', _order!.subtotal.toDouble()),
          if (_order!.deliveryCharge.toDouble() > 0)
            _buildPriceRow('Delivery Fee', _order!.deliveryCharge.toDouble()),
          const Divider(),
          _buildPriceRow(
            'Total',
            _order!.totalAmount.toDouble(),
            isBold: true,
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildShopSection() {
    if (_order!.shopId == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _order!.shopName ?? 'Shop',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_order!.shopPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primary),
              onPressed: () => launchUrl(Uri.parse('tel:${_order!.shopPhone}')),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Address',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _order!.deliveryAddress.fullAddress,
            style: const TextStyle(color: AppTheme.grey700),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_order!.canCancel)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showCancelDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancel Order'),
              ),
            ),
          if (_order!.canReturn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showReturnDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Return Order'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  context.push('/customer/support-chat/${_order!.id}'),
              child: const Text('Contact Support'),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder();
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showReturnDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Order', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Enter reason for return',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _requestReturn(reasonController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;
    final feeService = CancellationFeeService();
    final feeResult = feeService.calculateFee(_order!);

    // Show fee warning if applicable
    if (feeResult.fee > 0 && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancellation Fee', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'A cancellation fee of ₹${feeResult.fee.toStringAsFixed(0)} '
            '(${(feeResult.feeRate * 100).toStringAsFixed(0)}%) applies at this stage.\n\n'
            'Refund: ₹${feeResult.netRefund.toStringAsFixed(0)} will be credited to your wallet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    // FIX (Module 10): applyAndRefund must run for every cancellation, not just
    // fee>0 ones. It already handles the fee==0 case correctly (refunds the
    // full amount, skips the fee ledger entry) and is idempotent via a
    // deterministic ledger doc ID — the previous `if (feeResult.fee > 0)` gate
    // meant early-stage (0% fee) cancellations never got refunded at all.
    try {
      await feeService.applyAndRefund(
        order: _order!,
        cancelledBy: 'customer',
        reason: 'Cancelled by customer',
      );
    } catch (e) {
      debugPrint('[OrderDetail] Fee apply error: $e');
    }

    final success = await orderProvider.cancelOrder(
      _order!.id,
      'Cancelled by user',
    );
    if (mounted && success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order Cancelled')));
      // StreamBuilder will automatically refresh when Firestore data changes
    }
  }

  Future<void> _requestReturn(String reason) async {
    if (reason.isEmpty) return;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final success = await orderProvider.createReturnRequest(
      orderId: _order!.id,
      reason: reason,
      itemIds: _order!.items.map((i) => i.id).toList(),
    );
    if (mounted && success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Return Requested')));
      // StreamBuilder will automatically refresh when Firestore data changes
    }
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _buildPackingAndWeightProofSection() {
    if (_rawOrderData == null) return const SizedBox.shrink();

    final hasPackingProof = _rawOrderData!['packingProof'] != null;
    final hasWeightProof = _weightProofs.isNotEmpty;

    if (!hasPackingProof && !hasWeightProof) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Trust & Quality Proofs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 1. Packing Proof
          if (hasPackingProof) ...[
            _buildPackingProofCard(),
            if (hasWeightProof) const SizedBox(height: 16),
          ],

          // 2. Weight Verification Proof (Real Weight Guarantee)
          if (hasWeightProof) ...[_buildWeightProofCard()],
        ],
      ),
    );
  }

  Widget _buildPackingProofCard() {
    final packingProof = _rawOrderData!['packingProof'] as Map<String, dynamic>;
    final photoUrl = packingProof['photoUrl'] as String?;
    final packedBy = packingProof['packedBy'] as String? ?? 'Our Team';
    final packedAtVal = packingProof['packedAt'];
    String timeStr = '';
    if (packedAtVal is Timestamp) {
      timeStr = DateFormat('h:mm a, d MMM yyyy').format(packedAtVal.toDate());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(
                Icons.inventory_2,
                size: 14,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Packed with care by $packedBy',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.grey900,
                    ),
                  ),
                  if (timeStr.isNotEmpty)
                    Text(
                      'Time: $timeStr',
                      style: const TextStyle(
                        color: AppTheme.grey50,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (photoUrl != null && photoUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _viewFullPhoto(photoUrl, 'Packing Proof'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CachedNetworkImage(
                    imageUrl: photoUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 140,
                      color: AppTheme.grey50,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'View Photo Proof',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeightProofCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.scale, size: 14, color: Color(0xFF1565C0)),
            ),
            SizedBox(width: 10),
            Text(
              'Real Weight Guarantee',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.grey900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _weightProofs.length,
          itemBuilder: (context, index) {
            final proof = _weightProofs[index];
            final diff = proof.packedWeightKg - proof.orderedWeightKg;

            Color outcomeColor;
            String statusText;
            IconData statusIcon;

            switch (proof.outcome) {
              case WeightOutcome.exact:
                outcomeColor = const Color(0xFF2E7D32);
                statusText = 'Perfect weight';
                statusIcon = Icons.check_circle_outline;
                break;
              case WeightOutcome.overPacked:
                outcomeColor = const Color(0xFF1565C0);
                statusText = '+${diff.toStringAsFixed(2)}kg free extra!';
                statusIcon = Icons.card_giftcard;
                break;
              case WeightOutcome.underPacked:
                outcomeColor = const Color(0xFFE65100);
                statusText =
                    'Underweight (₹${proof.refundAmountIfAny.round()} refunded)';
                statusIcon = Icons.monetization_on_outlined;
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.grey200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proof.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: AppTheme.grey900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ordered: ${proof.orderedWeightKg.toStringAsFixed(2)} kg  •  Packed: ${proof.packedWeightKg.toStringAsFixed(2)} kg',
                          style: const TextStyle(
                            color: AppTheme.grey600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: outcomeColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: outcomeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (proof.photoUrl != null &&
                          proof.photoUrl!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _viewFullPhoto(
                            proof.photoUrl!,
                            'Weight Proof: ${proof.productName}',
                          ),
                          child: const Text(
                            'View Photo 📸',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _viewFullPhoto(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    height: 300,
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

