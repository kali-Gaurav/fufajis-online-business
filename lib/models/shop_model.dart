import 'package:cloud_firestore/cloud_firestore.dart';

enum ShopApprovalStatus { draft, under_review, approved, rejected }

class ShopModel {
  final String shopId;
  final String shopName;
  final String ownerUid;
  final DateTime createdAt;
  final bool active;
  final String? address;
  final String? contactPhone;
  final ShopApprovalStatus approvalStatus;

  /// Percentage of each order's total commissioned to the platform.
  /// The remainder (totalAmount - commission) is owed to the vendor and
  /// is what Task #53's automated payout job aggregates for payout.
  final double commissionPercent;

  /// Bank/payout details used by the automated vendor payout flow.
  /// Required before a vendor payout request can be approved & paid.
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankAccountHolderName;

  /// Shop's GSTIN (15-char GST Identification Number), required on every
  /// GST-compliant tax invoice generated for this shop (Task #54).
  final String? gstNumber;

  ShopModel({
    required this.shopId,
    required this.shopName,
    required this.ownerUid,
    required this.createdAt,
    this.active = true,
    this.address,
    this.contactPhone,
    this.approvalStatus = ShopApprovalStatus
        .approved, // Default to approved for backward compatibility, but new flows should start at draft
    this.commissionPercent = 10.0,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankAccountHolderName,
    this.gstNumber,
  });

  factory ShopModel.fromMap(Map<String, dynamic> map) {
    return ShopModel(
      shopId: map['shopId'] as String? ?? '',
      shopName: map['shopName'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      active: map['active'] as bool? ?? true,
      address: map['address'] as String?,
      contactPhone: map['contactPhone'] as String?,
      approvalStatus: ShopApprovalStatus.values.firstWhere(
        (e) => e.name == map['approvalStatus'] as String?,
        orElse: () => ShopApprovalStatus.approved,
      ),
      commissionPercent: (map['commissionPercent'] as num?)?.toDouble() ?? 10.0,
      bankAccountNumber: map['bankAccountNumber'] as String?,
      bankIfsc: map['bankIfsc'] as String?,
      bankAccountHolderName: map['bankAccountHolderName'] as String?,
      gstNumber: map['gstNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'ownerUid': ownerUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'active': active,
      'address': address,
      'contactPhone': contactPhone,
      'approvalStatus': approvalStatus.name,
      'commissionPercent': commissionPercent,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
      'bankAccountHolderName': bankAccountHolderName,
      'gstNumber': gstNumber,
    };
  }

  bool get hasPayoutDetails =>
      (bankAccountNumber?.isNotEmpty ?? false) && (bankIfsc?.isNotEmpty ?? false);

  ShopModel copyWith({
    String? shopId,
    String? shopName,
    String? ownerUid,
    DateTime? createdAt,
    bool? active,
    String? address,
    String? contactPhone,
    ShopApprovalStatus? approvalStatus,
    double? commissionPercent,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankAccountHolderName,
    String? gstNumber,
  }) {
    return ShopModel(
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      active: active ?? this.active,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankAccountHolderName: bankAccountHolderName ?? this.bankAccountHolderName,
      gstNumber: gstNumber ?? this.gstNumber,
    );
  }
}
