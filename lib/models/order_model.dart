import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';
import 'delivery_type.dart';
import 'payment_method.dart';

/// Order status enum representing all possible order states
enum OrderStatus {
  pending,
  confirmed,
  processing,
  packed,
  outForDelivery,
  delivered,
  cancelled,
  returned,
  refunded,
}

/// Extension on OrderStatus for display properties
extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.packed:
        return 'Packed';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.returned:
        return 'Returned';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Order is awaiting confirmation';
      case OrderStatus.confirmed:
        return 'Order has been confirmed by the shop';
      case OrderStatus.processing:
        return 'Order is being prepared';
      case OrderStatus.packed:
        return 'Order has been packed and is ready for pickup';
      case OrderStatus.outForDelivery:
        return 'Order is out for delivery';
      case OrderStatus.delivered:
        return 'Order has been delivered';
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
      case OrderStatus.returned:
        return 'Order has been returned';
      case OrderStatus.refunded:
        return 'Refund has been processed';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.indigo;
      case OrderStatus.packed:
        return Colors.purple;
      case OrderStatus.outForDelivery:
        return Colors.cyan;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.returned:
        return Colors.deepOrange;
      case OrderStatus.refunded:
        return Colors.teal;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.processing:
        return Icons.sync;
      case OrderStatus.packed:
        return Icons.inventory_2;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.home;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.returned:
        return Icons.undo;
      case OrderStatus.refunded:
        return Icons.replay;
    }
  }

  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.processing ||
        this == OrderStatus.packed ||
        this == OrderStatus.outForDelivery;
  }

  bool get isTerminal {
    return this == OrderStatus.delivered ||
        this == OrderStatus.cancelled ||
        this == OrderStatus.returned ||
        this == OrderStatus.refunded;
  }

  bool get canCancel {
    return isActive && this != OrderStatus.outForDelivery;
  }

  bool get canReturn {
    return this == OrderStatus.delivered;
  }
}

/// Represents a single status transition in the order history
class StatusHistoryEntry {
  final OrderStatus status;
  final DateTime timestamp;
  final String? note;

  const StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.note,
  });

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.toString(),
      'timestamp': timestamp,
      'note': note,
    };
  }

  StatusHistoryEntry copyWith({
    OrderStatus? status,
    DateTime? timestamp,
    String? note,
  }) {
    return StatusHistoryEntry(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
    );
  }
}

/// Represents an individual item within an order
class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final String unit;
  final int quantity;
  final double price;
  final double? originalPrice;
  final double? discountPercentage;
  final double totalPrice;
  final String? shopId;
  final String? shopName;
  final String? selectedVariant;
  final String? selectedSize;
  final String? selectedColor;
  final bool isPacked;
  final bool isOutOfStock;
  final String? substitutionStatus; // 'pending', 'approved', 'declined'
  final String? proposedReplacementId;
  final String? proposedReplacementName;
  final double? proposedReplacementPrice;
  final DateTime? substitutionTimestamp;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.unit,
    required this.quantity,
    required this.price,
    this.originalPrice,
    this.discountPercentage,
    required this.totalPrice,
    this.shopId,
    this.shopName,
    this.selectedVariant,
    this.selectedSize,
    this.selectedColor,
    this.isPacked = false,
    this.isOutOfStock = false,
    this.substitutionStatus,
    this.proposedReplacementId,
    this.proposedReplacementName,
    this.proposedReplacementPrice,
    this.substitutionTimestamp,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      unit: map['unit'] ?? 'piece',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0.0).toDouble(),
      originalPrice: map['originalPrice']?.toDouble(),
      discountPercentage: map['discountPercentage']?.toDouble(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      shopId: map['shopId'],
      shopName: map['shopName'],
      selectedVariant: map['selectedVariant'],
      selectedSize: map['selectedSize'],
      selectedColor: map['selectedColor'],
      isPacked: map['isPacked'] ?? false,
      isOutOfStock: map['isOutOfStock'] ?? false,
      substitutionStatus: map['substitutionStatus'],
      proposedReplacementId: map['proposedReplacementId'],
      proposedReplacementName: map['proposedReplacementName'],
      proposedReplacementPrice: (map['proposedReplacementPrice'] as num?)?.toDouble(),
      substitutionTimestamp: map['substitutionTimestamp'] != null
          ? (map['substitutionTimestamp'] is Timestamp
              ? (map['substitutionTimestamp'] as Timestamp).toDate()
              : DateTime.tryParse(map['substitutionTimestamp'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'unit': unit,
      'quantity': quantity,
      'price': price,
      'originalPrice': originalPrice,
      'discountPercentage': discountPercentage,
      'totalPrice': totalPrice,
      'shopId': shopId,
      'shopName': shopName,
      'selectedVariant': selectedVariant,
      'selectedSize': selectedSize,
      'selectedColor': selectedColor,
      'isPacked': isPacked,
      'isOutOfStock': isOutOfStock,
      'substitutionStatus': substitutionStatus,
      'proposedReplacementId': proposedReplacementId,
      'proposedReplacementName': proposedReplacementName,
      'proposedReplacementPrice': proposedReplacementPrice,
      'substitutionTimestamp': substitutionTimestamp != null
          ? Timestamp.fromDate(substitutionTimestamp!)
          : null,
    };
  }

  OrderItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    String? unit,
    int? quantity,
    double? price,
    double? originalPrice,
    double? discountPercentage,
    double? totalPrice,
    String? shopId,
    String? shopName,
    String? selectedVariant,
    String? selectedSize,
    String? selectedColor,
    bool? isPacked,
    bool? isOutOfStock,
    String? substitutionStatus,
    String? proposedReplacementId,
    String? proposedReplacementName,
    double? proposedReplacementPrice,
    DateTime? substitutionTimestamp,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      totalPrice: totalPrice ?? this.totalPrice,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedColor: selectedColor ?? this.selectedColor,
      isPacked: isPacked ?? this.isPacked,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      substitutionStatus: substitutionStatus ?? this.substitutionStatus,
      proposedReplacementId: proposedReplacementId ?? this.proposedReplacementId,
      proposedReplacementName: proposedReplacementName ?? this.proposedReplacementName,
      proposedReplacementPrice: proposedReplacementPrice ?? this.proposedReplacementPrice,
      substitutionTimestamp: substitutionTimestamp ?? this.substitutionTimestamp,
    );
  }
}

/// Main order model representing a customer order
class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double discount;
  final double tax;
  final double totalAmount;
  final double walletAmountUsed;
  final double cashbackEarned;
  final int rewardPointsUsed;
  final int rewardPointsEarned;
  final PaymentMethod paymentMethod;
  final String? paymentId;
  final String? paymentStatus;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final Address deliveryAddress;
  final String? deliveryInstructions;
  final DateTime? scheduledDeliveryDate;
  final String? timeSlot;
  final String? deliveryAgentId;
  final String? deliveryAgentName;
  final String? deliveryAgentPhone;
  final String? shopId;
  final String? shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String? trackingNumber;
  final String? parcelId;
  final String? otp;
  final bool otpVerified;
  final String? cancellationReason;
  final String? returnReason;
  final String? invoiceUrl;
  final String? notes;
  final String? voiceLandmarkUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final double? deliveryFee;
  final double tipAmount;
  final double packagingFee;
  final bool isGift;
  final String? giftMessage;
  final List<StatusHistoryEntry> statusHistory;
  final GeoPoint? liveLocation;
  final double? rating;

  Color get statusColor => status.color;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.items,
    required this.subtotal,
    this.deliveryCharge = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.totalAmount,
    this.walletAmountUsed = 0.0,
    this.cashbackEarned = 0.0,
    this.rewardPointsUsed = 0,
    this.rewardPointsEarned = 0,
    this.paymentMethod = PaymentMethod.cod,
    this.paymentId,
    this.paymentStatus,
    this.status = OrderStatus.pending,
    this.deliveryType = DeliveryType.standard,
    required this.deliveryAddress,
    this.deliveryInstructions,
    this.scheduledDeliveryDate,
    this.timeSlot,
    this.deliveryAgentId,
    this.deliveryAgentName,
    this.deliveryAgentPhone,
    this.shopId,
    this.shopName,
    this.shopPhone,
    this.shopAddress,
    this.trackingNumber,
    this.parcelId,
    this.otp,
    this.otpVerified = false,
    this.cancellationReason,
    this.returnReason,
    this.invoiceUrl,
    this.notes,
    this.voiceLandmarkUrl,
    required this.createdAt,
    required this.updatedAt,
    this.deliveredAt,
    this.deliveryFee,
    this.tipAmount = 0.0,
    this.packagingFee = 0.0,
    this.isGift = false,
    this.giftMessage,
    this.statusHistory = const [],
    this.liveLocation,
    this.rating,
  });

  /// Creates an OrderModel from a Firestore document map
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerEmail: map['customerEmail'],
      items: (map['items'] as List?)
              ?.map((item) => OrderItem.fromMap(item))
              .toList() ??
          [],
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      deliveryCharge: (map['deliveryCharge'] ?? 0.0).toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      tax: (map['tax'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      walletAmountUsed: (map['walletAmountUsed'] ?? 0.0).toDouble(),
      cashbackEarned: (map['cashbackEarned'] ?? 0.0).toDouble(),
      rewardPointsUsed: map['rewardPointsUsed'] ?? 0,
      rewardPointsEarned: map['rewardPointsEarned'] ?? 0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == map['paymentMethod'],
        orElse: () => PaymentMethod.cod,
      ),
      paymentId: map['paymentId'],
      paymentStatus: map['paymentStatus'],
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      deliveryType: DeliveryType.values.firstWhere(
        (e) => e.toString() == map['deliveryType'],
        orElse: () => DeliveryType.standard,
      ),
      deliveryAddress: Address.fromMap(map['deliveryAddress'] ?? {}),
      deliveryInstructions: map['deliveryInstructions'],
      scheduledDeliveryDate: map['scheduledDeliveryDate'] != null
          ? (map['scheduledDeliveryDate'] is DateTime
              ? map['scheduledDeliveryDate']
              : map['scheduledDeliveryDate'].toDate())
          : null,
      timeSlot: map['timeSlot'],
      deliveryAgentId: map['deliveryAgentId'],
      deliveryAgentName: map['deliveryAgentName'],
      deliveryAgentPhone: map['deliveryAgentPhone'],
      shopId: map['shopId'],
      shopName: map['shopName'],
      shopPhone: map['shopPhone'],
      shopAddress: map['shopAddress'],
      trackingNumber: map['trackingNumber'],
      parcelId: map['parcelId'],
      otp: map['otp'],
      otpVerified: map['otpVerified'] ?? false,
      cancellationReason: map['cancellationReason'],
      returnReason: map['returnReason'],
      invoiceUrl: map['invoiceUrl'],
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt']
              : map['createdAt'].toDate())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is DateTime
              ? map['updatedAt']
              : map['updatedAt'].toDate())
          : DateTime.now(),
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] is DateTime
              ? map['deliveredAt']
              : map['deliveredAt'].toDate())
          : null,
      deliveryFee: map['deliveryFee']?.toDouble(),
      tipAmount: (map['tipAmount'] ?? 0.0).toDouble(),
      packagingFee: (map['packagingFee'] ?? 0.0).toDouble(),
      isGift: map['isGift'] ?? false,
      giftMessage: map['giftMessage'],
      statusHistory: (map['statusHistory'] as List?)
              ?.map((entry) => StatusHistoryEntry.fromMap(entry))
              .toList() ??
          [],
      liveLocation: map['liveLocation'] as GeoPoint?,
      rating: (map['rating'] as num?)?.toDouble(),
    );
  }

  /// Converts the OrderModel to a Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCharge': deliveryCharge,
      'discount': discount,
      'tax': tax,
      'totalAmount': totalAmount,
      'walletAmountUsed': walletAmountUsed,
      'cashbackEarned': cashbackEarned,
      'rewardPointsUsed': rewardPointsUsed,
      'rewardPointsEarned': rewardPointsEarned,
      'paymentMethod': paymentMethod.toString(),
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'status': status.toString(),
      'deliveryType': deliveryType.toString(),
      'deliveryAddress': deliveryAddress.toMap(),
      'deliveryInstructions': deliveryInstructions,
      'scheduledDeliveryDate': scheduledDeliveryDate,
      'timeSlot': timeSlot,
      'deliveryAgentId': deliveryAgentId,
      'deliveryAgentName': deliveryAgentName,
      'deliveryAgentPhone': deliveryAgentPhone,
      'shopId': shopId,
      'shopName': shopName,
      'shopPhone': shopPhone,
      'shopAddress': shopAddress,
      'trackingNumber': trackingNumber,
      'parcelId': parcelId,
      'otp': otp,
      'otpVerified': otpVerified,
      'cancellationReason': cancellationReason,
      'returnReason': returnReason,
      'invoiceUrl': invoiceUrl,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deliveredAt': deliveredAt,
      'deliveryFee': deliveryFee,
      'tipAmount': tipAmount,
      'packagingFee': packagingFee,
      'isGift': isGift,
      'giftMessage': giftMessage,
      'statusHistory': statusHistory.map((entry) => entry.toMap()).toList(),
      'liveLocation': liveLocation,
    };
  }

  /// Creates a copy of this OrderModel with modified fields
  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryCharge,
    double? discount,
    double? tax,
    double? totalAmount,
    double? walletAmountUsed,
    double? cashbackEarned,
    int? rewardPointsUsed,
    int? rewardPointsEarned,
    PaymentMethod? paymentMethod,
    String? paymentId,
    String? paymentStatus,
    OrderStatus? status,
    DeliveryType? deliveryType,
    Address? deliveryAddress,
    String? deliveryInstructions,
    DateTime? scheduledDeliveryDate,
    String? timeSlot,
    String? deliveryAgentId,
    String? deliveryAgentName,
    String? deliveryAgentPhone,
    String? shopId,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? trackingNumber,
    String? parcelId,
    String? otp,
    bool? otpVerified,
    String? cancellationReason,
    String? returnReason,
    String? invoiceUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    double? deliveryFee,
    double? tipAmount,
    double? packagingFee,
    bool? isGift,
    String? giftMessage,
    List<StatusHistoryEntry>? statusHistory,
    GeoPoint? liveLocation,
    double? rating,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      totalAmount: totalAmount ?? this.totalAmount,
      walletAmountUsed: walletAmountUsed ?? this.walletAmountUsed,
      cashbackEarned: cashbackEarned ?? this.cashbackEarned,
      rewardPointsUsed: rewardPointsUsed ?? this.rewardPointsUsed,
      rewardPointsEarned: rewardPointsEarned ?? this.rewardPointsEarned,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId: paymentId ?? this.paymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      scheduledDeliveryDate:
          scheduledDeliveryDate ?? this.scheduledDeliveryDate,
      timeSlot: timeSlot ?? this.timeSlot,
      deliveryAgentId: deliveryAgentId ?? this.deliveryAgentId,
      deliveryAgentName: deliveryAgentName ?? this.deliveryAgentName,
      deliveryAgentPhone: deliveryAgentPhone ?? this.deliveryAgentPhone,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      parcelId: parcelId ?? this.parcelId,
      otp: otp ?? this.otp,
      otpVerified: otpVerified ?? this.otpVerified,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      returnReason: returnReason ?? this.returnReason,
      invoiceUrl: invoiceUrl ?? this.invoiceUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tipAmount: tipAmount ?? this.tipAmount,
      packagingFee: packagingFee ?? this.packagingFee,
      isGift: isGift ?? this.isGift,
      giftMessage: giftMessage ?? this.giftMessage,
      statusHistory: statusHistory ?? this.statusHistory,
      liveLocation: liveLocation ?? this.liveLocation,
      rating: rating ?? this.rating,
    );
  }

  /// Updates the order status and adds an entry to status history
  OrderModel updateStatus(OrderStatus newStatus, {String? note}) {
    final now = DateTime.now();
    final newEntry = StatusHistoryEntry(
      status: newStatus,
      timestamp: now,
      note: note,
    );

    return copyWith(
      status: newStatus,
      updatedAt: now,
      statusHistory: [...statusHistory, newEntry],
    );
  }

  /// Generates a 6-digit OTP for delivery verification
  String generateDeliveryOTP() {
    final random = DateTime.now().millisecond + DateTime.now().microsecond;
    final otp = List.generate(6, (index) => (random + index * 7) % 10).join();
    return otp;
  }

  /// Gets the total number of items in the order
  int get totalItemCount {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  /// Gets the total discount amount (original price - sale price)
  double get totalSavings {
    return items.fold(0.0, (total, item) {
      if (item.originalPrice != null && item.discountPercentage != null) {
        return total +
            ((item.originalPrice! - item.price) * item.quantity);
      }
      return total;
    });
  }

  /// Checks if the order can be cancelled
  bool get canCancel => status.canCancel;

  /// Checks if the order can be returned
  bool get canReturn => status.canReturn;

  /// Checks if the order is in an active state
  bool get isActive => status.isActive;

  /// Checks if the order is in a terminal state
  bool get isTerminal => status.isTerminal;

  /// Gets the current status display info
  StatusDisplayInfo get statusDisplayInfo {
    return StatusDisplayInfo(
      status: status,
      displayName: status.displayName,
      description: status.description,
      color: status.color,
      icon: status.icon,
    );
  }
}

/// Helper class for displaying order status information
class StatusDisplayInfo {
  final OrderStatus status;
  final String displayName;
  final String description;
  final Color color;
  final IconData icon;

  const StatusDisplayInfo({
    required this.status,
    required this.displayName,
    required this.description,
    required this.color,
    required this.icon,
  });
}
