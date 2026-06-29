import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/monetary_value.dart';

/// Represents a single line item in an invoice
class InvoiceItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double taxRate; // 5%, 12%, 18%, or 28%
  final MonetaryValue amount; // quantity * unitPrice
  final MonetaryValue tax; // amount * (taxRate / 100)

  InvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.taxRate,
    required this.amount,
    required this.tax,
  });

  /// Total price including tax
  MonetaryValue get totalAmount => amount + tax;

  /// Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxRate': taxRate,
      'amount': amount,
      'tax': tax,
    };
  }

  /// Create from Firestore map
  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: (map['unitPrice'] as num? ?? 0.0).toDouble(),
      taxRate: (map['taxRate'] as num? ?? 0.0).toDouble(),
      amount: MonetaryValue(map['amount'] ?? 0.0),
      tax: MonetaryValue(map['tax'] ?? 0.0),
    );
  }

  @override
  String toString() =>
      'InvoiceItem(product: $productName, qty: $quantity, tax: $taxRate%)';
}

/// Payment status enum
enum PaymentStatus {
  paid,
  unpaid,
  partial;

  String get displayName {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partial:
        return 'Partial';
    }
  }

  String get json {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.partial:
        return 'partial';
    }
  }

  static PaymentStatus fromJson(String? value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'partial':
        return PaymentStatus.partial;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

/// Complete invoice model for GST compliance and transparency
class InvoiceModel {
  final String invoiceId; // Unique document ID
  final String invoiceNumber; // Sequential: INV_001, INV_002, etc.
  final String orderId; // Reference to order
  final String customerId;
  final String customerName;
  final String shopId;
  final String shopName;

  final List<InvoiceItem> items;

  final MonetaryValue subtotal; // Sum of all item amounts (before tax & discount)
  final MonetaryValue totalTax; // Sum of all item taxes
  final MonetaryValue discount; // Applied discount (if any)
  final MonetaryValue grandTotal; // subtotal + totalTax - discount

  final String? billingAddress;
  final String? shippingAddress;
  final String? customerEmail;
  final String? customerPhone;

  final DateTime issueDate;
  final DateTime? dueDate;

  final String? paymentMethod; // Credit Card, UPI, COD, etc.
  final PaymentStatus paymentStatus;

  final String? notes;
  final String? pdfUrl; // Cloud Storage URL for generated PDF

  final DateTime createdAt;
  final DateTime? updatedAt;

  final bool isImmutable; // Once issued, should not be edited
  final String? gstNumber; // Shop's GSTIN

  InvoiceModel({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.subtotal,
    required this.totalTax,
    required this.discount,
    required this.grandTotal,
    this.billingAddress,
    this.shippingAddress,
    this.customerEmail,
    this.customerPhone,
    required this.issueDate,
    this.dueDate,
    this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.pdfUrl,
    required this.createdAt,
    this.updatedAt,
    this.isImmutable = true,
    this.gstNumber,
  });

  /// Get tax breakdown by rate for compliance reporting
  Map<double, double> getTaxBreakdown() {
    final breakdown = <double, double>{};
    for (var item in items) {
      breakdown[item.taxRate] = (breakdown[item.taxRate] ?? 0) + item.tax.toDouble();
    }
    return breakdown;
  }

  /// Format currency with Indian locale
  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'shopId': shopId,
      'shopName': shopName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'totalTax': totalTax,
      'discount': discount,
      'grandTotal': grandTotal,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'issueDate': issueDate,
      'dueDate': dueDate,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus.json,
      'notes': notes,
      'pdfUrl': pdfUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isImmutable': isImmutable,
      'gstNumber': gstNumber,
    };
  }

  /// Create from Firestore map
  factory InvoiceModel.fromMap(String id, Map<String, dynamic> map) {
    return InvoiceModel(
      invoiceId: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => InvoiceItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: MonetaryValue(map['subtotal'] ?? 0.0),
      totalTax: MonetaryValue(map['totalTax'] ?? 0.0),
      discount: MonetaryValue(map['discount'] ?? 0.0),
      grandTotal: MonetaryValue(map['grandTotal'] ?? 0.0),
      billingAddress: map['billingAddress'] as String?,
      shippingAddress: map['shippingAddress'] as String?,
      customerEmail: map['customerEmail'] as String?,
      customerPhone: map['customerPhone'] as String?,
      issueDate: (map['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      paymentMethod: map['paymentMethod'] as String?,
      paymentStatus:
          PaymentStatus.fromJson(map['paymentStatus'] as String?),
      notes: map['notes'] as String?,
      pdfUrl: map['pdfUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isImmutable: map['isImmutable'] as bool? ?? true,
      gstNumber: map['gstNumber'] as String?,
    );
  }

  /// Create from Firestore DocumentSnapshot
  factory InvoiceModel.fromDocSnapshot(DocumentSnapshot doc) {
    return InvoiceModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  @override
  String toString() => 'Invoice($invoiceNumber - ₹$grandTotal - $paymentStatus)';
}
