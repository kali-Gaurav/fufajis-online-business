import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IdempotencyService {
  static final IdempotencyService _instance = IdempotencyService._internal();
  factory IdempotencyService() => _instance;
  IdempotencyService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates a SHA-256 idempotency key
  String generateKey({
    required String operationType,
    required String entityId,
    required String userId,
    required String timestampBucket, // e.g., '2026-06-12T10' for hour-level bucket
  }) {
    final raw = '$operationType|$entityId|$userId|$timestampBucket';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if an operation has already been processed using a Firestore Transaction.
  /// If it hasn't, it reserves the key. Returns true if the operation should PROCEED.
  /// Returns false if it should be IGNORED (already processed).
  ///
  /// This should ideally be called inside a larger transaction, but since Flutter
  /// transactions wrap all reads before writes, we can use this as a standalone guard
  /// or integrate the logic directly into the business transaction.
  Future<bool> checkAndReserveKey(
    String idempotencyKey, {
    Duration expiry = const Duration(days: 7),
  }) async {
    final docRef = _db.collection('idempotency_keys').doc(idempotencyKey);

    try {
      final canProceed = await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          // Key exists, check if it's expired
          final data = snapshot.data()!;
          final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
          if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
            // Expired key, we can proceed and overwrite
            transaction.set(docRef, {
              'key': idempotencyKey,
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(DateTime.now().add(expiry)),
              'status': 'PROCESSING',
            });
            return true;
          }
          // Valid key found, block execution
          return false;
        }

        // Key doesn't exist, reserve it
        transaction.set(docRef, {
          'key': idempotencyKey,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(expiry)),
          'status': 'PROCESSING',
        });
        return true;
      });

      return canProceed;
    } catch (e) {
      // In case of error (e.g. network failure), we might want to fail closed to prevent duplicates.
      throw Exception('Idempotency check failed: $e');
    }
  }

  /// Marks an idempotency key as COMPLETED with an optional result reference
  Future<void> markCompleted(String idempotencyKey, {String? resultReference}) async {
    final docRef = _db.collection('idempotency_keys').doc(idempotencyKey);
    await docRef.set({
      'status': 'COMPLETED',
      'resultReference': resultReference,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
