import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore Data Service for Fufaji
/// Handles all CRUD operations, transactions, and batch writes
class FirestoreDataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Create or update a document
  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).set(
            data,
            SetOptions(merge: merge),
          );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set document in $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Create a new document with auto-generated ID
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final docRef = await _firestore.collection(collection).add(data);

      _isLoading = false;
      notifyListeners();

      return docRef.id;
    } catch (e) {
      _error = 'Failed to add document to $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get a single document
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final DocumentSnapshot doc =
          await _firestore.collection(collection).doc(documentId).get();

      _isLoading = false;
      notifyListeners();

      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      _error =
          'Failed to get document from $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Get a collection with optional filters
  Future<List<Map<String, dynamic>>> getCollection(
    String collection, {
    String? whereField,
    dynamic whereValue,
    String? whereOperator = '==',
    List<Map<String, dynamic>>? multipleWhere,
    String? orderBy,
    bool descending = false,
    int? limit = 50,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      Query query = _firestore.collection(collection);

      // Apply single where clause
      if (whereField != null && whereValue != null) {
        query = _applyWhereClause(query, whereField, whereOperator, whereValue);
      }

      // Apply multiple where clauses
      if (multipleWhere != null) {
        for (final Map<String, dynamic> condition in multipleWhere) {
          final field = condition['field'] as String;
          final value = condition['value'];
          final operator = condition['operator'] as String?;

          query = _applyWhereClause(query, field, operator, value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final QuerySnapshot snapshot = await query.get();

      _isLoading = false;
      notifyListeners();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      _error = 'Failed to get collection $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update a document
  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).update(data);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update document in $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a document
  Future<void> deleteDocument(
    String collection,
    String documentId,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).delete();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete document from $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Batch write operations
  Future<void> batchWrite(
    Map<String, Map<String, dynamic>> operations,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final WriteBatch batch = _firestore.batch();

      operations.forEach((path, data) {
        final parts = path.split('/');
        if (parts.length < 2) {
          throw Exception('Invalid path format: $path');
        }

        final collection = parts[0];
        final documentId = parts[1];
        final docRef = _firestore.collection(collection).doc(documentId);

        batch.set(docRef, data, SetOptions(merge: true));
      });

      await batch.commit();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Batch write failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Transaction for atomic multi-step operations
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction) updateFunction,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _firestore.runTransaction(updateFunction);

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Transaction failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Real-time listener for a single document
  Stream<Map<String, dynamic>?> streamDocument(
    String collection,
    String documentId,
  ) {
    return _firestore
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .map((doc) => doc.data());
  }

  /// Real-time listener for a collection
  Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    String? whereField,
    dynamic whereValue,
    String? orderBy,
    bool descending = false,
    int? limit = 50,
  }) {
    Query query = _firestore.collection(collection);

    if (whereField != null && whereValue != null) {
      query = query.where(whereField, isEqualTo: whereValue);
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  /// Delete entire collection (use with caution)
  Future<void> deleteCollection(String collection) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final QuerySnapshot snapshot = await _firestore.collection(collection).get();

      final WriteBatch batch = _firestore.batch();

      for (final DocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete collection $collection: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Increment a numeric field
  Future<void> incrementField(
    String collection,
    String documentId,
    String field,
    num value,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.increment(value),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to increment field: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Add to an array field
  Future<void> addToArrayField(
    String collection,
    String documentId,
    String field,
    dynamic value,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.arrayUnion([value]),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add to array field: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Remove from an array field
  Future<void> removeFromArrayField(
    String collection,
    String documentId,
    String field,
    dynamic value,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection(collection).doc(documentId).update({
        field: FieldValue.arrayRemove([value]),
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove from array field: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Apply where clause with operator
  Query _applyWhereClause(
    Query query,
    String field,
    String? operator,
    dynamic value,
  ) {
    switch (operator) {
      case '<':
        return query.where(field, isLessThan: value);
      case '<=':
        return query.where(field, isLessThanOrEqualTo: value);
      case '>':
        return query.where(field, isGreaterThan: value);
      case '>=':
        return query.where(field, isGreaterThanOrEqualTo: value);
      case '!=':
        return query.where(field, isNotEqualTo: value);
      case 'in':
        return query.where(field, whereIn: value as List);
      case 'array-contains':
        return query.where(field, arrayContains: value);
      default:
        return query.where(field, isEqualTo: value);
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
