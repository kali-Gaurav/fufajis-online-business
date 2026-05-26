import 'package:flutter/material.dart';
import '../models/payment_method.dart';

/// Service for validating payment methods and checking eligibility
class PaymentMethodValidator {
  /// Minimum order amount for Cash on Delivery (in rupees)
  static const double codMinimumAmount = 100;

  /// Maximum order amount for Cash on Delivery (in rupees)
  static const double codMaximumAmount = 10000;

  /// Minimum wallet balance required to show wallet option
  static const double minimumWalletBalance = 10;

  /// Minimum order amount for Pay Later (BNPL)
  static const double payLaterMinimumAmount = 200;

  /// Maximum order amount for Pay Later (BNPL)
  static const double payLaterMaximumAmount = 50000;

  /// Minimum order amount for EMI
  static const double emiMinimumAmount = 3000;

  

  /// Validate if a payment method is valid for the given order total
  static bool validatePaymentMethod(
    PaymentMethod method,
    double orderTotal, {
    double walletBalance = 0,
    bool isPayLaterEligible = false,
  }) {
    switch (method) {
      case PaymentMethod.cod:
        return _validateCod(orderTotal);
      case PaymentMethod.wallet:
        return _validateWallet(orderTotal, walletBalance);
      case PaymentMethod.payLater:
        return _validatePayLater(orderTotal, isPayLaterEligible);
      case PaymentMethod.emi:
        return _validateEmi(orderTotal);
      case PaymentMethod.upi:
      case PaymentMethod.card:
      case PaymentMethod.netBanking:
      case PaymentMethod.razorpay:
        return orderTotal > 0;
      case PaymentMethod.credit:
        // TODO: Handle this case.
        throw UnimplementedError();
      case PaymentMethod.loyaltyPoints:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  /// Validate Cash on Delivery
  static bool _validateCod(double orderTotal) {
    return orderTotal >= codMinimumAmount && orderTotal <= codMaximumAmount;
  }

  /// Validate Wallet payment
  static bool _validateWallet(double orderTotal, double walletBalance) {
    return walletBalance >= minimumWalletBalance &&
           walletBalance > 0 &&
           orderTotal > 0;
  }

  /// Validate Pay Later (BNPL)
  static bool _validatePayLater(double orderTotal, bool isEligible) {
    return isEligible &&
           orderTotal >= payLaterMinimumAmount &&
           orderTotal <= payLaterMaximumAmount;
  }

  /// Validate EMI
  static bool _validateEmi(double orderTotal) {
    return orderTotal >= emiMinimumAmount;
  }

  /// Get payment method details
  static PaymentMethodOption getPaymentMethodDetails(
    PaymentMethod method, {
    double walletBalance = 0,
    bool isPayLaterEligible = false,
  }) {
    final option = PaymentMethodOption.fromMethod(method);

    // Update wallet balance if applicable
    if (method == PaymentMethod.wallet) {
      return option.withWalletBalance(walletBalance);
    }

    // Add Pay Later badge if eligible
    if (method == PaymentMethod.payLater && isPayLaterEligible) {
      return option.copyWith(
        showBadge: true,
        badgeText: 'No Interest',
      );
    }

    return option;
  }

  /// Get all available payment methods for an order
  static List<PaymentMethodOption> getAvailablePaymentMethods(
    double orderTotal, {
    double walletBalance = 0,
    bool isPayLaterEligible = false,
  }) {
    return PaymentMethodOption.allOptions.map((option) {
      final isAvailable = validatePaymentMethod(
        option.method,
        orderTotal,
        walletBalance: walletBalance,
        isPayLaterEligible: isPayLaterEligible,
      );

      // Update wallet balance display
      if (option.method == PaymentMethod.wallet) {
        return option
            .withWalletBalance(walletBalance)
            .copyWith(isAvailable: isAvailable);
      }

      // Update Pay Later badge
      if (option.method == PaymentMethod.payLater) {
        return option.copyWith(
          isAvailable: isAvailable,
          showBadge: isPayLaterEligible,
          badgeText: isPayLaterEligible ? 'No Interest' : null,
        );
      }

      return option.copyWith(isAvailable: isAvailable);
    }).toList();
  }

  /// Get reason why a payment method is unavailable
  static String getUnavailabilityReason(
    PaymentMethod method,
    double orderTotal, {
    double walletBalance = 0,
    bool isPayLaterEligible = false,
  }) {
    switch (method) {
      case PaymentMethod.cod:
        if (orderTotal < codMinimumAmount) {
          return 'Minimum order amount for COD is ₹${codMinimumAmount.round()}';
        }
        if (orderTotal > codMaximumAmount) {
          return 'COD not available for orders above ₹${codMaximumAmount.round()}';
        }
        return 'Cash on Delivery is not available';

      case PaymentMethod.wallet:
        if (walletBalance < minimumWalletBalance) {
          return 'Insufficient wallet balance (minimum ₹$minimumWalletBalance)';
        }
        return 'Wallet balance not available';

      case PaymentMethod.payLater:
        if (!isPayLaterEligible) {
          return 'Pay Later is not available for your account';
        }
        if (orderTotal < payLaterMinimumAmount) {
          return 'Minimum order amount for Pay Later is ₹${payLaterMinimumAmount.round()}';
        }
        if (orderTotal > payLaterMaximumAmount) {
          return 'Pay Later not available for orders above ₹${payLaterMaximumAmount.round()}';
        }
        return 'Pay Later is not available';

      case PaymentMethod.emi:
        if (orderTotal < emiMinimumAmount) {
          return 'Minimum order amount for EMI is ₹${emiMinimumAmount.round()}';
        }
        return 'EMI is not available';

      case PaymentMethod.upi:
      case PaymentMethod.card:
      case PaymentMethod.netBanking:
      case PaymentMethod.razorpay:
        return 'This payment method is currently unavailable';
      case PaymentMethod.credit:
        // TODO: Handle this case.
        throw UnimplementedError();
      case PaymentMethod.loyaltyPoints:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  /// Check if payment method requires online payment
  static bool requiresOnlinePayment(PaymentMethod method) {
    return PaymentMethodOption.isOnlinePayment(method);
  }

  /// Get recommended payment methods based on order total
  static List<PaymentMethod> getRecommendedMethods(
    double orderTotal, {
    double walletBalance = 0,
    bool isPayLaterEligible = false,
  }) {
    final recommendations = <PaymentMethod>[];

    // Always recommend COD if within limits
    if (_validateCod(orderTotal)) {
      recommendations.add(PaymentMethod.cod);
    }

    // Recommend UPI for all orders
    recommendations.add(PaymentMethod.upi);

    // Recommend wallet if sufficient balance
    if (_validateWallet(orderTotal, walletBalance)) {
      recommendations.add(PaymentMethod.wallet);
    }

    // Recommend Pay Later if eligible
    if (_validatePayLater(orderTotal, isPayLaterEligible)) {
      recommendations.add(PaymentMethod.payLater);
    }

    // Recommend Razorpay for larger orders
    if (orderTotal > 500) {
      recommendations.add(PaymentMethod.razorpay);
    }

    return recommendations;
  }

  /// Calculate maximum wallet amount that can be used
  static double calculateMaxWalletAmount(
    double orderTotal,
    double walletBalance,
  ) {
    // Wallet limited to 50% of order value
    final maxWalletAllowed = orderTotal * 0.5;
    return walletBalance.clamp(0, maxWalletAllowed);
  }

  /// Check if wallet can cover full order
  static bool walletCanCoverOrder(double orderTotal, double walletBalance) {
    return walletBalance >= orderTotal;
  }

  /// Get payment method icon
  static IconData getPaymentIcon(PaymentMethod method) {
    return PaymentMethodOption.getIcon(method);
  }

  /// Get payment method color
  static Color getPaymentColor(PaymentMethod method) {
    return PaymentMethodOption.getColor(method);
  }

  /// Format payment method for display
  static String formatPaymentMethod(PaymentMethod method) {
    return PaymentMethodOption.getDisplayName(method);
  }
}
