import 'package:flutter/material.dart';

/// Payment method options for order payment
enum PaymentMethod {
  cod,
  upi,
  card,
  netBanking,
  wallet,
  razorpay,
  emi,
  payLater,
  credit, // Feature: Khata system for local trust
  loyaltyPoints, // New Feature: Pay using loyalty points
}

/// Extension on PaymentMethod for display properties
extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cod:
        return 'Cash on Delivery';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Credit/Debit Card';
      case PaymentMethod.netBanking:
        return 'Net Banking';
      case PaymentMethod.wallet:
        return 'Wallet';
      case PaymentMethod.razorpay:
        return 'Razorpay';
      case PaymentMethod.emi:
        return 'EMI';
      case PaymentMethod.payLater:
        return 'Pay Later';
      case PaymentMethod.credit:
        return 'Fufaji Credit';
      case PaymentMethod.loyaltyPoints:
        return 'Loyalty Points';
    }
  }
}

/// Model representing a payment method option with details
class PaymentMethodOption {
  final PaymentMethod method;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool isAvailable;
  final String? subLabel;
  final bool showBadge;
  final String? badgeText;
  final double? minAmount; // New Feature: Minimum amount required
  final double? cashbackPercentage; // New Feature: Cashback offer

  PaymentMethodOption({
    required this.method,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.isAvailable = true,
    this.subLabel,
    this.showBadge = false,
    this.badgeText,
    this.minAmount,
    this.cashbackPercentage,
  });

  /// Cash on Delivery option
  static final PaymentMethodOption cod = PaymentMethodOption(
    method: PaymentMethod.cod,
    name: 'Cash on Delivery',
    description: 'Pay when you receive your order',
    icon: Icons.money_outlined,
    iconColor: const Color(0xFF4CAF50),
  );

  /// UPI payment option
  static final PaymentMethodOption upi = PaymentMethodOption(
    method: PaymentMethod.upi,
    name: 'UPI',
    description: 'Google Pay, PhonePe, Paytm & more',
    icon: Icons.qr_code,
    iconColor: const Color(0xFF673AB7),
    cashbackPercentage: 2.0, // Offer 2% cashback on UPI
  );

  /// Credit/Debit Card option
  static final PaymentMethodOption card = PaymentMethodOption(
    method: PaymentMethod.card,
    name: 'Credit / Debit Card',
    description: 'All major cards accepted',
    icon: Icons.credit_card,
    iconColor: const Color(0xFF2196F3),
  );

  /// Net Banking option
  static final PaymentMethodOption netBanking = PaymentMethodOption(
    method: PaymentMethod.netBanking,
    name: 'Net Banking',
    description: 'Direct bank transfer',
    icon: Icons.account_balance,
    iconColor: const Color(0xFF607D8B),
  );

  /// Wallet Balance option
  static final PaymentMethodOption wallet = PaymentMethodOption(
    method: PaymentMethod.wallet,
    name: 'Wallet Balance',
    description: 'Use your Fufaji wallet balance',
    icon: Icons.account_balance_wallet,
    iconColor: const Color(0xFFFF9800),
    subLabel: 'Available: ₹0',
  );

  /// Razorpay payment option
  static final PaymentMethodOption razorpay = PaymentMethodOption(
    method: PaymentMethod.razorpay,
    name: 'Razorpay',
    description: 'Cards, UPI, Wallet & Net Banking',
    icon: Icons.payment,
    iconColor: const Color(0xFF3399CC),
  );

  /// EMI option
  static final PaymentMethodOption emi = PaymentMethodOption(
    method: PaymentMethod.emi,
    name: 'EMI',
    description: 'Easy monthly installments',
    icon: Icons.calendar_today,
    iconColor: const Color(0xFF9C27B0),
    minAmount: 3000.0, // EMI only available for orders > 3000
  );

  /// Pay Later (Buy Now Pay Later) option
  static final PaymentMethodOption payLater = PaymentMethodOption(
    method: PaymentMethod.payLater,
    name: 'Pay Later',
    description: 'Buy now, pay after delivery',
    icon: Icons.schedule,
    iconColor: const Color(0xFFE91E63),
    showBadge: true,
    badgeText: 'BNPL',
  );

  /// Credit (Khata) option for loyal customers
  static final PaymentMethodOption credit = PaymentMethodOption(
    method: PaymentMethod.credit,
    name: 'Fufaji Credit (Khata)',
    description: 'Add to your monthly account',
    icon: Icons.menu_book,
    iconColor: const Color(0xFF795548),
  );

  /// Loyalty Points option
  static final PaymentMethodOption loyaltyPoints = PaymentMethodOption(
    method: PaymentMethod.loyaltyPoints,
    name: 'Loyalty Points',
    description: 'Redeem your earned points',
    icon: Icons.stars,
    iconColor: const Color(0xFFFFC107),
  );

  /// Get all available payment method options
  static List<PaymentMethodOption> get allOptions {
    return [
      cod,
      upi,
      razorpay,
      credit,
      wallet,
      card,
      netBanking,
      emi,
      payLater,
      loyaltyPoints,
    ];
  }

  /// Get payment method option by method
  static PaymentMethodOption fromMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cod:
        return cod;
      case PaymentMethod.upi:
        return upi;
      case PaymentMethod.card:
        return card;
      case PaymentMethod.netBanking:
        return netBanking;
      case PaymentMethod.wallet:
        return wallet;
      case PaymentMethod.razorpay:
        return razorpay;
      case PaymentMethod.emi:
        return emi;
      case PaymentMethod.payLater:
        return payLater;
      case PaymentMethod.credit:
        return credit;
      case PaymentMethod.loyaltyPoints:
        return loyaltyPoints;
    }
  }

  /// Get display name for payment method
  static String getDisplayName(PaymentMethod method) {
    return fromMethod(method).name;
  }

  /// Get icon for payment method
  static IconData getIcon(PaymentMethod method) {
    return fromMethod(method).icon;
  }

  /// Get color for payment method
  static Color getColor(PaymentMethod method) {
    return fromMethod(method).iconColor;
  }

  /// Check if payment method is online (requires internet)
  static bool isOnlinePayment(PaymentMethod method) {
    return [
      PaymentMethod.upi,
      PaymentMethod.card,
      PaymentMethod.netBanking,
      PaymentMethod.razorpay,
      PaymentMethod.emi,
      PaymentMethod.payLater,
    ].contains(method);
  }

  /// Check if payment method supports instant refund
  static bool supportsInstantRefund(PaymentMethod method) {
    return [
      PaymentMethod.upi,
      PaymentMethod.card,
      PaymentMethod.wallet,
      PaymentMethod.razorpay,
      PaymentMethod.loyaltyPoints,
    ].contains(method);
  }

  /// Update wallet balance subLabel
  PaymentMethodOption withWalletBalance(double balance) {
    if (method == PaymentMethod.wallet) {
      return PaymentMethodOption(
        method: method,
        name: name,
        description: description,
        icon: icon,
        iconColor: iconColor,
        isAvailable: isAvailable,
        subLabel: 'Available: ₹${balance.round()}',
        showBadge: showBadge,
        badgeText: badgeText,
        minAmount: minAmount,
        cashbackPercentage: cashbackPercentage,
      );
    }
    return this;
  }

  /// Update availability
  PaymentMethodOption copyWith({
    PaymentMethod? method,
    String? name,
    String? description,
    IconData? icon,
    Color? iconColor,
    bool? isAvailable,
    String? subLabel,
    bool? showBadge,
    String? badgeText,
    double? minAmount,
    double? cashbackPercentage,
  }) {
    return PaymentMethodOption(
      method: method ?? this.method,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      isAvailable: isAvailable ?? this.isAvailable,
      subLabel: subLabel ?? this.subLabel,
      showBadge: showBadge ?? this.showBadge,
      badgeText: badgeText ?? this.badgeText,
      minAmount: minAmount ?? this.minAmount,
      cashbackPercentage: cashbackPercentage ?? this.cashbackPercentage,
    );
  }

  factory PaymentMethodOption.fromMap(Map<String, dynamic> map) {
    return PaymentMethodOption(
      method: PaymentMethod.values.firstWhere(
        (e) => e.toString() == map['method'],
        orElse: () => PaymentMethod.cod,
      ),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      icon: Icons.payment,
      iconColor: Color(map['iconColor'] ?? 0xFF2196F3),
      isAvailable: map['isAvailable'] ?? true,
      subLabel: map['subLabel'],
      showBadge: map['showBadge'] ?? false,
      badgeText: map['badgeText'],
      minAmount: map['minAmount']?.toDouble(),
      cashbackPercentage: map['cashbackPercentage']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'method': method.toString(),
      'name': name,
      'description': description,
      'icon': icon.codePoint,
      'iconColor': iconColor.toARGB32(),
      'isAvailable': isAvailable,
      'subLabel': subLabel,
      'showBadge': showBadge,
      'badgeText': badgeText,
      'minAmount': minAmount,
      'cashbackPercentage': cashbackPercentage,
    };
  }
}
