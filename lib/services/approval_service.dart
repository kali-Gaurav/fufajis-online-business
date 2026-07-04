import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/approval_request_model.dart';

class ApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'approval_requests';

  // Anyone can create an approval request (e.g. employee signing up)
  Future<String> submitRequest(ApprovalRequestModel request) async {
    final docRef = _firestore.collection(_collection).doc();
    
    final newRequest = ApprovalRequestModel(
      id: docRef.id,
      targetType: request.targetType,
      targetId: request.targetId,
      requesterId: request.requesterId,
      branchId: request.branchId,
      title: request.title,
      description: request.description,
      metadata: request.metadata,
      status: ApprovalStatus.pending,
      createdAt: DateTime.now(),
    );

    await docRef.set(newRequest.toMap());
    return docRef.id;
  }

  // Owner/Admin only
  Future<void> updateRequestStatus(String requestId, ApprovalStatus newStatus, String approverId, {String? notes}) async {
    await _firestore.collection(_collection).doc(requestId).update({
      'status': newStatus.name,
      'approverId': approverId,
      'resolvedAt': FieldValue.serverTimestamp(),
      if (notes != null) 'resolutionNotes': notes,
    });
  }

  // Owner/Admin only
  Stream<List<ApprovalRequestModel>> streamPendingRequests() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: ApprovalStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ApprovalRequestModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
