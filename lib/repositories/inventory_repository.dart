import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';
import '../models/cart_item.dart';

class InventoryRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference get _inventoryRef => _firestore.collection('inventory');

  /// Fetches inventory for a product at a specific branch
  Future<InventoryModel?> getInventory(String productId, {String branchId = 'default'}) async {
    try {
      final docId = '${productId}_$branchId';
      final doc = await _inventoryRef.doc(docId).get();
      if (!doc.exists) return null;
      return InventoryModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[InventoryRepository] Error getting inventory: $e');
      return null;
    }
  }

  /// Transactionally reserves inventory (Available -> Reserved)
  Future<void> reserveInventory(List<CartItem> items, {String branchId = 'default'}) async {
    await _firestore.runTransaction((transaction) async {
      for (final item in items) {
        final docId = '${item.productId}_$branchId';
        final docRef = _inventoryRef.doc(docId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('Product ${item.productName} not found in inventory.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final available = (data['availableStock'] as num? ?? 0).toInt();
        final reserved = (data['reservedStock'] as num? ?? 0).toInt();
        final qty = item.quantity;

        if (available < qty) {
          throw Exception(
            'Insufficient available stock for ${item.productName}. (Available: $available, Requested: $qty)',
          );
        }

        transaction.update(docRef, {
          'availableStock': available - qty,
          'reservedStock': reserved + qty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write to ledger
        final movementRef = _firestore.collection('inventory_movements').doc();
        transaction.set(movementRef, {
          'productId': item.productId,
          'branchId': branchId,
          'type': 'RESERVATION',
          'quantity': qty,
          'note': 'Order Reserved',
          'status': 'ACTIVE',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Transactionally commits inventory (Reserved -> Committed)
  Future<void> commitInventory(List<CartItem> items, {String branchId = 'default'}) async {
    await _firestore.runTransaction((transaction) async {
      for (final item in items) {
        final docId = '${item.productId}_$branchId';
        final docRef = _inventoryRef.doc(docId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception('Product ${item.productName} not found in inventory.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final reserved = (data['reservedStock'] as num? ?? 0).toInt();
        final committed = (data['committedStock'] as num? ?? 0).toInt();
        final qty = item.quantity;

        // In edge cases where reserved < qty due to manual intervention, we cap it at 0
        final newReserved = (reserved - qty) >= 0 ? reserved - qty : 0;

        transaction.update(docRef, {
          'reservedStock': newReserved,
          'committedStock': committed + qty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write to ledger
        final movementRef = _firestore.collection('inventory_movements').doc();
        transaction.set(movementRef, {
          'productId': item.productId,
          'branchId': branchId,
          'type': 'COMMITMENT',
          'quantity': qty,
          'note': 'Order Committed',
          'status': 'COMMITTED',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Transactionally restores inventory.
  /// Source defaults to 'reserved' but can be 'committed' if order was packed and then cancelled.
  Future<void> restoreInventory(
    List<CartItem> items, {
    String branchId = 'default',
    String fromState = 'reserved',
  }) async {
    await _firestore.runTransaction((transaction) async {
      for (final item in items) {
        final docId = '${item.productId}_$branchId';
        final docRef = _inventoryRef.doc(docId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) continue; // Might have been deleted, safely ignore for restoration

        final data = snapshot.data() as Map<String, dynamic>;
        final available = (data['availableStock'] as num? ?? 0).toInt();
        final sourceQty = (data['${fromState}Stock'] as num? ?? 0).toInt();
        final qty = item.quantity;

        final newSourceQty = (sourceQty - qty) >= 0 ? sourceQty - qty : 0;

        transaction.update(docRef, {
          'availableStock': available + qty,
          '${fromState}Stock': newSourceQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write to ledger
        final movementRef = _firestore.collection('inventory_movements').doc();
        transaction.set(movementRef, {
          'productId': item.productId,
          'branchId': branchId,
          'type': 'RELEASE',
          'quantity': qty,
          'note': 'Reservation Released from $fromState',
          'status': 'CANCELLED',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Transactionally moves inventory to QC (from Committed to QCStock)
  Future<void> qcInventory(
    List<CartItem> items, {
    String branchId = 'default',
    String fromState = 'committed',
  }) async {
    await _firestore.runTransaction((transaction) async {
      for (final item in items) {
        final docId = '${item.productId}_$branchId';
        final docRef = _inventoryRef.doc(docId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) continue;

        final data = snapshot.data() as Map<String, dynamic>;
        final qcStock = (data['qcStock'] as num? ?? 0).toInt();
        final sourceQty = (data['${fromState}Stock'] as num? ?? 0).toInt();
        final qty = item.quantity;

        final newSourceQty = (sourceQty - qty) >= 0 ? sourceQty - qty : 0;

        transaction.update(docRef, {
          'qcStock': qcStock + qty,
          '${fromState}Stock': newSourceQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Write to ledger
        final movementRef = _firestore.collection('inventory_movements').doc();
        transaction.set(movementRef, {
          'productId': item.productId,
          'branchId': branchId,
          'type': 'QC_MOVE',
          'quantity': qty,
          'note': 'Moved to QC from $fromState',
          'status': 'ACTIVE',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Transactionally mark QC inventory as damaged
  Future<void> markDamaged(
    String productId,
    int qty, {
    String branchId = 'default',
    String fromState = 'qc',
  }) async {
    await _firestore.runTransaction((transaction) async {
      final docId = '${productId}_$branchId';
      final docRef = _inventoryRef.doc(docId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) throw Exception('Inventory document not found.');

      final data = snapshot.data() as Map<String, dynamic>;
      final damaged = (data['damagedStock'] as num? ?? 0).toInt();
      final sourceQty = (data['${fromState}Stock'] as num? ?? 0).toInt();

      if (sourceQty < qty) throw Exception('Not enough $fromState stock to mark as damaged.');

      transaction.update(docRef, {
        'damagedStock': damaged + qty,
        '${fromState}Stock': sourceQty - qty,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write to ledger
      final movementRef = _firestore.collection('inventory_movements').doc();
      transaction.set(movementRef, {
        'productId': productId,
        'branchId': branchId,
        'type': 'DAMAGE',
        'quantity': qty,
        'note': 'Marked Damaged from $fromState',
        'status': 'ACTIVE',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
