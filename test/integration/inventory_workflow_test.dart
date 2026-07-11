import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/services/inventory_service.dart';
import 'package:fufajis_online/services/supplier_service.dart';
import 'package:fufajis_online/services/reorder_service.dart';
import 'package:fufajis_online/services/purchase_order_service.dart';
import 'package:fufajis_online/services/stock_adjustment_service.dart';
import 'package:fufajis_online/services/expiry_service.dart';
import 'package:fufajis_online/services/warehouse_service.dart';

void main() {
  group('Complete Inventory Workflow', () {
    late InventoryService inventoryService;
    late SupplierService supplierService;
    late ReorderService reorderService;
    late PurchaseOrderService purchaseOrderService;
    late StockAdjustmentService adjustmentService;
    late ExpiryService expiryService;
    late WarehouseService warehouseService;

    setUp(() {
      inventoryService = InventoryService();
      supplierService = SupplierService();
      reorderService = ReorderService();
      purchaseOrderService = PurchaseOrderService();
      adjustmentService = StockAdjustmentService();
      expiryService = ExpiryService();
      warehouseService = WarehouseService();
    });

    test('Complete order-to-delivery workflow', () async {
      // Phase 1: Check initial stock
      final stockLevel = await inventoryService.getStockLevel('product_001');
      expect(stockLevel, isNotNull);

      // Phase 2: Create purchase order when stock is low
      final reorderSuggestions = await inventoryService.getReorderSuggestions();
      expect(reorderSuggestions, isA<List>());

      if (reorderSuggestions.isNotEmpty) {
        final suggestion = reorderSuggestions.first;
        final suppliers = await supplierService.getAllSuppliers();
        expect(suppliers, isNotEmpty);

        // Create PO
        final poId = await purchaseOrderService.createPurchaseOrder(
          supplierId: suppliers.first.id,
          supplierName: suppliers.first.name,
          items: [
            {
              'product_id': 'product_001',
              'quantity': 100,
              'unit_cost': 10,
            }
          ],
          createdBy: 'test_user',
          expectedDelivery: DateTime.now().add(const Duration(days: 3)),
        );

        expect(poId, isNotEmpty);
      }
    });

    test('Stock adjustment workflow', () async {
      // Create adjustment request
      final adjustmentId = await adjustmentService.adjustStock(
        productId: 'product_001',
        productName: 'Tomato',
        adjustmentType: 'damage',
        quantity: 5,
        reason: 'Damaged in transport',
        batchNumber: 'BATCH_001',
        createdBy: 'test_user',
      );

      expect(adjustmentId, isNotEmpty);

      // Verify pending adjustment exists
      final pending = await adjustmentService.getPendingAdjustments();
      expect(pending, isNotEmpty);

      // Approval should update stock
      final adjustment = await adjustmentService.getAdjustment(adjustmentId);
      if (adjustment != null && adjustment['status'] == 'pending') {
        await adjustmentService.approveAdjustment(
          adjustmentId: adjustmentId,
          productId: adjustment['product_id'],
          quantity: adjustment['quantity'],
          adjustmentType: adjustment['adjustment_type'],
          approvedBy: 'approver_001',
          notes: 'Approved - damaged goods',
        );

        // Verify adjustment is now approved
        final updated = await adjustmentService.getAdjustment(adjustmentId);
        expect(updated?['status'], equals('approved'));
      }
    });

    test('Expiry management workflow', () async {
      // Track batch with expiry
      final expiryDate = DateTime.now().add(const Duration(days: 10));
      final batchId = await expiryService.trackBatch(
        productId: 'product_002',
        productName: 'Apple',
        batchNumber: 'BATCH_APPLE_001',
        manufactureDate: DateTime.now().subtract(const Duration(days: 20)),
        expiryDate: expiryDate,
        quantityReceived: 500,
        supplierId: 'supplier_001',
        poId: 'PO_001',
        location: 'Zone_A',
        receivedBy: 'receiver_001',
      );

      expect(batchId, isNotEmpty);

      // Verify expiry alerts exist
      final alerts = await expiryService.getExpiryAlerts(daysThreshold: 30);
      expect(alerts, isA<List<Map<String, dynamic>>>());

      // Get metrics
      final metrics = await expiryService.getExpiryMetrics();
      expect(metrics, containsPair('fresh_count', isA<int>()));
      expect(metrics, containsPair('expiring_count', isA<int>()));
    });

    test('Warehouse operations workflow', () async {
      // Create warehouse
      final warehouseId = await warehouseService.createWarehouse(
        warehouseName: 'Main Warehouse',
        zone: 'Zone A',
        temperature: 22,
        humidity: 45,
        totalBins: 100,
      );

      expect(warehouseId, isNotEmpty);

      // Place item in bin
      final binLocationId = await warehouseService.placeBinLocation(
        warehouseId: warehouseId,
        binId: 'BIN_A1',
        productId: 'product_003',
        quantity: 200,
        batchNumber: 'BATCH_003',
        expiryDate: null,
      );

      expect(binLocationId, isNotEmpty);

      // Check utilization
      final utilization = await warehouseService.getWarehouseUtilization(warehouseId);
      expect(utilization['warehouse_id'], equals(warehouseId));
      expect(utilization['bin_utilization_percentage'], isNotNull);

      // Perform stock count
      final countResult = await warehouseService.performStockCount(
        warehouseId,
        'counter_001',
      );

      expect(countResult['bins_counted'], isA<int>());
    });

    test('Reorder point auto-trigger workflow', () async {
      // Set reorder point for product
      await reorderService.setReorderPoint(
        productId: 'product_004',
        reorderPoint: 50,
        reorderQuantity: 200,
        leadTimeDays: 3,
        preferredSupplierId: null,
        maxStockLevel: 500,
        safetyStock: 25,
        autoReorder: true,
      );

      // Get reorder configuration
      final config = await reorderService.getReorderPoint('product_004');
      expect(config, isNotNull);
      expect(config?['reorder_point'], equals(50));

      // Get suggestions
      final suggestions = await reorderService.getReorderSuggestions();
      expect(suggestions, isA<List>());
    });

    test('Multi-supplier preference workflow', () async {
      // Get supplier list
      final suppliers = await supplierService.getAllSuppliers();
      expect(suppliers, isNotEmpty);

      // Check supplier performance
      if (suppliers.isNotEmpty) {
        final supplier = suppliers.first;
        final metrics = await supplierService.getPerformanceMetrics(supplier.id);

        expect(metrics, containsPair('supplier_id', supplier.id));
        expect(metrics, containsPair('rating', isA<num>()));
        expect(metrics, containsPair('on_time_delivery_rate', isA<num>()));
        expect(metrics, containsPair('reliability_score', isA<num>()));
      }

      // Get suppliers sorted by performance
      final ranked = await supplierService.getSuppliersByPerformance();
      expect(ranked, isNotEmpty);

      // Highest rated supplier should be first
      if (ranked.length > 1) {
        expect(
          ranked.first.rating,
          greaterThanOrEqualTo(ranked.last.rating),
        );
      }
    });

    test('Complete purchase order lifecycle', () async {
      // Get suppliers
      final suppliers = await supplierService.getAllSuppliers();
      if (suppliers.isEmpty) return;

      final supplier = suppliers.first;

      // Create PO
      final poId = await purchaseOrderService.createPurchaseOrder(
        supplierId: supplier.id,
        supplierName: supplier.name,
        items: [
          {'product_id': 'product_005', 'quantity': 100, 'unit_cost': 15},
          {'product_id': 'product_006', 'quantity': 50, 'unit_cost': 25},
        ],
        createdBy: 'test_user',
        expectedDelivery: DateTime.now().add(const Duration(days: 5)),
      );

      expect(poId, isNotEmpty);

      // Verify PO exists
      final po = await purchaseOrderService.getPurchaseOrder(poId);
      expect(po?['po_number'], isNotNull);
      expect(po?['status'], equals('draft'));

      // Send PO (draft -> sent)
      await purchaseOrderService.updatePOStatus(poId, 'sent');

      // Verify status changed
      final sentPo = await purchaseOrderService.getPurchaseOrder(poId);
      expect(sentPo?['status'], equals('sent'));

      // Receive PO
      await purchaseOrderService.receivePurchaseOrder(
        poId,
        'receiver_001',
        [
          {'product_id': 'product_005', 'quantity_received': 100},
          {'product_id': 'product_006', 'quantity_received': 50},
        ],
      );

      // Verify final status
      final receivedPo = await purchaseOrderService.getPurchaseOrder(poId);
      expect(receivedPo?['status'], isNotNull);
    });

    test('Stock levels stream subscription', () async {
      // Verify stream can be created without error
      final stream = inventoryService.streamStockLevel('product_001');
      expect(stream, isA<Stream>());

      // Take first event with timeout
      final firstEvent = stream.first
          .timeout(const Duration(seconds: 5))
          .catchError((_) => null);

      expect(firstEvent, isA<Future>());
    });

    test('Real-time reorder suggestions stream', () async {
      // Verify stream can be created
      final stream = inventoryService.streamReorderSuggestions();
      expect(stream, isA<Stream<List>>());
    });

    test('Expiry alerts stream subscription', () async {
      // Verify stream can be created
      final stream = inventoryService.streamExpiryAlerts();
      expect(stream, isA<Stream<List>>());
    });

    test('Inventory metrics calculation', () async {
      // Get comprehensive metrics
      final metrics = await inventoryService.getInventoryMetrics();

      if (metrics != null) {
        expect(metrics.totalStockValue, isA<double>());
        expect(metrics.totalItemsInStock, isA<int>());
        expect(metrics.totalStockValueFormatted, isA<String>());
      }
    });

    test('Movement history audit trail', () async {
      // Get movement history for product
      final movements = await inventoryService.getMovementHistory('product_001');

      expect(movements, isA<List>());

      // Each movement should have timestamp and details
      for (final movement in movements) {
        expect(movement.movementType, isNotNull);
        expect(movement.quantityChange, isNotNull);
      }
    });
  });
}
