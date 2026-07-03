import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_change_request_model.dart';
import 'audit_service.dart';

/// Manages the owner-approval workflow for bulk/single inventory edits
/// proposed via the Excel-like Bulk Inventory Query Builder.
///
/// Nothing proposed through [createChangeRequest] touches `products` until
/// an owner calls [approveRequest] — at which point changes are applied to
/// Firestore (source of truth for the app UI) and, where a known column
/// mapping exists, dual-written to the Supabase `products` table, with a
/// full audit trail via [AuditService].
class InventoryChangeRequestService {
  static final InventoryChangeRequestService _instance = InventoryChangeRequestService._internal();
  factory InventoryChangeRequestService() => _instance;
  InventoryChangeRequestService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'inventory_change_requests';

  /// Creates a new pending change request. Returns the new document id.
  Future<String> createChangeRequest(InventoryChangeRequestModel request) async {
    final docRef = await _db.collection(_collection).add(request.toMap());

    await AuditService().logAction(
      userId: request.requestedBy,
      userName: request.requestedByName,
      action: AuditAction.inventoryUpdate,
      description:
          'Requested bulk inventory change (${request.type.name}) affecting '
          '${request.affectedProductCount} product(s): ${request.filterDescription}',
      targetId: docRef.id,
      metadata: {
        'status': 'pending',
        'changeCount': request.changes.length,
        'filter': request.filterDescription,
      },
    );

    return docRef.id;
  }

  /// Streams all pending requests, newest first — feeds the owner Approval
  /// Queue screen.
  Stream<List<InventoryChangeRequestModel>> watchPendingRequests() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: InventoryChangeRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => InventoryChangeRequestModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// Streams ALL requests (any status), newest first — used for a
  /// history/audit view.
  Stream<List<InventoryChangeRequestModel>> watchAllRequests({int limit = 100}) {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => InventoryChangeRequestModel.fromMap(d.data(), d.id)).toList(),
        );
  }

  /// Approves [requestId]: applies every field change to `products` in
  /// Firestore (batched), dual-writes recognized fields to Supabase, marks
  /// the request `approved`, and writes audit log entries.
  Future<void> approveRequest({
    required String requestId,
    required String ownerId,
    required String ownerName,
    String? reviewNote,
  }) async {
    final doc = await _db.collection(_collection).doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Change request not found');
    }
    final request = InventoryChangeRequestModel.fromMap(doc.data()!, doc.id);
    if (request.status != InventoryChangeRequestStatus.pending) {
      throw Exception('Change request is no longer pending');
    }

    // Group field changes by productId so each product gets one Firestore
    // update with all of its changed fields at once.
    final Map<String, Map<String, dynamic>> updatesByProduct = {};
    for (final change in request.changes) {
      updatesByProduct.putIfAbsent(change.productId, () => {});
      updatesByProduct[change.productId]![change.field] = change.newValue;
    }

    // 1. Firestore writes (batched, 450/batch ceiling like elsewhere in app).
    final entries = updatesByProduct.entries.toList();
    for (var i = 0; i < entries.length; i += 450) {
      final batch = _db.batch();
      for (final entry in entries.skip(i).take(450)) {
        final ref = _db.collection('products').doc(entry.key);
        batch.update(ref, {
          ...entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
          if (entry.value.containsKey('stockQuantity'))
            'isAvailable': (entry.value['stockQuantity'] as num? ?? 0) > 0,
        });
      }
      await batch.commit();
    }

    // 2. Mark request approved.
    await _db.collection(_collection).doc(requestId).update({
      'status': InventoryChangeRequestStatus.approved.name,
      'reviewedBy': ownerId,
      'reviewedByName': ownerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': reviewNote,
    });

    // 4. Audit trail — one summary entry plus per-product detail.
    await AuditService().logAction(
      userId: ownerId,
      userName: ownerName,
      action: AuditAction.inventoryUpdate,
      description:
          'Approved bulk inventory change affecting ${updatesByProduct.length} product(s): '
          '${request.filterDescription}',
      targetId: requestId,
      metadata: {
        'status': 'approved',
        'requestedBy': request.requestedByName,
        'productCount': updatesByProduct.length,
      },
    );
  }

  /// Rejects [requestId] without applying any changes.
  Future<void> rejectRequest({
    required String requestId,
    required String ownerId,
    required String ownerName,
    String? reviewNote,
  }) async {
    final doc = await _db.collection(_collection).doc(requestId).get();
    if (!doc.exists) {
      throw Exception('Change request not found');
    }
    final request = InventoryChangeRequestModel.fromMap(doc.data()!, doc.id);

    await _db.collection(_collection).doc(requestId).update({
      'status': InventoryChangeRequestStatus.rejected.name,
      'reviewedBy': ownerId,
      'reviewedByName': ownerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': reviewNote,
    });

    await AuditService().logAction(
      userId: ownerId,
      userName: ownerName,
      action: AuditAction.adminAction,
      description:
          'Rejected bulk inventory change requested by ${request.requestedByName}: '
          '${request.filterDescription}'
          '${reviewNote != null && reviewNote.isNotEmpty ? ' — Reason: $reviewNote' : ''}',
      targetId: requestId,
      metadata: {'status': 'rejected'},
    );
  }

  /// Convenience method used by BulkInventoryQueryScreen.
  /// Builds an [InventoryChangeRequestModel] from simple params and submits it.
  Future<String> createBulkRequest({
    required String requestedBy,
    required String requestedByName,
    required InventoryChangeType changeType,
    required List<String> productIds,
    required double value,
    required String reason,
    String? queryDescription,
  }) async {
    final field = changeType == InventoryChangeType.stockAdjustment ? 'stockQuantity' : 'price';

    final changes = productIds
        .map(
          (pid) => InventoryFieldChange(
            productId: pid,
            productName: pid, // name resolved on server/approval
            field: field,
            oldValue: null,
            newValue: value,
          ),
        )
        .toList();

    final request = InventoryChangeRequestModel(
      id: '',
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      type: changeType,
      filterDescription: queryDescription ?? 'Bulk change affecting \${productIds.length} products',
      note: reason, // model uses 'note' for requester comments
      status: InventoryChangeRequestStatus.pending,
      changes: changes,
      createdAt: DateTime.now(),
    );

    return createChangeRequest(request);
  }
}
