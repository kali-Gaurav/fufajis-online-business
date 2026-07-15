import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_config.dart';
import '../../utils/app_theme.dart';
import '../../widgets/shimmer_loading.dart';

/// Customer Wallet — shows balance, transaction history, and add-money CTA.
///
/// SECURITY FIX (Module 10): top-up now goes through a real Razorpay payment.
/// Previously the quick-add buttons credited the wallet directly with no
/// payment — any customer could mint unlimited spendable balance.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final Razorpay _razorpay = Razorpay();
  double _pendingAmount = 0;
  String _pendingUserId = '';

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _startTopUp(BuildContext context, double amount, String userId, AuthProvider auth) {
    final key = AppConfig.razorpayKeyId;
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payments are not configured. Please try again later.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    _pendingAmount = amount;
    _pendingUserId = userId;
    _razorpay.open(<String, dynamic>{
      'key': key,
      'amount': (amount * 100).toInt(), // paise
      'name': "Fufaji's Online",
      'description': 'Wallet Top-up ₹${amount.toStringAsFixed(0)}',
      'prefill': {
        'contact': auth.currentUser?.phoneNumber ?? '',
        'name': auth.currentUser?.name ?? 'Customer',
      },
      'notes': {'type': 'wallet_topup', 'customer_id': userId},
      'theme': {'color': '#FF5722'},
    });
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final wp = context.read<WalletProvider>();
    final success = await wp.addMoney(
      _pendingUserId,
      _pendingAmount,
      paymentId: response.paymentId ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '₹${_pendingAmount.toStringAsFixed(0)} added to wallet!'
              : 'Payment received but crediting failed — contact support with payment ID ${response.paymentId}.',
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.code == Razorpay.PAYMENT_CANCELLED
              ? 'Payment cancelled.'
              : 'Payment failed. Please try again.',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer2<WalletProvider, AuthProvider>(
        builder: (context, wp, auth, _) {
          final userId = auth.currentUser?.id ?? 'user_001';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ── Balance hero card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  boxShadow: AppTheme.primaryGlowShadows(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Fufaji Wallet Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹ ${wp.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Available to spend on any Fufaji order',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                    // Quick add-money row
                    Row(
                      children: [
                        _QuickAddButton(
                          amount: 100,
                          onTap: () => _startTopUp(context, 100, userId, auth),
                        ),
                        const SizedBox(width: 8),
                        _QuickAddButton(
                          amount: 200,
                          onTap: () => _startTopUp(context, 200, userId, auth),
                        ),
                        const SizedBox(width: 8),
                        _QuickAddButton(
                          amount: 500,
                          onTap: () => _startTopUp(context, 500, userId, auth),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Stats row ────────────────────────────────────────────────
              Row(
                children: [
                  _StatTile(
                    label: 'Total Added',
                    value:
                        '₹ ${wp.transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount).toStringAsFixed(0)}',
                    icon: Icons.arrow_downward_rounded,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    label: 'Total Spent',
                    value:
                        '₹ ${wp.transactions.where((t) => t.amount < 0).fold(0.0, (s, t) => s + t.amount.abs()).toStringAsFixed(0)}',
                    icon: Icons.arrow_upward_rounded,
                    color: AppTheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Transactions ─────────────────────────────────────────────
              Row(
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const Spacer(),
                  if (wp.transactions.isNotEmpty)
                    Text(
                      '${wp.transactions.length} records',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (wp.isLoading)
                const TransactionListSkeleton(count: 5)
              else if (wp.transactions.isEmpty)
                _buildEmptyTransactions()
              else
                ...wp.transactions.map((tx) => _TransactionTile(tx: tx)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.grey900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add money or place an order to get started',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.grey500),
          ),
        ],
      ),
    );
  }
}

// ── Quick Add Button ────────────────────────────────────────────────────────
class _QuickAddButton extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;
  const _QuickAddButton({required this.amount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Text(
            '+₹$amount',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ── Stat Tile ───────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadows,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.grey500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction Tile ────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final dynamic tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCredit
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
              color: isCredit ? AppTheme.success : AppTheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? tx.type.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  tx.timestamp.toString().substring(0, 16),
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? "+" : ""}₹ ${tx.amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isCredit ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
