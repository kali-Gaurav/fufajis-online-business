import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/purchase_request_model.dart';
import '../models/supplier_quote_model.dart';
import '../models/purchase_order_model.dart';
import '../models/goods_receipt_model.dart';
import '../models/supplier_scorecard_model.dart';
import '../models/supplier_invoice_model.dart';
import 'audit_logger.dart';

class SupplierPortalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggerService _auditLogger = AuditLoggerService();

  /// Supplier submits a quote for an open purchase request
  Future<void> submitQuote(SupplierQuoteModel quote) async {
    try {
      final docRef = _firestore.collection('supplier_quotes').doc(quote.id);
      await docRef.set(quote.toMap());
      debugPrint('[SupplierPortal] Quote submitted: ${quote.id}');
    } catch (e) {
      debugPrint('[SupplierPortal] Error submitting quote: $e');
      rethrow;
    }
  }

  /// Owner accepts a quote, creates a PO, and marks other quotes for this PR as rejected
  Future<void> acceptQuoteAndCreatePO(String quoteId, String ownerId) async {
    try {
      final quoteSnap = await _firestore.collection('supplier_quotes').doc(quoteId).get();
      if (!quoteSnap.exists) return;
      
      final quote = SupplierQuoteModel.fromMap(quoteSnap.data()!, quoteSnap.id);
      
      final prSnap = await _firestore.collection('purchase_requests').doc(quote.purchaseRequestId).get();
      if (!prSnap.exists) return;

      final pr = PurchaseRequestModel.fromMap(prSnap.data()!, prSnap.id);

      final batch = _firestore.batch();

      // 1. Mark quote as accepted
      batch.update(quoteSnap.reference, {'status': SupplierQuoteStatus.accepted.name});

      // 2. Reject all other quotes for this PR
      final otherQuotesSnap = await _firestore.collection('supplier_quotes')
          .where('purchaseRequestId', isEqualTo: pr.id)
          .where('status', isEqualTo: SupplierQuoteStatus.pending.name)
          .get();
      
      for (var doc in otherQuotesSnap.docs) {
        if (doc.id != quoteId) {
          batch.update(doc.reference, {'status': SupplierQuoteStatus.rejected.name});
        }
      }

      // 3. Update PR status
      batch.update(prSnap.reference, {
        'status': PurchaseRequestStatus.ordered.name,
        'supplierId': quote.supplierId,
      });

      // 4. Create Purchase Order
      final poRef = _firestore.collection('purchase_orders').doc();
      final po = PurchaseOrderModel(
        id: poRef.id,
        purchaseRequestId: pr.id,
        quoteId: quote.id,
        supplierId: quote.supplierId,
        branchId: pr.branchId,
        productId: pr.productId,
        quantity: quote.requestedQuantity,
        agreedPricePerUnit: quote.quotedPricePerUnit,
        totalAmount: quote.requestedQuantity * quote.quotedPricePerUnit,
        status: PurchaseOrderStatus.po_generated,
        expectedDeliveryDate: quote.estimatedDeliveryDate,
        createdAt: DateTime.now(),
      );
      batch.set(poRef, po.toMap());

      await batch.commit();

      await _auditLogger.logAdminAction(
        'Purchase Order Created',
        targetUserId: ownerId,
        metadata: {
          'purchaseOrderId': po.id,
          'purchaseRequestId': pr.id,
          'supplierId': po.supplierId,
          'totalAmount': po.totalAmount,
        },
      );

      debugPrint('[SupplierPortal] PO Created: ${po.id}');
    } catch (e) {
      debugPrint('[SupplierPortal] Error accepting quote: $e');
      rethrow;
    }
  }

  /// Owner/Warehouse logs received goods, updates inventory
  Future<void> receiveGoods(GoodsReceiptModel receipt, String ownerId) async {
    try {
      final poSnap = await _firestore.collection('purchase_orders').doc(receipt.purchaseOrderId).get();
      if (!poSnap.exists) return;
      
      final po = PurchaseOrderModel.fromMap(poSnap.data()!, poSnap.id);

      final batch = _firestore.batch();

      // 1. Save Receipt
      final receiptRef = _firestore.collection('goods_receipts').doc(receipt.id);
      batch.set(receiptRef, receipt.toMap());

      // 2. Update PO status
      final newPoStatus = (receipt.acceptedQuantity >= po.quantity) 
          ? PurchaseOrderStatus.fully_received.name 
          : PurchaseOrderStatus.partially_received.name;
      
      batch.update(poSnap.reference, {'status': newPoStatus});

      // 3. Update Product Inventory
      final productRef = _firestore.collection('products').doc(po.productId);
      batch.update(productRef, {
        'stockQuantity': FieldValue.increment(receipt.acceptedQuantity),
      });

      // 4. Update PR status if PO completed
      if (newPoStatus == PurchaseOrderStatus.fully_received.name) {
        final prRef = _firestore.collection('purchase_requests').doc(po.purchaseRequestId);
        batch.update(prRef, {'status': PurchaseRequestStatus.received.name});
      }

      await batch.commit();

      await _auditLogger.logAdminAction(
        'Goods Received & Inventory Updated',
        targetUserId: ownerId,
        metadata: {
          'purchaseOrderId': po.id,
          'productId': po.productId,
          'acceptedQuantity': receipt.acceptedQuantity,
          'damagedQuantity': receipt.damagedQuantity,
        },
      );

      // --- Supplier Scorecard Generation ---
      final scorecardRef = _firestore.collection('supplier_scorecards').doc(po.supplierId);
      final scorecardSnap = await scorecardRef.get();
      
      SupplierScorecardModel scorecard;
      if (scorecardSnap.exists) {
        final existing = SupplierScorecardModel.fromMap(scorecardSnap.data()!, scorecardSnap.id);
        
        // Simple moving average mock logic for update
        final newTotal = existing.totalOrders + 1;
        final damageRate = (receipt.damagedQuantity / receipt.receivedQuantity) * 100;
        final fulfillment = (receipt.acceptedQuantity / po.quantity) * 100;
        
        scorecard = SupplierScorecardModel(
          supplierId: existing.supplierId,
          onTimeDeliveryPercentage: existing.onTimeDeliveryPercentage, // Assume 100% for now
          damageRatePercentage: ((existing.damageRatePercentage * existing.totalOrders) + damageRate) / newTotal,
          orderFulfillmentPercentage: ((existing.orderFulfillmentPercentage * existing.totalOrders) + fulfillment) / newTotal,
          priceCompetitiveness: existing.priceCompetitiveness,
          overallQualityRating: existing.overallQualityRating,
          totalOrders: newTotal,
          lastUpdated: DateTime.now(),
        );
      } else {
        final damageRate = (receipt.damagedQuantity / receipt.receivedQuantity) * 100;
        final fulfillment = (receipt.acceptedQuantity / po.quantity) * 100;
        scorecard = SupplierScorecardModel(
          supplierId: po.supplierId,
          damageRatePercentage: damageRate,
          orderFulfillmentPercentage: fulfillment,
          totalOrders: 1,
          lastUpdated: DateTime.now(),
        );
      }
      
      await scorecardRef.set(scorecard.toMap(), SetOptions(merge: true));

      debugPrint('[SupplierPortal] Goods received for PO: ${po.id}');
    } catch (e) {
      debugPrint('[SupplierPortal] Error receiving goods: $e');
      rethrow;
    }
  }

  /// 3-Way Match Verification (PO amount == Received Amount == Invoice Amount)
  Future<bool> verifyThreeWayMatch(String invoiceId) async {
    try {
      final invoiceSnap = await _firestore.collection('supplier_invoices').doc(invoiceId).get();
      if (!invoiceSnap.exists) return false;
      final invoice = SupplierInvoiceModel.fromMap(invoiceSnap.data()!, invoiceSnap.id);

      final poSnap = await _firestore.collection('purchase_orders').doc(invoice.purchaseOrderId).get();
      if (!poSnap.exists) return false;
      final po = PurchaseOrderModel.fromMap(poSnap.data()!, poSnap.id);

      // Aggregate all goods receipts for this PO
      final receiptsSnap = await _firestore.collection('goods_receipts')
          .where('purchaseOrderId', isEqualTo: po.id)
          .get();
      
      int totalAccepted = 0;
      for (var doc in receiptsSnap.docs) {
        totalAccepted += (doc.data()['acceptedQuantity'] as int? ?? 0);
      }

      final expectedValue = totalAccepted * po.agreedPricePerUnit;
      
      // Allow a small threshold difference e.g., rounding
      final isMatched = (invoice.billedAmount - expectedValue).abs() < 1.0;

      if (isMatched) {
        await invoiceSnap.reference.update({
          'status': InvoiceStatus.matched.name,
          'isThreeWayMatched': true,
        });

        await _auditLogger.logAdminAction(
          '3-Way Match Successful',
          targetUserId: 'system',
          metadata: {
            'invoiceId': invoice.id,
            'purchaseOrderId': po.id,
            'matchedAmount': invoice.billedAmount,
          },
        );
      } else {
        await invoiceSnap.reference.update({
          'status': InvoiceStatus.disputed.name,
          'isThreeWayMatched': false,
        });
      }

      return isMatched;
    } catch (e) {
      debugPrint('[SupplierPortal] Error verifying 3-way match: $e');
      return false;
    }
  }
}
