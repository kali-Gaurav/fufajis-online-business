import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:fufajis_online/core/resilience/retry_engine.dart';
import 'package:fufajis_online/core/errors/app_exceptions.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RetryEngine engine;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    engine = RetryEngine(firestore: fakeFirestore);
  });

  group('RetryEngine Tests', () {
    test('Operation succeeds on first try', () async {
      int attempt = 0;
      final result = await engine.executeWithRetry<String>(
        operationName: 'Test Success',
        operation: () async {
          attempt++;
          return 'done';
        },
        payload: {'test': true},
        config: const RetryConfig(maxRetries: 3),
      );

      expect(result, 'done');
      expect(attempt, 1);
    });

    test('Operation succeeds after retries', () async {
      int attempt = 0;
      final result = await engine.executeWithRetry<String>(
        operationName: 'Test Recovery',
        operation: () async {
          attempt++;
          if (attempt < 3) {
            throw Exception('Fail');
          }
          return 'recovered';
        },
        payload: {'test': true},
        config: const RetryConfig(
          maxRetries: 3,
          // Fast intervals for testing
          backoffIntervals: [Duration(milliseconds: 10), Duration(milliseconds: 20)],
        ),
      );

      expect(result, 'recovered');
      expect(attempt, 3);
    });

    test('Exhausted retries writes to Dead Letter Queue', () async {
      int attempt = 0;

      expect(
        () => engine.executeWithRetry<String>(
          operationName: 'Test Exhaustion',
          operation: () async {
            attempt++;
            throw Exception('Persistent Fail');
          },
          payload: {'orderId': '123'},
          config: const RetryConfig(
            maxRetries: 2,
            backoffIntervals: [Duration(milliseconds: 10), Duration(milliseconds: 20)],
          ),
        ),
        throwsA(isA<AppException>()),
      );

      // Wait a bit to ensure async execution completes and DLQ is written
      await Future.delayed(const Duration(milliseconds: 100));

      expect(attempt, 3); // 1 initial + 2 retries = 3 total attempts

      final dlqDocs = await fakeFirestore.collection('failed_operations').get();
      expect(dlqDocs.docs.length, 1);
      final docData = dlqDocs.docs.first.data();
      expect(docData['operationName'], 'Test Exhaustion');
      expect(docData['status'], 'PENDING_MANUAL_REVIEW');
    });
  });
}
