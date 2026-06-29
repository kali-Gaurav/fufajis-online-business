import 'package:cloud_firestore/cloud_firestore.dart';

enum InvoiceStatus { pending_match, matched, paid, disputed }

class SupplierInvoiceModel {
  final String id;
  final String purchaseOrderId;
  final String supplierId;
  final String invoiceNumber;
  final double billedAmount;
  final String? documentUrl;
  final InvoiceStatus status;
  final bool isThreeWayMatched;
  final DateTime createdAt;
  final DateTime dueDate;

  SupplierInvoiceModel({
    required this.id,
    required this.purchaseOrderId,
    required this.supplierId,
    required this.invoiceNumber,
    required this.billedAmount,
    this.documentUrl,
    this.status = InvoiceStatus.pending_match,
    this.isThreeWayMatched = false,
    required this.createdAt,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchaseOrderId': purchaseOrderId,
      'supplierId': supplierId,
      'invoiceNumber': invoiceNumber,
      'billedAmount': billedAmount,
      'documentUrl': documentUrl,
      'status': status.name,
      'isThreeWayMatched': isThreeWayMatched,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': Timestamp.fromDate(dueDate),
    };
  }

  factory SupplierInvoiceModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierInvoiceModel(
      id: docId,
      purchaseOrderId: map['purchaseOrderId'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      billedAmount: (map['billedAmount'] as num? ?? 0.0).toDouble(),
      documentUrl: map['documentUrl'] as String?,
      status: InvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => InvoiceStatus.pending_match,
      ),
      isThreeWayMatched: map['isThreeWayMatched'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
