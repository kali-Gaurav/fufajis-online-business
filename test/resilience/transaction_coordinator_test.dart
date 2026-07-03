import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/core/resilience/transaction_coordinator.dart';

void main() {
  group('TransactionCoordinator Saga Pattern Tests', () {
    test('Successful execution completes all steps without rollbacks', () async {
      final coordinator = TransactionCoordinator();
      bool step1Executed = false;
      bool step2Executed = false;
      bool step1Compensated = false;

      coordinator.addStep(
        name: 'Step 1',
        action: () async => step1Executed = true,
        compensation: () async => step1Compensated = true,
      );

      coordinator.addStep(name: 'Step 2', action: () async => step2Executed = true);

      final results = await coordinator.execute();

      expect(results.length, 2);
      expect(step1Executed, true);
      expect(step2Executed, true);
      expect(step1Compensated, false);
    });

    test('Failure in step 2 triggers compensation for step 1', () async {
      final coordinator = TransactionCoordinator();
      bool step1Executed = false;
      bool step1Compensated = false;

      coordinator.addStep(
        name: 'Create Order',
        action: () async => step1Executed = true,
        compensation: () async => step1Compensated = true,
      );

      coordinator.addStep(
        name: 'Capture Payment (Fails)',
        action: () async => throw Exception('Payment Gateway Error'),
      );

      expect(() => coordinator.execute(), throwsA(isA<Exception>()));

      // Allow async rollback to complete in test environment
      await Future.delayed(const Duration(milliseconds: 50));

      expect(step1Executed, true);
      expect(step1Compensated, true); // Verified Rollback
    });
  });
}
