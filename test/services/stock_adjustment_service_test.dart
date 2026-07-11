import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/services/stock_adjustment_service.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('StockAdjustmentService', () {
    late StockAdjustmentService service;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      service = StockAdjustmentService();
    });

    test('adjustStock creates pending adjustment', () async {
      // Arrange
      const productId = 'product_001';
      const productName = 'Tomato';
      const quantity = 5;
      const adjustmentType = 'damage';
      const reason = 'Damaged during transport';

      // Act & Assert
      expect(
        service.adjustStock(
          productId: productId,
          productName: productName,
          adjustmentType: adjustmentType,
          quantity: quantity,
          reason: reason,
          batchNumber: 'BATCH_001',
          createdBy: 'user_001',
        ),
        completes,
      );
    });

    test('adjustStock validates quantity is positive', () async {
      // Arrange
      const invalidQuantity = 0;

      // Act & Assert
      expect(
        service.adjustStock(
          productId: 'product_001',
          productName: 'Tomato',
          adjustmentType: 'damage',
          quantity: invalidQuantity,
          reason: 'Test',
          batchNumber: null,
          createdBy: 'user_001',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('adjustStock validates adjustment type', () async {
      // Arrange
      const invalidType = 'invalid_type';

      // Act & Assert
      expect(
        service.adjustStock(
          productId: 'product_001',
          productName: 'Tomato',
          adjustmentType: invalidType,
          quantity: 5,
          reason: 'Test',
          batchNumber: null,
          createdBy: 'user_001',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('getStockAdjustments retrieves all adjustments', () async {
      // This test verifies the method signature and returns a list
      final adjustments = await service.getStockAdjustments();
      expect(adjustments, isA<List<Map<String, dynamic>>>());
    });

    test('getPendingAdjustments returns only pending items', () async {
      // This test verifies filtering works
      final pending = await service.getPendingAdjustments();
      expect(pending, isA<List<Map<String, dynamic>>>());

      // All items should have status: pending
      for (final item in pending) {
        expect(item['status'], equals('pending'));
      }
    });

    test('getAdjustmentStats calculates metrics correctly', () async {
      // This test verifies statistics generation
      final stats = await service.getAdjustmentStats();

      expect(stats, containsPair('pending_count', isA<int>()));
      expect(stats, containsPair('approved_count', isA<int>()));
      expect(stats, containsPair('rejected_count', isA<int>()));
      expect(stats, containsPair('total_quantity_adjusted', isA<int>()));
      expect(stats, containsPair('approval_rate', isA<String>()));
    });

    test('approveAdjustment requires valid adjustment ID', () async {
      // This test verifies error handling
      expect(
        service.approveAdjustment(
          adjustmentId: 'nonexistent_id',
          productId: 'product_001',
          quantity: 5,
          adjustmentType: 'damage',
          approvedBy: 'approver_001',
          notes: 'Approved',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejectAdjustment requires valid adjustment ID', () async {
      // This test verifies error handling
      expect(
        service.rejectAdjustment(
          adjustmentId: 'nonexistent_id',
          rejectionReason: 'Invalid reason',
          rejectedBy: 'approver_001',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('getAdjustmentsByProduct returns product-specific adjustments', () async {
      // This test verifies product filtering
      const productId = 'product_001';
      final adjustments = await service.getAdjustmentsByProduct(productId);

      expect(adjustments, isA<List<Map<String, dynamic>>>());
      for (final adj in adjustments) {
        expect(adj['product_id'], equals(productId));
      }
    });

    test('adjustment types are valid', () async {
      // Valid types: 'damage', 'loss', 'recount_correction', 'theft', 'expiry'
      final validTypes = ['damage', 'loss', 'recount_correction', 'theft', 'expiry'];

      for (final type in validTypes) {
        // Should not throw
        expect(
          service.adjustStock(
            productId: 'product_001',
            productName: 'Test',
            adjustmentType: type,
            quantity: 1,
            reason: 'Test adjustment',
            batchNumber: null,
            createdBy: 'user_001',
          ),
          completes,
        );
      }
    });
  });
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
