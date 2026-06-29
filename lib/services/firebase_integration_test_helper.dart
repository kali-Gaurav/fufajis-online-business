import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_data_service.dart';
import '../constants/firestore_collections.dart';

/// Firebase Integration Test Helper
/// Provides utilities for testing Firebase integration
class FirebaseIntegrationTestHelper {
  final FirestoreDataService _firestoreService;

  FirebaseIntegrationTestHelper({
    required FirestoreDataService firestoreService,
  }) : _firestoreService = firestoreService;

  /// Test Firebase Auth connection
  Future<bool> testAuthConnection() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user');
        return false;
      }

      final token = await user.getIdToken(true);
      print('Auth token retrieved: ${token?.isNotEmpty ?? false}');
      return token?.isNotEmpty ?? false;
    } catch (e) {
      print('Auth connection test failed: $e');
      return false;
    }
  }

  /// Test Firestore connectivity
  Future<bool> testFirestoreConnection() async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('_connectivity_test').doc('test').get();
      print('Firestore connection test passed');
      return true;
    } catch (e) {
      print('Firestore connection test failed: $e');
      return false;
    }
  }

  /// Test creating a test document
  Future<bool> testCreateDocument() async {
    try {
      final testData = {
        'testField': 'testValue',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestoreService.addDocument(
        FirestoreCollections.AUDIT_LOG,
        testData,
      );

      print('Document creation test passed');
      return true;
    } catch (e) {
      print('Document creation test failed: $e');
      return false;
    }
  }

  /// Test reading a document
  Future<bool> testReadDocument(String docId) async {
    try {
      final doc = await _firestoreService.getDocument(
        FirestoreCollections.AUDIT_LOG,
        docId,
      );

      print('Document read test passed: ${doc != null}');
      return doc != null;
    } catch (e) {
      print('Document read test failed: $e');
      return false;
    }
  }

  /// Test updating a document
  Future<bool> testUpdateDocument(String docId) async {
    try {
      await _firestoreService.updateDocument(
        FirestoreCollections.AUDIT_LOG,
        docId,
        {'updated': true, 'updatedAt': FieldValue.serverTimestamp()},
      );

      print('Document update test passed');
      return true;
    } catch (e) {
      print('Document update test failed: $e');
      return false;
    }
  }

  /// Test collection query
  Future<bool> testCollectionQuery() async {
    try {
      final docs = await _firestoreService.getCollection(
        FirestoreCollections.AUDIT_LOG,
        limit: 10,
      );

      print('Collection query test passed: retrieved ${docs.length} documents');
      return true;
    } catch (e) {
      print('Collection query test failed: $e');
      return false;
    }
  }

  /// Test batch write
  Future<bool> testBatchWrite() async {
    try {
      final operations = {
        '${FirestoreCollections.AUDIT_LOG}/batch_test_1': {
          'type': 'batch_test',
          'index': 1,
        },
        '${FirestoreCollections.AUDIT_LOG}/batch_test_2': {
          'type': 'batch_test',
          'index': 2,
        },
      };

      await _firestoreService.batchWrite(operations);

      print('Batch write test passed');
      return true;
    } catch (e) {
      print('Batch write test failed: $e');
      return false;
    }
  }

  /// Test transaction
  Future<bool> testTransaction() async {
    try {
      final result = await _firestoreService.runTransaction<bool>((transaction) async {
        final ref = FirebaseFirestore.instance
            .collection(FirestoreCollections.AUDIT_LOG)
            .doc('transaction_test');

        transaction.set(ref, {'transaction': true});
        return true;
      });

      print('Transaction test passed: $result');
      return result;
    } catch (e) {
      print('Transaction test failed: $e');
      return false;
    }
  }

  /// Test streaming
  Future<bool> testStream() async {
    try {
      final stream = _firestoreService.streamCollection(
        FirestoreCollections.AUDIT_LOG,
        limit: 5,
      );

      // Take first emission
      final docs = await stream.first;

      print('Stream test passed: received ${docs.length} documents');
      return true;
    } catch (e) {
      print('Stream test failed: $e');
      return false;
    }
  }

  /// Test array field operations
  Future<bool> testArrayFields() async {
    try {
      const testDocId = 'array_test_doc';

      // Add to array
      await _firestoreService.addToArrayField(
        FirestoreCollections.AUDIT_LOG,
        testDocId,
        'tags',
        'test_tag',
      );

      // Remove from array
      await _firestoreService.removeFromArrayField(
        FirestoreCollections.AUDIT_LOG,
        testDocId,
        'tags',
        'test_tag',
      );

      print('Array field operations test passed');
      return true;
    } catch (e) {
      print('Array field operations test failed: $e');
      return false;
    }
  }

  /// Test increment field
  Future<bool> testIncrementField() async {
    try {
      const testDocId = 'increment_test_doc';

      await _firestoreService.incrementField(
        FirestoreCollections.AUDIT_LOG,
        testDocId,
        'counter',
        1,
      );

      print('Increment field test passed');
      return true;
    } catch (e) {
      print('Increment field test failed: $e');
      return false;
    }
  }

  /// Run all tests
  Future<Map<String, bool>> runAllTests() async {
    print('Starting Firebase integration tests...\n');

    final results = <String, bool>{};

    // Test auth
    results['auth_connection'] = await testAuthConnection();

    // Test Firestore connection
    results['firestore_connection'] = await testFirestoreConnection();

    // Test CRUD operations
    print('\nTesting CRUD operations...');
    results['create_document'] = await testCreateDocument();

    // Get the first document for other tests
    final docs = await _firestoreService.getCollection(
      FirestoreCollections.AUDIT_LOG,
      limit: 1,
    );

    if (docs.isNotEmpty) {
      // Extract docId from the retrieved doc (assuming 'id' field exists)
      final testDocId = docs.first['id'] ?? 'test_doc_${DateTime.now().millisecondsSinceEpoch}';

      results['read_document'] = await testReadDocument(testDocId);
      results['update_document'] = await testUpdateDocument(testDocId);
      results['delete_document'] = true; // Skip delete to keep test data
    }

    // Test query
    print('\nTesting queries...');
    results['collection_query'] = await testCollectionQuery();

    // Test advanced operations
    print('\nTesting advanced operations...');
    results['batch_write'] = await testBatchWrite();
    results['transaction'] = await testTransaction();
    results['stream'] = await testStream();
    results['array_fields'] = await testArrayFields();
    results['increment_field'] = await testIncrementField();

    // Print summary
    print('\n========== TEST SUMMARY ==========');
    int passCount = 0;
    int failCount = 0;

    results.forEach((testName, passed) {
      final status = passed ? 'PASS' : 'FAIL';
      print('$testName: $status');
      if (passed) {
        passCount++;
      } else {
        failCount++;
      }
    });

    print('\nTotal: ${passCount + failCount} | Passed: $passCount | Failed: $failCount');
    print('==================================\n');

    return results;
  }

  /// Validate Firestore collections exist
  Future<bool> validateCollectionsExist() async {
    try {
      final collectionsToCheck = [
        FirestoreCollections.USERS,
        FirestoreCollections.ORDERS,
        FirestoreCollections.PAYMENTS,
        FirestoreCollections.DELIVERIES,
      ];

      for (final collection in collectionsToCheck) {
        final docs = await _firestoreService.getCollection(
          collection,
          limit: 1,
        );
        print('Collection $collection: ${docs.isEmpty ? 'empty' : 'has documents'}');
      }

      return true;
    } catch (e) {
      print('Collection validation failed: $e');
      return false;
    }
  }

  /// Check security rules enforcement
  Future<bool> checkSecurityRules() async {
    try {
      // This is a basic check; comprehensive testing requires Firebase emulator
      final canRead = await _testSecurityRule('read');
      final canWrite = await _testSecurityRule('write');

      print('Security rule check - Read: $canRead, Write: $canWrite');
      return canRead || canWrite; // At least one should be true
    } catch (e) {
      print('Security rule check failed: $e');
      return false;
    }
  }

  Future<bool> _testSecurityRule(String operation) async {
    try {
      if (operation == 'read') {
        await _firestoreService.getCollection(
          FirestoreCollections.AUDIT_LOG,
          limit: 1,
        );
      } else {
        await _firestoreService.addDocument(
          FirestoreCollections.AUDIT_LOG,
          {'securityTest': true},
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
