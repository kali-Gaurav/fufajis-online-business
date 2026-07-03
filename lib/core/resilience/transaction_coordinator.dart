import 'dart:async';
import 'package:flutter/foundation.dart';
import '../errors/app_exceptions.dart';

typedef SagaStepAction = Future<dynamic> Function();
typedef SagaCompensationAction = Future<void> Function();

class SagaStep {
  final String name;
  final SagaStepAction action;
  final SagaCompensationAction? compensation;

  SagaStep({required this.name, required this.action, this.compensation});
}

class TransactionCoordinator {
  final List<SagaStep> _steps = [];
  final List<SagaStep> _completedSteps = [];

  void addStep({
    required String name,
    required SagaStepAction action,
    SagaCompensationAction? compensation,
  }) {
    _steps.add(SagaStep(name: name, action: action, compensation: compensation));
  }

  Future<List<dynamic>> execute() async {
    final List<dynamic> results = [];
    _completedSteps.clear();

    try {
      for (final step in _steps) {
        debugPrint('[TransactionCoordinator] Executing step: ${step.name}');
        final result = await step.action();
        results.add(result);
        _completedSteps.add(step);
      }
      return results;
    } catch (e, stackTrace) {
      debugPrint(
        '[TransactionCoordinator] Transaction failed at step ${_steps[_completedSteps.length].name}: $e',
      );
      await _rollback();
      throw ErrorMapper.map(e, stackTrace);
    }
  }

  Future<void> _rollback() async {
    debugPrint(
      '[TransactionCoordinator] Initiating rollback for ${_completedSteps.length} completed steps.',
    );
    // Execute compensations in reverse order
    for (int i = _completedSteps.length - 1; i >= 0; i--) {
      final step = _completedSteps[i];
      if (step.compensation != null) {
        try {
          debugPrint('[TransactionCoordinator] Compensating step: ${step.name}');
          await step.compensation!();
          debugPrint('[TransactionCoordinator] Successfully compensated: ${step.name}');
        } catch (compensationError) {
          // If compensation fails, it MUST be dead-lettered
          debugPrint(
            '[TransactionCoordinator] CRITICAL: Compensation failed for ${step.name}: $compensationError',
          );
          // Note: In Step 4 (Retry Engine & Dead Letter), we will intercept this and queue it.
          // For now, we print and continue other rollbacks.
        }
      } else {
        debugPrint('[TransactionCoordinator] No compensation required for: ${step.name}');
      }
    }
    debugPrint('[TransactionCoordinator] Rollback complete.');
  }
}
