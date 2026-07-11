import 'package:fufaji/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Purchase Order service
/// Handles PO lifecycle: creation, status tracking, receipt management
class PurchaseOrderService {
  static final PurchaseOrderService _instance = PurchaseOrderService._internal();

  factory PurchaseOrderService() {
    return _instance;
  }

  PurchaseOrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Create new purchase order
  Future<String> createPurchaseOrder({
    required String supplierId,
    required String supplierName,
    required List<Map<String, dynamic>> items,
    required String createdBy,
    DateTime? expectedDeliveryDate,
    String? notes,
  }) async {
    try {
      developer.log('Creating purchase order for supplier: $supplierId');

      if (items.isEmpty) {
        throw Exception('Purchase order must contain at least one item');
      }

      // Calculate totals
      double subtotal = 0;
      for (final item in items) {
        subtotal += (item['quantity'] as int) * (item['unit_cost'] as double);
      }

      const taxRate = 0.18; // 18% GST
      final taxAmount = subtotal * taxRate;
      final totalAmount = subtotal + taxAmount;

      // Generate PO number (could be enhanced with auto-increment)
      final poNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';

      final poRef = await _firestore.collection('$_collectionPrefix/purchase_orders').add({
        'po_number': poNumber,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'status': 'draft',
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'total_amount': totalAmount,
        'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
        'actual_delivery_date': null,
        'notes': notes,
        'created_by': createdBy,
        'approved_by': null,
        'received_by': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'approved_at': null,
        'received_at': null,
      });

      // Add items
      final batch = _firestore.batch();
      for (final item in items) {
        final itemRef = _firestore
            .collection('$_collectionPrefix/purchase_orders')
            .doc(poRef.id)
            .collection('items')
            .doc();

        batch.set(itemRef, {
          'po_id': poRef.id,
          'product_id': item['product_id'] as String,
          'product_name': item['product_name'] as String,
          'quantity': item['quantity'] as int,
          'unit_cost': item['unit_cost'] as double,
          'total_cost': (item['quantity'] as int) * (item['unit_cost'] as double),
          'quantity_received': 0,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      developer.log('Successfully created purchase order: $poNumber');
      _clearPOCache();

      return poRef.id;
    } catch (e) {
      developer.log('Error creating purchase order: $e', error: e);
      rethrow;
    }
  }

  // Get all purchase orders
  Future<List<PurchaseOrder>> getAllPurchaseOrders({String? status}) async {
    try {
      developer.log('Fetching purchase orders${status != null ? ' (status: $status)' : ''}');

      var query = _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .orderBy('created_at', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status) as Query<Map<String, dynamic>>;
      }

      final snapshot = await query.get();

      final orders = <PurchaseOrder>[];
      for (final doc in snapshot.docs) {
        final po = await _buildPurchaseOrder(doc);
        orders.add(po);
      }

      return orders;
    } catch (e) {
      developer.log('Error fetching purchase orders: $e', error: e);
      rethrow;
    }
  }

  // Get single purchase order
  Future<PurchaseOrder?> getPurchaseOrder(String poId) async {
    try {
      developer.log('Fetching purchase order: $poId');

      final doc = await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .doc(poId)
          .get();

      if (!doc.exists) return null;

      return await _buildPurchaseOrder(doc);
    } catch (e) {
      developer.log('Error fetching purchase order: $e', error: e);
      rethrow;
    }
  }

  // Update PO status
  Future<void> updatePOStatus(String poId, String newStatus) async {
    try {
      developer.log('Updating PO status: $poId -> $newStatus');

      final validStatuses = ['draft', 'sent', 'confirmed', 'received', 'cancelled'];
      if (!validStatuses.contains(newStatus)) {
        throw Exception('Invalid PO status: $newStatus');
      }

      await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .doc(poId)
          .update({
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully updated PO status');
      _clearPOCache();
    } catch (e) {
      developer.log('Error updating PO status: $e', error: e);
      rethrow;
    }
  }

  // Approve purchase order
  Future<void> approvePurchaseOrder(String poId, String approvedBy) async {
    try {
      developer.log('Approving purchase order: $poId');

      await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .doc(poId)
          .update({
            'status': 'sent',
            'approved_by': approvedBy,
            'approved_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully approved purchase order');
      _clearPOCache();
    } catch (e) {
      developer.log('Error approving purchase order: $e', error: e);
      rethrow;
    }
  }

  // Receive purchase order items
  Future<void> receivePurchaseOrder(
    String poId,
    String receivedBy,
    List<Map<String, dynamic>> receivedItems,
  ) async {
    try {
      developer.log('Receiving purchase order: $poId');

      final batch = _firestore.batch();

      // Update PO status
      final poRef = _firestore.collection('$_collectionPrefix/purchase_orders').doc(poId);
      batch.update(poRef, {
        'status': 'received',
        'received_by': receivedBy,
        'received_at': FieldValue.serverTimestamp(),
        'actual_delivery_date': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update item quantities received
      for (final item in receivedItems) {
        final itemRef = poRef.collection('items').doc(item['item_id'] as String);
        batch.update(itemRef, {
          'quantity_received': item['quantity_received'] as int,
        });
      }

      await batch.commit();

      developer.log('Successfully received purchase order');
      _clearPOCache();
    } catch (e) {
      developer.log('Error receiving purchase order: $e', error: e);
      rethrow;
    }
  }

  // Get POs by supplier
  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(String supplierId) async {
    try {
      developer.log('Fetching purchase orders for supplier: $supplierId');

      final snapshot = await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .where('supplier_id', isEqualTo: supplierId)
          .orderBy('created_at', descending: true)
          .get();

      final orders = <PurchaseOrder>[];
      for (final doc in snapshot.docs) {
        final po = await _buildPurchaseOrder(doc);
        orders.add(po);
      }

      return orders;
    } catch (e) {
      developer.log('Error fetching supplier purchase orders: $e', error: e);
      rethrow;
    }
  }

  // Get PO statistics
  Future<Map<String, dynamic>> getPOStatistics() async {
    try {
      developer.log('Fetching PO statistics');

      final allPOs = await getAllPurchaseOrders();

      final stats = {
        'total_pos': allPOs.length,
        'draft': allPOs.where((p) => p.status == 'draft').length,
        'sent': allPOs.where((p) => p.status == 'sent').length,
        'confirmed': allPOs.where((p) => p.status == 'confirmed').length,
        'received': allPOs.where((p) => p.status == 'received').length,
        'cancelled': allPOs.where((p) => p.status == 'cancelled').length,
        'total_value': allPOs.fold<double>(0, (sum, po) => sum + po.grandTotal),
        'average_value': 0.0,
        'pending_receipt': 0,
      };

      final pending = allPOs.where((p) => p.status == 'sent' || p.status == 'confirmed').length;
      stats['pending_receipt'] = pending;

      if (allPOs.isNotEmpty) {
        stats['average_value'] = (stats['total_value'] as double) / allPOs.length;
      }

      return stats;
    } catch (e) {
      developer.log('Error fetching PO statistics: $e', error: e);
      rethrow;
    }
  }

  // Cancel purchase order
  Future<void> cancelPurchaseOrder(String poId, String reason) async {
    try {
      developer.log('Cancelling purchase order: $poId');

      await _firestore
          .collection('$_collectionPrefix/purchase_orders')
          .doc(poId)
          .update({
            'status': 'cancelled',
            'cancel_reason': reason,
            'cancelled_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully cancelled purchase order');
      _clearPOCache();
    } catch (e) {
      developer.log('Error cancelling purchase order: $e', error: e);
      rethrow;
    }
  }

  // Build PurchaseOrder object from Firestore doc
  Future<PurchaseOrder> _buildPurchaseOrder(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Get items
    final itemsSnapshot = await doc.reference.collection('items').get();
    final items = itemsSnapshot.docs
        .map((itemDoc) => PurchaseOrderItem.fromJson({...itemDoc.data(), 'id': itemDoc.id}))
        .toList();

    return PurchaseOrder(
      id: doc.id,
      poNumber: data['po_number'] as String,
      supplierId: data['supplier_id'] as String,
      supplierName: data['supplier_name'] as String,
      status: data['status'] as String? ?? 'draft',
      totalAmount: (data['total_amount'] as num? ?? 0).toDouble(),
      taxAmount: data['tax_amount'] != null ? (data['tax_amount'] as num).toDouble() : null,
      discountAmount: data['discount_amount'] != null ? (data['discount_amount'] as num).toDouble() : null,
      expectedDeliveryDate: data['expected_delivery_date'] != null
          ? DateTime.parse(data['expected_delivery_date'] as String)
          : null,
      actualDeliveryDate: data['actual_delivery_date'] != null
          ? DateTime.parse(data['actual_delivery_date'] as String)
          : null,
      notes: data['notes'] as String?,
      createdBy: data['created_by'] as String,
      approvedBy: data['approved_by'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String),
      approvedAt: data['approved_at'] != null ? DateTime.parse(data['approved_at'] as String) : null,
      items: items,
    );
  }

  void _clearPOCache() {
    developer.log('Clearing PO cache');
    AnalyticsPerformance.clearCacheKey('purchase_orders');
  }
}
