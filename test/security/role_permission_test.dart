import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/order_status_engine.dart';
import 'package:fufajis_online/services/refund_status_engine.dart';
import 'package:fufajis_online/services/vendor_approval_engine.dart';
import 'package:fufajis_online/constants/order_status.dart';
import 'package:fufajis_online/models/refund_request_model.dart';
import 'package:fufajis_online/models/shop_model.dart';

void main() {
  late OrderStatusEngine orderEngine;
  late RefundStatusEngine refundEngine;
  late VendorApprovalEngine vendorEngine;

  setUp(() {
    orderEngine = OrderStatusEngine();
    refundEngine = RefundStatusEngine();
    vendorEngine = VendorApprovalEngine();
  });

  group('RBAC Matrix Validation', () {
    test('Customer role limitations', () {
      // Allowed
      expect(
        () =>
            orderEngine.validateTransition(OrderStatus.pending, OrderStatus.cancelled, 'customer'),
        returnsNormally,
      );
      expect(
        () =>
            refundEngine.validateTransition(RefundStatus.failed, RefundStatus.pending, 'customer'),
        returnsNormally,
      );

      // Denied
      expect(
        () =>
            orderEngine.validateTransition(OrderStatus.processing, OrderStatus.packed, 'customer'),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
      expect(
        () => refundEngine.validateTransition(
          RefundStatus.pending,
          RefundStatus.approved,
          'customer',
        ),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
      expect(
        () => vendorEngine.validateTransition(
          ShopApprovalStatus.under_review,
          ShopApprovalStatus.approved,
          'customer',
        ),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });

    test('Vendor (Shop Owner) role limitations', () {
      // Allowed
      expect(
        () => orderEngine.validateTransition(
          OrderStatus.confirmed,
          OrderStatus.processing,
          'shop_owner',
        ),
        returnsNormally,
      );
      expect(
        () => vendorEngine.validateTransition(
          ShopApprovalStatus.draft,
          ShopApprovalStatus.under_review,
          'shop_owner',
        ),
        returnsNormally,
      );

      // Denied
      expect(
        () => refundEngine.validateTransition(
          RefundStatus.pending,
          RefundStatus.approved,
          'shop_owner',
        ),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
      expect(
        () => vendorEngine.validateTransition(
          ShopApprovalStatus.under_review,
          ShopApprovalStatus.approved,
          'shop_owner',
        ),
        throwsA(isA<UnauthorizedWorkflowException>()),
      );
    });

    test('Admin role global access', () {
      expect(
        () => orderEngine.validateTransition(OrderStatus.processing, OrderStatus.packed, 'admin'),
        returnsNormally,
      );
      expect(
        () => refundEngine.validateTransition(RefundStatus.pending, RefundStatus.approved, 'admin'),
        returnsNormally,
      );
      expect(
        () => vendorEngine.validateTransition(
          ShopApprovalStatus.under_review,
          ShopApprovalStatus.approved,
          'admin',
        ),
        returnsNormally,
      );
    });
  });
}
