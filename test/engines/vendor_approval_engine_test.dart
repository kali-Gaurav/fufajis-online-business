import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/vendor_approval_engine.dart';
import 'package:fufajis_online/models/shop_model.dart';
import 'package:fufajis_online/services/order_status_engine.dart';

void main() {

  late VendorApprovalEngine engine;

  setUp(() {
    engine = VendorApprovalEngine();
  });

  group('VendorApprovalEngine Workflow Validation', () {
    test('Valid vendor onboarding transitions should succeed', () {
      expect(() => engine.validateTransition(ShopApprovalStatus.draft, ShopApprovalStatus.under_review, 'shop_owner'), returnsNormally);
      expect(() => engine.validateTransition(ShopApprovalStatus.under_review, ShopApprovalStatus.approved, 'admin'), returnsNormally);
    });

    test('Standard vendor cannot approve themselves', () {
      expect(
        () => engine.validateTransition(ShopApprovalStatus.under_review, ShopApprovalStatus.approved, 'shop_owner'),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });
  });
}
