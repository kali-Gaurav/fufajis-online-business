import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

/// Payment status screen with real-time Firestore listeners
///
/// Features:
/// - Real-time payment status updates (pending → authorized → completed)
/// - Auto-navigation to order confirmation when payment completes
/// - Shows transaction details and error messages
/// - Handles payment failures with retry option
class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;
  final String orderId;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
    required this.orderId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  // Track if we've already navigated to avoid duplicate navigation
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payment_transactions')
            .doc(widget.paymentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState('Payment not found');
          }

          final paymentData =
              snapshot.data!.data() as Map<String, dynamic>;

          final status = paymentData['status'] as String? ?? 'pending';
          final amount = paymentData['amount'] as num? ?? 0;
          final paymentMethod =
              paymentData['paymentMethod'] as String? ?? 'unknown';
          final createdAt = paymentData['createdAt'];
          final completedAt = paymentData['completedAt'];
          final errorMessage =
              paymentData['errorMessage'] as String?;

          // Auto-navigate when payment is completed
          if (status == 'completed' &&
              !_hasNavigated) {
            _hasNavigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.pushReplacement(
                  '/customer/order-confirmation/${widget.orderId}',
                );
              }
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status indicator
                _buildStatusIndicator(status),
                const SizedBox(height: 24),

                // Amount and details
                _buildAmountCard(
                  amount: amount,
                  paymentMethod: paymentMethod,
                ),
                const SizedBox(height: 24),

                // Transaction timeline
                _buildTransactionTimeline(
                  status: status,
                  createdAt: createdAt,
                  completedAt: completedAt,
                ),
                const SizedBox(height: 24),

                // Error message if payment failed
                if (errorMessage != null)
                  _buildErrorMessageCard(errorMessage),

                const SizedBox(height: 24),

                // Action buttons
                if (status == 'failed' || status == 'pending')
                  _buildRetryButton(),

                if (status == 'completed')
                  _buildSuccessMessage(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
          const SizedBox(height: 16),
          Text(
            'Processing payment...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait, do not close this screen',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load payment status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    late Color statusColor;
    late IconData statusIcon;
    late String statusText;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Processing Payment';
        break;
      case 'authorized':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Payment Authorized';
        break;
      case 'completed':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        statusText = 'Payment Successful';
        break;
      case 'failed':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        statusText = 'Payment Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withAlpha(200),
            statusColor.withAlpha(100),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(statusIcon, color: Colors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard({
    required num amount,
    required String paymentMethod,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Amount',
            style: TextStyle(
              color: AppTheme.grey600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.grey200),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Method',
                style: TextStyle(
                  color: AppTheme.grey600,
                  fontSize: 13,
                ),
              ),
              Text(
                paymentMethod.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTimeline({
    required String status,
    required dynamic createdAt,
    required dynamic completedAt,
  }) {
    final steps = [
      ('Initiated', 'pending', createdAt),
      ('Authorized', 'authorized', null),
      ('Completed', 'completed', completedAt),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transaction Timeline',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.indexed.map((entry) {
            final i = entry.$1;
            final step = entry.$2;
            final isCompleted =
                _isStatusCompleted(step.$2, status);
            final timestamp = step.$3;
            final isLast = i == steps.length - 1;

            String timeText = '–';
            if (timestamp is Timestamp) {
              timeText =
                  DateFormat('h:mm a').format(timestamp.toDate());
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isCompleted
                          ? AppTheme.primary
                          : AppTheme.grey300,
                      child: Icon(
                        isCompleted
                            ? Icons.check
                            : Icons.schedule,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 30,
                        color: AppTheme.grey300,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCompleted
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isCompleted
                              ? AppTheme.primary
                              : AppTheme.grey600,
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.grey600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorMessageCard(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.error.withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Failed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // Trigger retry logic - typically this would call
          // a payment service or redirect to payment gateway
          context.push(
            '/customer/payment/${widget.paymentId}',
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
        ),
        child: const Text('Retry Payment'),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.success.withAlpha(100),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: AppTheme.success,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Confirmed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your payment has been processed successfully.',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isStatusCompleted(String stepStatus, String currentStatus) {
    const statusOrder = ['pending', 'authorized', 'completed'];
    final stepIndex = statusOrder.indexOf(stepStatus);
    final currentIndex = statusOrder.indexOf(currentStatus);
    return stepIndex <= currentIndex;
  }
}
