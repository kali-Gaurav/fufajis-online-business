import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

enum AuditAction {
  roleChange,
  priceUpdate,
  stockAdjustment,
  orderCancellation,
  adminAction,
  securityAlert,
}

class AuditService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  Future<void> logAction({
    required String userId,
    required String userName,
    required AuditAction action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final logData = {
        'userId': userId,
        'userName': userName,
        'action': action.toString(),
        'description': description,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _db.collection('audit_logs').add(logData);
      debugPrint('[Audit] Action logged: ${action.toString()} by $userName');
    } catch (e) {
      debugPrint('[Audit] ERROR logging action: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getLogsStream({int limit = 100}) {
    return _db
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
