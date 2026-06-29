import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/order_status.dart';
import 'user_model.dart';
import 'delivery_type.dart';
import 'payment_method.dart';
import '../utils/monetary_value.dart';

/// Represents a single status transition in the order history
class StatusHistoryEntry {
  final OrderStatus status;
  final DateTime timestamp;
  final String? note;
  final String? actorId;
  final String? actorRole;
  final String? actorName;

  const StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.note,
    this.actorId,
    this.actorRole,
    this.actorName,
  });

  factory StatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return StatusHistoryEntry(
      status: OrderStatus.fromString(map['status']),
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      note: map['note'],
      actorId: map['actorId'],
      actorRole: map['actorRole'],
      actorName: map['actorName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.firestoreValue,
      'timestamp': timestamp,
      'note': note,
      'actorId': actorId,
      'actorRole': actorRole,
      'actorName': actorName,
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
  final String? barcode;
  final String productName;
  final String productImage;
  final String unit;
  final int quantity;
  final MonetaryValue price;
  final MonetaryValue? originalPrice;
  final MonetaryValue? discountPercentage;
  final MonetaryValue totalPrice;
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
  final MonetaryValue? proposedReplacementPrice;
  final DateTime? substitutionTimestamp;
  final String? specialInstructions;

  /// Convenience getter for productName (alias for compatibility)
  String get name => productName;

  OrderItem({
    required this.id,
    required this.productId,
    this.barcode,
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
    this.specialInstructions,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      barcode: map['barcode'],
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      unit: map['unit'] ?? 'piece',
      quantity: map['quantity'] ?? 1,
      price: MonetaryValue(map['price'] ?? 0.0),
      originalPrice: map['originalPrice'] != null ? MonetaryValue(map['originalPrice']) : null,
      discountPercentage: map['discountPercentage'] != null ? MonetaryValue(map['discountPercentage']) : null,
      totalPrice: MonetaryValue(map['totalPrice'] ?? 0.0),
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
      proposedReplacementPrice: map['proposedReplacementPrice'] != null
          ? MonetaryValue(map['proposedReplacementPrice']) : null,
      substitutionTimestamp: map['substitutionTimestamp'] != null
          ? (map['substitutionTimestamp'] is Timestamp
                ? (map['substitutionTimestamp'] as Timestamp).toDate()
                : DateTime.tryParse(map['substitutionTimestamp'].toString()))
          : null,
      specialInstructions: map['specialInstructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'barcode': barcode,
      'productName': productName,
      'productImage': productImage,
      'unit': unit,
      'quantity': quantity,
      'price': price.toFirestore(),
      'originalPrice': originalPrice?.toFirestore(),
      'discountPercentage': discountPercentage?.toFirestore(),
      'totalPrice': totalPrice.toFirestore(),
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
      'proposedReplacementPrice': proposedReplacementPrice?.toFirestore(),
      'substitutionTimestamp': substitutionTimestamp != null
          ? Timestamp.fromDate(substitutionTimestamp!)
          : null,
    };
  }

  OrderItem copyWith({
    String? id,
    String? productId,
    String? barcode,
    String? productName,
    String? productImage,
    String? unit,
    int? quantity,
    MonetaryValue? price,
    MonetaryValue? originalPrice,
    MonetaryValue? discountPercentage,
    MonetaryValue? totalPrice,
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
    MonetaryValue? proposedReplacementPrice,
    DateTime? substitutionTimestamp,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      barcode: barcode ?? this.barcode,
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
      proposedReplacementId:
          proposedReplacementId ?? this.proposedReplacementId,
      proposedReplacementName:
          proposedReplacementName ?? this.proposedReplacementName,
      proposedReplacementPrice:
          proposedReplacementPrice ?? this.proposedReplacementPrice,
      substitutionTimestamp:
          substitutionTimestamp ?? this.substitutionTimestamp,
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
  final MonetaryValue subtotal;
  final MonetaryValue deliveryCharge;
  final MonetaryValue discount;
  final MonetaryValue tax;
  final MonetaryValue totalAmount;
  MonetaryValue get total => totalAmount;
  final MonetaryValue walletAmountUsed;
  final MonetaryValue cashbackEarned;
  final int rewardPointsUsed;
  final int rewardPointsEarned;
  final int loyaltyPointsUsed;  // Alias for rewardPointsUsed for compatibility
  final PaymentMethod paymentMethod; 
  final PaymentMethod selectedPaymentMethod; 
  final String? paymentId;
  final String? paymentStatus;
  final String? paymentConvertedFrom; 
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
  final MonetaryValue? deliveryFee;
  final MonetaryValue tipAmount;
  final MonetaryValue packagingFee;
  final bool isGift;
  final String? giftMessage;
  final List<StatusHistoryEntry> statusHistory;
  final GeoPoint? liveLocation;
  final double? rating;
  final String? packingStatus;

  /// Getters for task assignment compatibility
  double? get deliveryLat => deliveryAddress.latitude;
  double? get deliveryLon => deliveryAddress.longitude;
  final String? packingRejectionReason;
  final Map<String, dynamic>? packingProof;
  final List<dynamic>? packingHistory;
  final DateTime? packingStartedAt;
  final DateTime? packingCompletedAt;
  final Map<String, MonetaryValue>? splitPayment;
  final String? branchId;
  final String? couponCode;
  final MonetaryValue? couponDiscount;
  final String? cartHash;
  final String? invoiceId;
  final String? invoiceNumber;

  Color get statusColor => status.color;
  bool get isAwaitingPackingApproval => packingStatus == 'pending_approval';

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.items,
    required this.subtotal,
    MonetaryValue? deliveryCharge,
    MonetaryValue? discount,
    MonetaryValue? tax,
    required this.totalAmount,
    MonetaryValue? walletAmountUsed,
    MonetaryValue? cashbackEarned,
    this.rewardPointsUsed = 0,
    this.rewardPointsEarned = 0,
    int? loyaltyPointsUsed,
    this.paymentMethod = PaymentMethod.cod,
    this.selectedPaymentMethod = PaymentMethod.cod,
    this.paymentId,
    this.paymentStatus,
    this.paymentConvertedFrom,
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
    MonetaryValue? tipAmount,
    MonetaryValue? packagingFee,
    this.isGift = false,
    this.giftMessage,
    this.statusHistory = const [],
    this.liveLocation,
    this.rating,
    this.packingStatus,
    this.packingRejectionReason,
    this.packingProof,
    this.packingHistory,
    this.packingStartedAt,
    this.packingCompletedAt,
    this.splitPayment,
    this.branchId,
    this.couponCode,
    this.couponDiscount,
    this.cartHash,
    this.invoiceId,
    this.invoiceNumber,
  }) : deliveryCharge = deliveryCharge ?? MonetaryValue(0.0),
       discount = discount ?? MonetaryValue(0.0),
       tax = tax ?? MonetaryValue(0.0),
       walletAmountUsed = walletAmountUsed ?? MonetaryValue(0.0),
       cashbackEarned = cashbackEarned ?? MonetaryValue(0.0),
       tipAmount = tipAmount ?? MonetaryValue(0.0),
       packagingFee = packagingFee ?? MonetaryValue(0.0),
       loyaltyPointsUsed = loyaltyPointsUsed ?? rewardPointsUsed;

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    final id = map['id'] ?? doc.id;
    return OrderModel.fromMap({...map, 'id': id});
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      orderNumber: map['orderNumber'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      customerEmail: map['customerEmail'],
      items: (map['items'] as List?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: MonetaryValue(map['subtotal'] ?? 0.0),
      deliveryCharge: MonetaryValue(map['deliveryCharge'] ?? 0.0),
      discount: MonetaryValue(map['discount'] ?? 0.0),
      tax: MonetaryValue(map['tax'] ?? 0.0),
      totalAmount: MonetaryValue(map['totalAmount'] ?? 0.0),
      walletAmountUsed: MonetaryValue(map['walletAmountUsed'] ?? 0.0),
      cashbackEarned: MonetaryValue(map['cashbackEarned'] ?? 0.0),
      rewardPointsUsed: map['rewardPointsUsed'] ?? map['loyaltyPointsUsed'] ?? 0,
      rewardPointsEarned: map['rewardPointsEarned'] ?? 0,
      loyaltyPointsUsed: map['loyaltyPointsUsed'] ?? map['rewardPointsUsed'] ?? 0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == map['paymentMethod'],
        orElse: () => PaymentMethod.cod,
      ),
      selectedPaymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.toString() == (map['selectedPaymentMethod'] ?? map['paymentMethod']),
        orElse: () => PaymentMethod.cod,
      ),
      paymentId: map['paymentId'],
      paymentStatus: map['paymentStatus'],
      paymentConvertedFrom: map['paymentConvertedFrom'],
      status: OrderStatus.fromString(map['status']),
      deliveryType: DeliveryType.values.firstWhere(
        (e) => e.toString() == map['deliveryType'],
        orElse: () => DeliveryType.standard,
      ),
      deliveryAddress: Address.fromMap(Map<String, dynamic>.from(map['deliveryAddress'] ?? {})),
      deliveryInstructions: map['deliveryInstructions'],
      scheduledDeliveryDate: map['scheduledDeliveryDate'] != null
          ? (map['scheduledDeliveryDate'] is Timestamp
                ? (map['scheduledDeliveryDate'] as Timestamp).toDate()
                : map['scheduledDeliveryDate'])
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
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] is Timestamp
                ? (map['deliveredAt'] as Timestamp).toDate()
                : map['deliveredAt'])
          : null,
      deliveryFee: map['deliveryFee'] != null ? MonetaryValue(map['deliveryFee']) : null,
      tipAmount: MonetaryValue(map['tipAmount'] ?? 0.0),
      packagingFee: MonetaryValue(map['packagingFee'] ?? 0.0),
      isGift: map['isGift'] ?? false,
      giftMessage: map['giftMessage'],
      statusHistory: (map['statusHistory'] as List?)
              ?.map((entry) => StatusHistoryEntry.fromMap(entry as Map<String, dynamic>))
              .toList() ??
          [],
      liveLocation: map['liveLocation'] as GeoPoint?,
      rating: (map['rating'] as num?)?.toDouble(),
      packingStatus: map['packingStatus'],
      packingRejectionReason: map['packingRejectionReason'],
      packingProof: map['packingProof'] != null ? Map<String, dynamic>.from(map['packingProof'] as Map) : null,
      packingHistory: map['packingHistory'] as List<dynamic>?,
      packingStartedAt: map['packingStartedAt'] != null
          ? (map['packingStartedAt'] is Timestamp
              ? (map['packingStartedAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['packingStartedAt'].toString()))
          : null,
      packingCompletedAt: map['packingCompletedAt'] != null
          ? (map['packingCompletedAt'] is Timestamp
              ? (map['packingCompletedAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['packingCompletedAt'].toString()))
          : null,
      splitPayment: map['splitPayment'] != null 
          ? (map['splitPayment'] as Map).map((k, v) => MapEntry(k.toString(), MonetaryValue(v)))
          : null,
      branchId: map['branchId'],
      couponCode: map['couponCode'],
      couponDiscount: map['couponDiscount'] != null ? MonetaryValue(map['couponDiscount']) : null,
      cartHash: map['cartHash'],
      invoiceId: map['invoiceId'],
      invoiceNumber: map['invoiceNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal.toFirestore(),
      'deliveryCharge': deliveryCharge.toFirestore(),
      'discount': discount.toFirestore(),
      'tax': tax.toFirestore(),
      'totalAmount': totalAmount.toFirestore(),
      'walletAmountUsed': walletAmountUsed.toFirestore(),
      'cashbackEarned': cashbackEarned.toFirestore(),
      'rewardPointsUsed': rewardPointsUsed,
      'rewardPointsEarned': rewardPointsEarned,
      'loyaltyPointsUsed': loyaltyPointsUsed,
      'paymentMethod': paymentMethod.toString(),
      'selectedPaymentMethod': selectedPaymentMethod.toString(),
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'paymentConvertedFrom': paymentConvertedFrom,
      'status': status.firestoreValue,
      'deliveryType': deliveryType.toString(),
      'deliveryAddress': deliveryAddress.toMap(),
      'deliveryInstructions': deliveryInstructions,
      'scheduledDeliveryDate': scheduledDeliveryDate != null ? Timestamp.fromDate(scheduledDeliveryDate!) : null,
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'deliveryFee': deliveryFee?.toFirestore(),
      'tipAmount': tipAmount.toFirestore(),
      'packagingFee': packagingFee.toFirestore(),
      'isGift': isGift,
      'giftMessage': giftMessage,
      'statusHistory': statusHistory.map((entry) => entry.toMap()).toList(),
      'liveLocation': liveLocation,
      'packingStatus': packingStatus,
      'packingRejectionReason': packingRejectionReason,
      'packingProof': packingProof,
      'packingHistory': packingHistory,
      'packingStartedAt': packingStartedAt != null ? Timestamp.fromDate(packingStartedAt!) : null,
      'packingCompletedAt': packingCompletedAt != null ? Timestamp.fromDate(packingCompletedAt!) : null,
      'splitPayment': splitPayment?.map((k, v) => MapEntry(k, v.toFirestore())),
      'branchId': branchId,
      'couponCode': couponCode,
      'couponDiscount': couponDiscount?.toFirestore(),
      'cartHash': cartHash,
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
    };
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    List<OrderItem>? items,
    MonetaryValue? subtotal,
    MonetaryValue? deliveryCharge,
    MonetaryValue? discount,
    MonetaryValue? tax,
    MonetaryValue? totalAmount,
    MonetaryValue? walletAmountUsed,
    MonetaryValue? cashbackEarned,
    int? rewardPointsUsed,
    int? rewardPointsEarned,
    PaymentMethod? paymentMethod,
    PaymentMethod? selectedPaymentMethod,
    String? paymentId,
    String? paymentStatus,
    String? paymentConvertedFrom,
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
    MonetaryValue? deliveryFee,
    MonetaryValue? tipAmount,
    MonetaryValue? packagingFee,
    bool? isGift,
    String? giftMessage,
    List<StatusHistoryEntry>? statusHistory,
    GeoPoint? liveLocation,
    double? rating,
    String? packingStatus,
    String? packingRejectionReason,
    Map<String, dynamic>? packingProof,
    List<dynamic>? packingHistory,
    DateTime? packingStartedAt,
    DateTime? packingCompletedAt,
    Map<String, MonetaryValue>? splitPayment,
    String? branchId,
    String? couponCode,
    MonetaryValue? couponDiscount,
    String? cartHash,
    String? invoiceId,
    String? invoiceNumber,
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
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      paymentId: paymentId ?? this.paymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentConvertedFrom: paymentConvertedFrom ?? this.paymentConvertedFrom,
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
      packingStatus: packingStatus ?? this.packingStatus,
      packingRejectionReason: packingRejectionReason ?? this.packingRejectionReason,
      packingProof: packingProof ?? this.packingProof,
      packingHistory: packingHistory ?? this.packingHistory,
      packingStartedAt: packingStartedAt ?? this.packingStartedAt,
      packingCompletedAt: packingCompletedAt ?? this.packingCompletedAt,
      splitPayment: splitPayment ?? this.splitPayment,
      branchId: branchId ?? this.branchId,
      couponCode: couponCode ?? this.couponCode,
      couponDiscount: couponDiscount ?? this.couponDiscount,
      cartHash: cartHash ?? this.cartHash,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    );
  }

  bool isValidTransition(OrderStatus newStatus) {
    return status.canTransitionTo(newStatus);
  }

  OrderModel updateStatus(OrderStatus newStatus, {String? note, String? actorId, String? actorRole, String? actorName, bool force = false}) {
    if (!force && !isValidTransition(newStatus)) {
      throw StateError('Invalid order status transition from $status to $newStatus');
    }

    final now = DateTime.now();
    final newEntry = StatusHistoryEntry(
      status: newStatus,
      timestamp: now,
      note: note,
      actorId: actorId,
      actorRole: actorRole,
      actorName: actorName,
    );

    return copyWith(
      status: newStatus,
      updatedAt: now,
      statusHistory: [...statusHistory, newEntry],
    );
  }

  String generateDeliveryOTP() {
    final random = DateTime.now().millisecond + DateTime.now().microsecond;
    final otp = List.generate(6, (index) => (random + index * 7) % 10).join();
    return otp;
  }

  int get totalItemCount {
    return items.fold(0, (total, item) => total + item.quantity);
  }

  MonetaryValue get totalSavings {
    return items.fold(MonetaryValue(0.0), (total, item) {
      if (item.originalPrice != null) {
        return total + ((item.originalPrice! - item.price) * item.quantity);
      }
      return total;
    });
  }

  bool get canCancel => status.canCancel;
  bool get canReturn => status.canReturn;
  bool get isActive => status.isActive;
  bool get isTerminal => status.isTerminal;

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
