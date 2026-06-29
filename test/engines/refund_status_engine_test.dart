import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/refund_status_engine.dart';
import 'package:fufajis_online/models/refund_request_model.dart';
import 'package:fufajis_online/services/order_status_engine.dart';

void main() {

  late RefundStatusEngine engine;

  setUp(() {
    engine = RefundStatusEngine();
  });

  group('RefundStatusEngine Workflow Validation', () {
    test('Valid workflow transitions should succeed', () {
      expect(() => engine.validateTransition(RefundStatus.pending, RefundStatus.approved, 'admin'), returnsNormally);
      expect(() => engine.validateTransition(RefundStatus.approved, RefundStatus.processing, 'finance'), returnsNormally);
      expect(() => engine.validateTransition(RefundStatus.processing, RefundStatus.completed, 'system'), returnsNormally);
    });

    test('Unauthorized user cannot approve refund', () {
      expect(
        () => engine.validateTransition(RefundStatus.pending, RefundStatus.approved, 'customer'),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
      expect(
        () => engine.validateTransition(RefundStatus.pending, RefundStatus.approved, 'delivery_partner'),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });

    test('Finance role is authorized for processing and completing', () {
      expect(() => engine.validateTransition(RefundStatus.approved, RefundStatus.processing, 'finance'), returnsNormally);
      expect(() => engine.validateTransition(RefundStatus.processing, RefundStatus.completed, 'finance'), returnsNormally);
    });
  });
}
