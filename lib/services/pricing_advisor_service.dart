import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pricing_recommendation_model.dart';
import 'audit_logger.dart';

class PricingAdvisorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggerService _auditLogger = AuditLoggerService();

  /// Approve a pricing recommendation and apply the price change
  Future<void> approvePricing(String recommendationId, String ownerId) async {
    try {
      final docRef = _firestore.collection('pricing_recommendations').doc(recommendationId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) return;

      final rec = PricingRecommendationModel.fromMap(docSnap.data()!, recommendationId);

      // 1. Update the recommendation status
      await docRef.update({'status': PricingRecommendationStatus.approved.name});

      // 2. Fetch product to get current details
      final productRef = _firestore.collection('products').doc(rec.productId);
      final productSnap = await productRef.get();

      if (!productSnap.exists) {
        debugPrint('[PricingAdvisor] Product not found for ID: ${rec.productId}');
        return;
      }

      final productData = productSnap.data()!;
      final oldPrice = (productData['price'] ?? 0.0).toDouble();

      // 3. Update the product price
      await productRef.update({'price': rec.suggestedPrice});

      // 4. Log to Audit Trail with reversibility metadata
      await _auditLogger.logAdminAction(
        'Price Updated via AI Recommendation',
        targetUserId: ownerId,
        metadata: {
          'recommendationId': recommendationId,
          'productId': rec.productId,
          'oldPrice': oldPrice,
          'newPrice': rec.suggestedPrice,
          'reason': rec.reason,
          'reversible': true,
        },
      );

      debugPrint(
        '[PricingAdvisor] Price updated for ${rec.productId}: $oldPrice -> ${rec.suggestedPrice}',
      );
    } catch (e) {
      debugPrint('[PricingAdvisor] Error approving pricing: $e');
    }
  }

  /// Reject a pricing recommendation
  Future<void> rejectPricing(String recommendationId, String ownerId) async {
    try {
      final docRef = _firestore.collection('pricing_recommendations').doc(recommendationId);
      await docRef.update({'status': PricingRecommendationStatus.rejected.name});

      await _auditLogger.logAdminAction(
        'Pricing Recommendation Rejected',
        targetUserId: ownerId,
        metadata: {'recommendationId': recommendationId},
      );
    } catch (e) {
      debugPrint('[PricingAdvisor] Error rejecting pricing: $e');
    }
  }

  /// Rollback a price change (Undo)
  Future<void> rollbackPriceChange(String auditLogId, String ownerId) async {
    try {
      final logSnap = await _firestore.collection('audit_logs').doc(auditLogId).get();
      if (!logSnap.exists) return;

      final logData = logSnap.data()!;
      final metadata = logData['metadata'] as Map<String, dynamic>? ?? {};

      if (metadata['reversible'] == true &&
          metadata['productId'] != null &&
          metadata['oldPrice'] != null) {
        final productId = metadata['productId'] as String?;
        final oldPrice = metadata['oldPrice'];

        await _firestore.collection('products').doc(productId).update({'price': oldPrice});

        await _auditLogger.logAdminAction(
          'Price Change Rolled Back',
          targetUserId: ownerId,
          metadata: {
            'productId': productId,
            'restoredPrice': oldPrice,
            'originalAuditLogId': auditLogId,
          },
        );
      }
    } catch (e) {
      debugPrint('[PricingAdvisor] Error rolling back price: $e');
    }
  }
}
