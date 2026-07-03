import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import 'whatsapp_notification_service.dart';
import '../utils/monetary_value.dart';

/// Hybrid Out-of-Stock Substitute Service — Component 5
///
/// Decision chain:
///   1. Manual override by shop staff (Firestore /substitute_overrides/{productId})
///   2. Customer's saved preferences (Firestore /users/{uid}/substitution_prefs)
///   3. Rule-based scoring: same category + highest tag overlap + lowest price delta
///
/// Policy: NEVER automatically substitute without customer approval unless they
/// have opted in via "Always auto-approve substitutions" preference.
class HybridSubstituteService {
  static final HybridSubstituteService _instance = HybridSubstituteService._internal();
  factory HybridSubstituteService() => _instance;
  HybridSubstituteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────── MAIN ENTRY POINT ───────────────

  /// Finds the best substitute for an out-of-stock product.
  /// Returns null if no substitute is appropriate.
  Future<SubstituteResult?> findBestSubstitute({
    required ProductModel outOfStock,
    required String shopId,
    required String customerId,
    List<ProductModel>? catalogCache, // pass if already loaded to avoid re-fetch
  }) async {
    debugPrint('[HybridSubstitute] Finding substitute for: ${outOfStock.name}');

    // Step 1: Manual shop override (highest priority — staff decision)
    final override = await _getManualOverride(shopId: shopId, productId: outOfStock.id);
    if (override != null) {
      debugPrint('[HybridSubstitute] Manual override found: ${override.substitute.name}');
      return override;
    }

    // Step 2: Customer preference
    final preferredBrandId = await _getCustomerBrandPreference(customerId, outOfStock.id);

    // Step 3: Fetch live catalog
    final catalog = catalogCache ?? await _fetchCatalog(shopId, outOfStock.category);

    // Step 4: Score and pick
    final scored = _scoreSubstitutes(
      original: outOfStock,
      candidates: catalog,
      preferredBrandId: preferredBrandId,
    );

    if (scored.isEmpty) {
      debugPrint('[HybridSubstitute] No suitable substitute found for ${outOfStock.name}');
      return null;
    }

    final best = scored.first;
    return SubstituteResult(
      substitute: best,
      source: SubstituteSource.ruleBased,
      requiresCustomerApproval: true,
      confidenceScore: _computeScore(outOfStock, best, preferredBrandId),
    );
  }

  // ─────────────── APPROVAL FLOW ───────────────

  /// Proposes a substitution to the customer via WhatsApp + stores in Firestore.
  /// Customer has [approvalWindowMinutes] to approve/decline before auto-action.
  Future<void> proposeSubstitution({
    required String orderId,
    required OrderItem item,
    required ProductModel substitute,
    required String customerPhone,
    required String customerName,
    required String orderNumber,
    int approvalWindowMinutes = 10,
  }) async {
    final docRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final order = OrderModel.fromMap(snapshot.data()!);
    final updatedItems = order.items.map((it) {
      if (it.id == item.id) {
        return it.copyWith(
          substitutionStatus: 'pending',
          proposedReplacementId: substitute.id,
          proposedReplacementName: substitute.name,
          proposedReplacementPrice: substitute.price,
          substitutionTimestamp: DateTime.now(),
        );
      }
      return it;
    }).toList();

    await docRef.update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      'substitutionDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(minutes: approvalWindowMinutes)),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify customer
    if (customerPhone.isNotEmpty) {
      await WhatsAppNotificationService.sendSubstitutionNotification(
        phoneNumber: customerPhone,
        customerName: customerName,
        orderNumber: orderNumber,
        originalName: item.productName,
        replacementName: substitute.name,
        replacementPrice: substitute.price.toDouble(),
      );
    }
    debugPrint(
      '[HybridSubstitute] Substitution proposed: ${item.productName} → ${substitute.name}',
    );
  }

  /// Handles customer approve/decline, or auto-approves after deadline.
  Future<void> resolveSubstitution({
    required String orderId,
    required String itemId,
    required bool approved,
    bool isAutoResolution = false,
  }) async {
    final docRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final order = OrderModel.fromMap(snapshot.data()!);
    bool changed = false;

    final updatedItems = order.items.map((it) {
      if (it.id == itemId && (it.substitutionStatus == 'pending' || isAutoResolution)) {
        changed = true;
        if (approved) {
          return it.copyWith(
            productId: it.proposedReplacementId,
            productName: it.proposedReplacementName,
            price: it.proposedReplacementPrice,
            totalPrice: (it.proposedReplacementPrice ?? MonetaryValue(0.0)) * it.quantity,
            substitutionStatus: isAutoResolution ? 'auto_approved' : 'approved',
            isPacked: true,
          );
        } else {
          return it.copyWith(
            substitutionStatus: 'declined',
            isOutOfStock: true,
            isPacked: false,
            totalPrice: MonetaryValue(0.0),
          );
        }
      }
      return it;
    }).toList();

    if (!changed) return;

    final newSubtotal = updatedItems.fold(0.0, (t, it) => t + it.totalPrice.toDouble());
    final newTotal = newSubtotal + order.deliveryCharge.toDouble() - order.discount.toDouble();

    await docRef.update({
      'items': updatedItems.map((e) => e.toMap()).toList(),
      'subtotal': newSubtotal,
      'totalAmount': newTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[HybridSubstitute] Resolved $itemId: ${approved ? "APPROVED" : "DECLINED"}');
  }

  /// Checks and auto-resolves all pending substitutions past their deadline.
  Future<void> processPendingSubstitutions(String orderId) async {
    final snapshot = await _firestore.collection('orders').doc(orderId).get();
    if (!snapshot.exists) return;

    final order = OrderModel.fromMap(snapshot.data()!);
    final now = DateTime.now();

    for (final item in order.items) {
      if (item.substitutionStatus == 'pending' && item.substitutionTimestamp != null) {
        final elapsed = now.difference(item.substitutionTimestamp!);
        if (elapsed.inMinutes >= 10) {
          // Check if customer opted in for auto-approve
          final autoApprove = await _getAutoApprovePreference(order.customerId);
          await resolveSubstitution(
            orderId: orderId,
            itemId: item.id,
            approved: autoApprove,
            isAutoResolution: true,
          );
        }
      }
    }
  }

  // ─────────────── RULE-BASED SCORING ───────────────

  List<ProductModel> _scoreSubstitutes({
    required ProductModel original,
    required List<ProductModel> candidates,
    String? preferredBrandId,
  }) {
    final available = candidates.where((p) => p.id != original.id && p.stockQuantity > 0).toList();

    available.sort((a, b) {
      return _computeScore(
        original,
        b,
        preferredBrandId,
      ).compareTo(_computeScore(original, a, preferredBrandId));
    });

    return available.take(5).toList();
  }

  double _computeScore(ProductModel original, ProductModel candidate, String? preferredBrandId) {
    double score = 0;

    // Category match — mandatory, but score higher for same sub-category
    if (candidate.categoryId == original.categoryId) score += 40;
    if (candidate.subCategory == original.subCategory) score += 20;

    // Tag overlap
    final tagOverlap = candidate.tags.where((t) => original.tags.contains(t)).length;
    score += tagOverlap * 5;

    // Price proximity (within 20% price range = max score)
    final double candidatePrice = candidate.price.toDouble();
    final double originalPrice = original.price.toDouble();
    final priceDelta = originalPrice > 0
        ? (candidatePrice - originalPrice).abs() / originalPrice
        : 0.0;
    if (priceDelta <= 0.05) {
      score += 20;
    } else if (priceDelta <= 0.10)
      score += 15;
    else if (priceDelta <= 0.20)
      score += 10;

    // Customer's preferred brand
    if (preferredBrandId != null && candidate.brand == preferredBrandId) score += 15;

    // Prefer same unit
    if (candidate.unit == original.unit) score += 5;

    return score;
  }

  // ─────────────── FIRESTORE HELPERS ───────────────

  Future<SubstituteResult?> _getManualOverride({
    required String shopId,
    required String productId,
  }) async {
    try {
      final doc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('substitute_overrides')
          .doc(productId)
          .get();

      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data['isActive'] != true) return null;

      final subId = data['substituteProductId'] as String? ?? '';
      if (subId.isEmpty) return null;

      final subDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(subId)
          .get();

      if (!subDoc.exists) return null;
      final substitute = ProductModel.fromMap(subDoc.data()!);
      if (substitute.stockQuantity <= 0) return null;

      return SubstituteResult(
        substitute: substitute,
        source: SubstituteSource.manualOverride,
        requiresCustomerApproval: data['requiresApproval'] as bool? ?? true,
        confidenceScore: 100,
      );
    } catch (e) {
      debugPrint('[HybridSubstitute] Override lookup error: $e');
      return null;
    }
  }

  Future<String?> _getCustomerBrandPreference(String userId, String productId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('substitution_prefs')
          .doc(productId)
          .get();
      return doc.data()?['preferredBrand'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _getAutoApprovePreference(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['autoApproveSubstitutions'] as bool? ?? false;
    } catch (_) {
      return false; // default: require explicit approval
    }
  }

  Future<List<ProductModel>> _fetchCatalog(String shopId, String category) async {
    try {
      final snap = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .where('category', isEqualTo: category)
          .where('isAvailable', isEqualTo: true)
          .get();
      return snap.docs.map((d) => ProductModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('[HybridSubstitute] Catalog fetch error: $e');
      return [];
    }
  }

  /// Saves a manual override rule for a product
  Future<void> setManualOverride({
    required String shopId,
    required String productId,
    required String substituteProductId,
    bool requiresApproval = true,
  }) async {
    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('substitute_overrides')
        .doc(productId)
        .set({
          'substituteProductId': substituteProductId,
          'isActive': true,
          'requiresApproval': requiresApproval,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    debugPrint('[HybridSubstitute] Manual override set for $productId → $substituteProductId');
  }

  Future<void> removeManualOverride(String shopId, String productId) async {
    await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('substitute_overrides')
        .doc(productId)
        .update({'isActive': false});
  }
}

// ─────────────── VALUE OBJECTS ───────────────

enum SubstituteSource { manualOverride, customerPreference, ruleBased }

class SubstituteResult {
  final ProductModel substitute;
  final SubstituteSource source;
  final bool requiresCustomerApproval;
  final double confidenceScore;

  const SubstituteResult({
    required this.substitute,
    required this.source,
    required this.requiresCustomerApproval,
    required this.confidenceScore,
  });
}
