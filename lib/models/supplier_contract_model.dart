import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractStatus { active, expired, pending_renewal, terminated }

class SupplierContractModel {
  final String id;
  final String supplierId;
  final String title;
  final DateTime contractStart;
  final DateTime contractEnd;
  final String paymentTerms; // e.g., "Net 30", "Cash on Delivery"
  final double creditLimit;
  final String gstNumber;
  final String? documentUrl;
  final ContractStatus status;
  final DateTime createdAt;

  SupplierContractModel({
    required this.id,
    required this.supplierId,
    required this.title,
    required this.contractStart,
    required this.contractEnd,
    required this.paymentTerms,
    required this.creditLimit,
    required this.gstNumber,
    this.documentUrl,
    this.status = ContractStatus.active,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'title': title,
      'contractStart': Timestamp.fromDate(contractStart),
      'contractEnd': Timestamp.fromDate(contractEnd),
      'paymentTerms': paymentTerms,
      'creditLimit': creditLimit,
      'gstNumber': gstNumber,
      'documentUrl': documentUrl,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory SupplierContractModel.fromMap(Map<String, dynamic> map, String docId) {
    return SupplierContractModel(
      id: docId,
      supplierId: map['supplierId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      contractStart: (map['contractStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      contractEnd: (map['contractEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentTerms: map['paymentTerms'] as String? ?? '',
      creditLimit: (map['creditLimit'] as num? ?? 0.0).toDouble(),
      gstNumber: map['gstNumber'] as String? ?? '',
      documentUrl: map['documentUrl'] as String?,
      status: ContractStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => ContractStatus.active,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
