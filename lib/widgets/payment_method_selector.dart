import 'package:flutter/material.dart';
import '../models/payment_method.dart';
import '../services/payment_method_validator.dart';
import '../utils/app_theme.dart';

/// Widget for selecting payment method with visual cards
class PaymentMethodSelector extends StatefulWidget {
  final PaymentMethod selectedMethod;
  final double orderTotal;
  final double walletBalance;
  final bool isPayLaterEligible;
  final double creditLimit;
  final double creditBalance;
  final ValueChanged<PaymentMethod> onMethodSelected;
  final bool showWalletBalance;
  final bool compactMode;

  const PaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.orderTotal,
    required this.walletBalance,
    required this.isPayLaterEligible,
    this.creditLimit = 5000.0,
    this.creditBalance = 0.0,
    required this.onMethodSelected,
    this.showWalletBalance = true,
    this.compactMode = false,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  late PaymentMethod _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  void didUpdateWidget(PaymentMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMethod != widget.selectedMethod) {
      _selectedMethod = widget.selectedMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableMethods = PaymentMethodValidator.getAvailablePaymentMethods(
      widget.orderTotal,
      walletBalance: widget.walletBalance,
      isPayLaterEligible: widget.isPayLaterEligible,
      creditLimit: widget.creditLimit,
      creditBalance: widget.creditBalance,
    );

    if (widget.compactMode) {
      return _buildCompactMode(availableMethods);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
        ),
        const SizedBox(height: 12),
        ...availableMethods.map((option) => _buildPaymentOption(option)),
        const SizedBox(height: 8),
        _buildPaymentHint(),
      ],
    );
  }

  Widget _buildPaymentOption(PaymentMethodOption option) {
    final isSelected = _selectedMethod == option.method;
    final icon = option.icon;
    final color = option.iconColor;
    final unavailabilityReason = !option.isAvailable
        ? PaymentMethodValidator.getUnavailabilityReason(
            option.method,
            widget.orderTotal,
            walletBalance: widget.walletBalance,
            isPayLaterEligible: widget.isPayLaterEligible,
            creditLimit: widget.creditLimit,
            creditBalance: widget.creditBalance,
          )
        : null;

    return GestureDetector(
      onTap: option.isAvailable
          ? () {
              setState(() => _selectedMethod = option.method);
              widget.onMethodSelected(option.method);
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: option.isAvailable
              ? (isSelected ? color.withValues(alpha: 0.08) : Colors.white)
              : AppTheme.grey100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: option.isAvailable ? (isSelected ? color : AppTheme.grey300) : AppTheme.grey200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: option.isAvailable ? 1.0 : 0.7,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: option.isAvailable
                        ? (isSelected ? color.withValues(alpha: 0.15) : AppTheme.grey100)
                        : AppTheme.grey200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: option.isAvailable
                        ? (isSelected ? color : AppTheme.grey600)
                        : AppTheme.grey400,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            option.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: option.isAvailable
                                  ? (isSelected ? color : AppTheme.grey900)
                                  : AppTheme.grey500,
                            ),
                          ),
                          if (option.showBadge && option.badgeText != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.badgeText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                      ),
                      if (option.subLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          option.subLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: option.method == PaymentMethod.wallet && widget.walletBalance > 0
                                ? AppTheme.success
                                : AppTheme.grey500,
                          ),
                        ),
                      ],
                      if (unavailabilityReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, size: 12, color: AppTheme.error),
                              const SizedBox(width: 4),
                              Text(
                                unavailabilityReason,
                                style: const TextStyle(fontSize: 11, color: AppTheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: option.isAvailable
                          ? (isSelected ? color : AppTheme.grey400)
                          : AppTheme.grey300,
                      width: 2,
                    ),
                    color: option.isAvailable && isSelected ? color : Colors.transparent,
                  ),
                  child: option.isAvailable && isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHint() {
    // Show wallet hint if wallet balance is available but not selected
    if (widget.walletBalance > 0 &&
        _selectedMethod != PaymentMethod.wallet &&
        widget.showWalletBalance) {
      final maxWalletAmount = PaymentMethodValidator.calculateMaxWalletAmount(
        widget.orderTotal,
        widget.walletBalance,
      );

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You have ₹${widget.walletBalance.round()} in wallet. Use up to ₹${maxWalletAmount.round()} on this order.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show Pay Later hint if eligible but not selected
    if (widget.isPayLaterEligible && _selectedMethod != PaymentMethod.payLater) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE91E63).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule, color: Color(0xFFE91E63), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pay Later available! Buy now, pay after delivery with no interest.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show COD hint if COD is selected
    if (_selectedMethod == PaymentMethod.cod) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pay cash when your order is delivered. No advance payment required!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompactMode(List<PaymentMethodOption> availableMethods) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableMethods.length,
        itemBuilder: (context, index) {
          final option = availableMethods[index];
          final isSelected = _selectedMethod == option.method;
          final color = option.iconColor;

          return GestureDetector(
            onTap: option.isAvailable
                ? () {
                    setState(() => _selectedMethod = option.method);
                    widget.onMethodSelected(option.method);
                  }
                : null,
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: option.isAvailable
                    ? (isSelected ? color.withValues(alpha: 0.1) : AppTheme.grey100)
                    : AppTheme.grey100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: option.isAvailable
                      ? (isSelected ? color : AppTheme.grey300)
                      : AppTheme.grey200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    option.icon,
                    color: option.isAvailable
                        ? (isSelected ? color : AppTheme.grey600)
                        : AppTheme.grey400,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.name.split(' ').first,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: option.isAvailable
                          ? (isSelected ? color : AppTheme.grey700)
                          : AppTheme.grey500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact payment method selector for smaller spaces
class CompactPaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selectedMethod;
  final double orderTotal;
  final double walletBalance;
  final bool isPayLaterEligible;
  final ValueChanged<PaymentMethod> onMethodSelected;

  const CompactPaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.orderTotal,
    required this.walletBalance,
    required this.isPayLaterEligible,
    required this.onMethodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PaymentMethodSelector(
      selectedMethod: selectedMethod,
      orderTotal: orderTotal,
      walletBalance: walletBalance,
      isPayLaterEligible: isPayLaterEligible,
      onMethodSelected: onMethodSelected,
      compactMode: true,
    );
  }
}

/// Payment method summary widget for order review
class PaymentMethodSummary extends StatelessWidget {
  final PaymentMethod method;
  final double? amount;
  final bool showAmount;

  const PaymentMethodSummary({
    super.key,
    required this.method,
    this.amount,
    this.showAmount = true,
  });

  @override
  Widget build(BuildContext context) {
    final option = PaymentMethodOption.fromMethod(method);
    final color = option.iconColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(option.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                Text(
                  option.description,
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
          if (showAmount && amount != null) ...[
            const SizedBox(width: 8),
            Text(
              '₹${amount!.round()}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
