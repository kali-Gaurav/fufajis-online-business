import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_request_model.dart';
import '../models/inventory_recommendation_model.dart';
import 'audit_logger.dart';

class AutoReorderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggerService _auditLogger = AuditLoggerService();

  /// Generate an inventory recommendation for a given product and demand prediction
  Future<void> generateInventoryRecommendation({
    required String productId,
    required String branchId,
    required int currentStock,
    required int predictedDemand,
  }) async {
    try {
      // 1. Calculate recommended quantity
      // Assuming a simple logic: recommendedStock = predictedDemand + 20% safety stock
      final int recommendedStock = (predictedDemand * 1.2).ceil();
      final int suggestedPurchaseQty = recommendedStock - currentStock;

      if (suggestedPurchaseQty <= 0) {
        debugPrint('[AutoReorder] No purchase needed for $productId. Current: $currentStock, Recommended: $recommendedStock');
        return;
      }

      // 2. Create the inventory recommendation
      final docRef = _firestore.collection('inventory_recommendations').doc();
      final recommendation = InventoryRecommendationModel(
        id: docRef.id,
        productId: productId,
        branchId: branchId,
        currentStock: currentStock,
        predictedDemand: predictedDemand,
        recommendedOrderQty: suggestedPurchaseQty,
        confidenceScore: 0.85, // Mock confidence
        reason: 'Predicted demand ($predictedDemand) exceeds current stock ($currentStock) + safety buffer.',
        status: InventoryRecommendationStatus.pending,
        createdAt: DateTime.now(),
      );

      await docRef.set(recommendation.toMap());

      await _auditLogger.logAdminAction(
        'Inventory Recommendation Generated',
        metadata: {
          'targetUserId': 'system',
          'productId': productId,
          'qty': suggestedPurchaseQty,
          'branchId': branchId,
        },
      );

      debugPrint('[AutoReorder] Inventory Recommendation generated for $productId');
    } catch (e) {
      debugPrint('[AutoReorder] Error generating purchase request: $e');
    }
  }

  /// Approve an inventory recommendation (Owner Action)
  Future<void> approveRecommendation(String recommendationId, String ownerId) async {
    try {
      final docRef = _firestore.collection('inventory_recommendations').doc(recommendationId);
      final docSnap = await docRef.get();
      
      if (!docSnap.exists) return;
      
      final rec = InventoryRecommendationModel.fromMap(docSnap.data()!, recommendationId);
      
      // Update recommendation status
      await docRef.update({
        'status': InventoryRecommendationStatus.approved.name,
      });

      // Now create the Purchase Request
      final String mockSupplierId = 'supplier_${DateTime.now().millisecondsSinceEpoch % 100}';
      final double expectedCost = rec.recommendedOrderQty * 50.0; // Mock unit cost

      final prRef = _firestore.collection('purchase_requests').doc();
      final pr = PurchaseRequestModel(
        id: prRef.id,
        productId: rec.productId,
        branchId: rec.branchId,
        supplierId: mockSupplierId,
        currentStock: rec.currentStock,
        recommendedStock: rec.currentStock + rec.recommendedOrderQty,
        suggestedPurchaseQty: rec.recommendedOrderQty,
        expectedCost: expectedCost,
        status: PurchaseRequestStatus.ordered, // Directly to ordered as approved
        createdAt: DateTime.now(),
      );
      
      await prRef.set(pr.toMap());

      await _auditLogger.logFinancialEvent(
        'Inventory Recommendation Approved -> Purchase Ordered',
        metadata: {
          'amount': expectedCost,
          'recommendationId': recommendationId,
          'purchaseRequestId': prRef.id,
          'approvedBy': ownerId
        },
      );
    } catch (e) {
      debugPrint('[AutoReorder] Error approving recommendation: $e');
    }
  }

  /// Reject an inventory recommendation (Owner Action)
  Future<void> rejectRecommendation(String recommendationId, String ownerId) async {
    try {
      final docRef = _firestore.collection('inventory_recommendations').doc(recommendationId);
      await docRef.update({
        'status': InventoryRecommendationStatus.rejected.name,
      });

      await _auditLogger.logAdminAction(
        'Inventory Recommendation Rejected',
        metadata: {
          'targetUserId': ownerId,
          'recommendationId': recommendationId
        },
      );
    } catch (e) {
      debugPrint('[AutoReorder] Error rejecting recommendation: $e');
    }
  }
}
