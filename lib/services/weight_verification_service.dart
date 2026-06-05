import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Component — Real Weight Guarantee Service (Feature 3)
///
/// Policy:
///   • Weight verification applies to vegetables & fruits categories ONLY
///   • If packed weight > ordered weight by ≤5%: charged as ordered (benefit to customer)
///   • If packed weight > ordered weight by >5%: store absorbs the difference
///   • If packed weight < ordered weight: partial refund automatically issued
///   • Photo proof stored in Firebase Storage; URL saved to order record
class WeightVerificationService {
  static final WeightVerificationService _instance =
      WeightVerificationService._internal();
  factory WeightVerificationService() => _instance;
  WeightVerificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final Uuid _uuid = const Uuid();

  // Categories that require weight verification
  static const Set<String> _weightVerifiedCategories = {'vegetables', 'fruits'};

  // Acceptable over-pack tolerance (customer is not charged for this)
  static const double _overPackTolerancePercent = 5.0;

  // ─────────────── PUBLIC API ───────────────

  /// Returns true if this product category requires weight verification
  bool requiresWeightVerification(String category) {
    return _weightVerifiedCategories.contains(category.toLowerCase());
  }

  /// Records weight verification for a single order item.
  /// Returns a [WeightProofRecord] with the outcome and any adjustment.
  Future<WeightProofRecord> recordWeightVerification({
    required String orderId,
    required String orderItemId,
    required String productId,
    required String productName,
    required double orderedWeightKg,
    required double packedWeightKg,
    required String employeeId,
    required String employeeName,
    XFile? proofPhoto,
  }) async {
    String? photoUrl;
    if (proofPhoto != null) {
      photoUrl = await _uploadProofPhoto(
        orderId: orderId,
        productId: productId,
        file: proofPhoto,
      );
    }

    final outcome = _computeOutcome(orderedWeightKg, packedWeightKg);

    final record = WeightProofRecord(
      id: _uuid.v4(),
      orderId: orderId,
      orderItemId: orderItemId,
      productId: productId,
      productName: productName,
      orderedWeightKg: orderedWeightKg,
      packedWeightKg: packedWeightKg,
      outcome: outcome,
      refundAmountIfAny: 0, // computed separately by caller based on price/kg
      photoUrl: photoUrl,
      employeeId: employeeId,
      employeeName: employeeName,
      recordedAt: DateTime.now(),
    );

    await _saveRecord(record);
    return record;
  }

  /// Computes the refund amount for under-packing.
  /// Call this after [recordWeightVerification] if outcome == underPacked.
  double computeRefundAmount({
    required double orderedWeightKg,
    required double packedWeightKg,
    required double pricePerKg,
  }) {
    if (packedWeightKg >= orderedWeightKg) return 0;
    final shortfallKg = orderedWeightKg - packedWeightKg;
    return (shortfallKg * pricePerKg).roundToDouble();
  }

  /// Captures a proof photo using the device camera.
  Future<XFile?> captureProofPhoto() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1024,
      );
    } catch (e) {
      debugPrint('[WeightVerification] Camera capture failed: $e');
      return null;
    }
  }

  /// Fetches all weight proof records for an order (for customer view).
  Future<List<WeightProofRecord>> getOrderWeightProofs(String orderId) async {
    try {
      final snap = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('weight_proofs')
          .get();
      return snap.docs.map((d) => WeightProofRecord.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('[WeightVerification] getOrderWeightProofs error: $e');
      return [];
    }
  }

  // ─────────────── PRIVATE ───────────────

  WeightOutcome _computeOutcome(double ordered, double packed) {
    if (packed >= ordered) {
      final overPercent = ((packed - ordered) / ordered) * 100;
      if (overPercent <= _overPackTolerancePercent) {
        return WeightOutcome.exact; // within tolerance
      }
      return WeightOutcome.overPacked; // store absorbs
    }
    return WeightOutcome.underPacked; // triggers partial refund
  }

  Future<void> _saveRecord(WeightProofRecord record) async {
    await _firestore
        .collection('orders')
        .doc(record.orderId)
        .collection('weight_proofs')
        .doc(record.id)
        .set(record.toMap());

    // Update order item with weight proof flag
    await _firestore.collection('orders').doc(record.orderId).update({
      'hasWeightProof': true,
      'weightProofStatus': record.outcome.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '[WeightVerification] Recorded: ${record.productName} ${record.orderedWeightKg}kg → ${record.packedWeightKg}kg (${record.outcome.name})',
    );
  }

  Future<String?> _uploadProofPhoto({
    required String orderId,
    required String productId,
    required XFile file,
  }) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      final ref = _storage
          .ref()
          .child('weight_proofs')
          .child(orderId)
          .child('$productId.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[WeightVerification] Photo upload failed: $e');
      return null;
    }
  }
}

// ─────────────── VALUE OBJECTS ───────────────

enum WeightOutcome { exact, overPacked, underPacked }

class WeightProofRecord {
  final String id;
  final String orderId;
  final String orderItemId;
  final String productId;
  final String productName;
  final double orderedWeightKg;
  final double packedWeightKg;
  final WeightOutcome outcome;
  final double refundAmountIfAny;
  final String? photoUrl;
  final String employeeId;
  final String employeeName;
  final DateTime recordedAt;

  const WeightProofRecord({
    required this.id,
    required this.orderId,
    required this.orderItemId,
    required this.productId,
    required this.productName,
    required this.orderedWeightKg,
    required this.packedWeightKg,
    required this.outcome,
    required this.refundAmountIfAny,
    this.photoUrl,
    required this.employeeId,
    required this.employeeName,
    required this.recordedAt,
  });

  String get outcomeLabel {
    switch (outcome) {
      case WeightOutcome.exact:
        return '✅ Exact Weight';
      case WeightOutcome.overPacked:
        return '📦 Slightly Over (No Extra Charge)';
      case WeightOutcome.underPacked:
        return '⚠️ Under — Partial Refund Applied';
    }
  }

  String get weightSummary =>
      'Ordered: ${orderedWeightKg.toStringAsFixed(2)} kg  •  Packed: ${packedWeightKg.toStringAsFixed(2)} kg';

  Map<String, dynamic> toMap() => {
    'id': id,
    'orderId': orderId,
    'orderItemId': orderItemId,
    'productId': productId,
    'productName': productName,
    'orderedWeightKg': orderedWeightKg,
    'packedWeightKg': packedWeightKg,
    'outcome': outcome.name,
    'refundAmountIfAny': refundAmountIfAny,
    'photoUrl': photoUrl ?? '',
    'employeeId': employeeId,
    'employeeName': employeeName,
    'recordedAt': Timestamp.fromDate(recordedAt),
  };

  factory WeightProofRecord.fromMap(Map<String, dynamic> map) =>
      WeightProofRecord(
        id: map['id'] ?? '',
        orderId: map['orderId'] ?? '',
        orderItemId: map['orderItemId'] ?? '',
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        orderedWeightKg: (map['orderedWeightKg'] ?? 0).toDouble(),
        packedWeightKg: (map['packedWeightKg'] ?? 0).toDouble(),
        outcome: WeightOutcome.values.firstWhere(
          (e) => e.name == map['outcome'],
          orElse: () => WeightOutcome.exact,
        ),
        refundAmountIfAny: (map['refundAmountIfAny'] ?? 0).toDouble(),
        photoUrl: map['photoUrl'] as String?,
        employeeId: map['employeeId'] ?? '',
        employeeName: map['employeeName'] ?? '',
        recordedAt: map['recordedAt'] is Timestamp
            ? (map['recordedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
