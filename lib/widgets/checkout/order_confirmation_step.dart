import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';

/// Step 4: Order Confirmation Widget
class OrderConfirmationStep extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onTrackOrder;
  final VoidCallback onContinueShopping;

  const OrderConfirmationStep({
    super.key,
    required this.order,
    required this.onTrackOrder,
    required this.onContinueShopping,
  });

  @override
  State<OrderConfirmationStep> createState() => _OrderConfirmationStepState();
}

class _OrderConfirmationStepState extends State<OrderConfirmationStep> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .snapshots(),
      builder: (context, snapshot) {
        OrderModel currentOrder = widget.order;
        if (snapshot.hasData && snapshot.data!.exists) {
          currentOrder = OrderModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
        }

        final bool isWaitingForPayment = currentOrder.status == OrderStatus.pending;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success or Waiting animation and message
              _buildStatusSection(currentOrder, isWaitingForPayment),
              const SizedBox(height: 24),

              // Order details card
              _buildOrderDetailsCard(currentOrder),
              const SizedBox(height: 12),

              // Delivery info card
              _buildDeliveryInfoCard(currentOrder),
              const SizedBox(height: 12),

              // Payment info card
              _buildPaymentInfoCard(currentOrder),
              const SizedBox(height: 24),

              // Action buttons
              _buildActionButtons(),
              const SizedBox(height: 16),

              // Help section
              _buildHelpSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusSection(OrderModel order, bool isWaiting) {
    return Column(
      children: [
        // Animated icon or loader
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: (isWaiting ? AppTheme.warning : AppTheme.success).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: isWaiting
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppTheme.warning),
                )
              : const Icon(
                  Icons.check_circle,
                  color: AppTheme.success,
                  size: 80,
                ),
        ),
        const SizedBox(height: 24),
        Text(
          isWaiting ? 'Verifying Payment...' : 'Order Placed!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 8),
        if (isWaiting)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Please stay on this screen while we verify your transaction with the bank.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Order #${order.orderNumber}',
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isWaiting ? AppTheme.warning : AppTheme.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            order.status.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isWaiting ? AppTheme.warning : AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Row(
            children: [
              Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.take(3).map((item) => _buildOrderItemRow(item)),
          if (order.items.length > 3) ...[
            const SizedBox(height: 8),
            Text(
              '+${order.items.length - 3} more items',
              style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
            ),
          ],
          const Divider(height: 24),
          _buildOrderSummaryRow('Items Total', order.subtotal),
          const SizedBox(height: 8),
          _buildOrderSummaryRow(
            'Delivery',
            order.deliveryCharge,
            isFree: order.deliveryCharge == 0,
          ),
          if (order.discount > 0) ...[
            const SizedBox(height: 8),
            _buildOrderSummaryRow('Discount', -order.discount, isDiscount: true),
          ],
          if (order.walletAmountUsed > 0) ...[
            const SizedBox(height: 8),
            _buildOrderSummaryRow(
              'Wallet Used',
              -order.walletAmountUsed,
              isDiscount: true,
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Text(
                '₹${order.totalAmount.round()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.productImage.isNotEmpty
                ? Image.network(item.productImage, fit: BoxFit.cover)
                : const Icon(Icons.image, color: AppTheme.grey400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Qty: ${item.quantity} × ₹${item.price.round()}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalPrice.round()}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryRow(String label, double value,
      {bool isFree = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isFree ? AppTheme.success : AppTheme.grey600,
          ),
        ),
        Text(
          isDiscount
              ? '- ₹${value.abs().round()}'
              : isFree
                  ? 'FREE'
                  : '₹${value.round()}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isFree
                ? AppTheme.success
                : isDiscount
                    ? AppTheme.success
                    : AppTheme.grey900,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInfoCard(OrderModel order) {
    final estimatedDate = order.scheduledDeliveryDate ??
        DateTime.now().add(const Duration(days: 2));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Row(
            children: [
              Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Delivery Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, color: AppTheme.grey500, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Estimated Delivery: ',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
              Text(
                '${estimatedDate.day}/${estimatedDate.month}/${estimatedDate.year}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: AppTheme.grey500, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.deliveryAddress.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    Text(
                      order.deliveryAddress.fullAddress,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                    if (order.deliveryAddress.landmark.isNotEmpty)
                      Text(
                        'Landmark: ${order.deliveryAddress.landmark}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard(OrderModel order) {
    final paymentMethodName = order.paymentMethod.toString().split('.').last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          const Row(
            children: [
              Icon(Icons.payment, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Method',
                style: TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
              Text(
                paymentMethodName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          if (order.paymentId != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction ID',
                  style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                ),
                Text(
                  order.paymentId!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onTrackOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Track Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onContinueShopping,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.headset_mic, color: AppTheme.grey600, size: 20),
              SizedBox(width: 8),
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHelpButton(Icons.chat, 'Chat'),
              _buildHelpButton(Icons.phone, 'Call'),
              _buildHelpButton(Icons.receipt, 'Invoice'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpButton(IconData icon, String label) {
    return InkWell(
      onTap: () {
        // Handle help action
      },
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }
}


