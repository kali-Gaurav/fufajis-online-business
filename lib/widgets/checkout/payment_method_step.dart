import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../models/payment_method.dart';
import '../../services/payment_method_validator.dart';
import '../../widgets/payment_method_selector.dart';
import '../../utils/app_theme.dart';

/// Step 2: Payment Method Selection Widget
class PaymentMethodStep extends StatefulWidget {
  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onMethodSelected;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const PaymentMethodStep({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<PaymentMethodStep> createState() => _PaymentMethodStepState();
}

class _PaymentMethodStepState extends State<PaymentMethodStep> {
  late PaymentMethod _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  void didUpdateWidget(PaymentMethodStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMethod != widget.selectedMethod) {
      setState(() {
        _selectedMethod = widget.selectedMethod;
      });
    }
  }

  void _validateAndContinue() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    bool isValid = true;
    String errorMessage = '';

    if (_selectedMethod == PaymentMethod.wallet) {
      if (walletProvider.walletBalance < cartProvider.total) {
        isValid = false;
        errorMessage = 'Insufficient wallet balance (Available: ₹${walletProvider.walletBalance.round()})';
      }
    } else if (_selectedMethod == PaymentMethod.credit) {
      if (user != null) {
        if (user.creditBalance + cartProvider.total > user.creditLimit) {
          isValid = false;
          errorMessage = 'Exceeds credit limit (Remaining: ₹${(user.creditLimit - user.creditBalance).round()})';
        }
      } else {
        isValid = false;
        errorMessage = 'User profile not found for credit check.';
      }
    } else {
      isValid = PaymentMethodValidator.validatePaymentMethod(
        _selectedMethod,
        cartProvider.total,
        walletBalance: walletProvider.walletBalance,
        isPayLaterEligible: _checkPayLaterEligibility(),
        creditLimit: user?.creditLimit ?? 5000.0,
        creditBalance: user?.creditBalance ?? 0.0,
      );
      if (!isValid) {
        errorMessage = PaymentMethodValidator.getUnavailabilityReason(
          _selectedMethod,
          cartProvider.total,
          walletBalance: walletProvider.walletBalance,
          isPayLaterEligible: _checkPayLaterEligibility(),
          creditLimit: user?.creditLimit ?? 5000.0,
          creditBalance: user?.creditBalance ?? 0.0,
        );
      }
    }

    if (isValid) {
      widget.onContinue();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final creditLimit = user?.creditLimit ?? 5000.0;
    final creditBalance = user?.creditBalance ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              color: AppTheme.primary,
            ),
            const Expanded(
              child: Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Order total display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey700,
                ),
              ),
              Text(
                '₹${cartProvider.total.round()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payment method selector
        Container(
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
          child: PaymentMethodSelector(
            selectedMethod: _selectedMethod,
            orderTotal: cartProvider.total,
            walletBalance: orderProvider.walletBalance,
            isPayLaterEligible: _checkPayLaterEligibility(),
            creditLimit: creditLimit,
            creditBalance: creditBalance,
            onMethodSelected: (method) {
              setState(() => _selectedMethod = method);
              widget.onMethodSelected(method);
            },
            showWalletBalance: true,
            compactMode: false,
          ),
        ),

        const SizedBox(height: 24),

        // Continue button
        ElevatedButton(
          onPressed: _validateAndContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: AppTheme.grey300,
          ),
          child: const Text(
            'Continue to Review',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  bool _checkPayLaterEligibility() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return orderProvider.walletBalance >= 0;
  }
}

/// Compact payment method selection for inline use
class CompactPaymentMethodStep extends StatelessWidget {
  final PaymentMethod selectedMethod;
  final ValueChanged<PaymentMethod> onMethodSelected;

  const CompactPaymentMethodStep({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 12),
        PaymentMethodSelector(
          selectedMethod: selectedMethod,
          orderTotal: cartProvider.total,
          walletBalance: orderProvider.walletBalance,
          isPayLaterEligible: true,
          onMethodSelected: onMethodSelected,
          showWalletBalance: true,
          compactMode: true,
        ),
      ],
    );
  }
}

