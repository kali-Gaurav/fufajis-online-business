import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/purchase_order.dart';
import '../utils/monetary_value.dart';

class PurchaseOrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates a draft PO based on items below reorder threshold
  Future<PurchaseOrder?> generateDraftPO(
    String shopId,
    List<ProductModel> catalog,
  ) async {
    final lowStockItems = catalog
        .where((p) => p.stockQuantity <= p.minimumStock)
        .toList();

    if (lowStockItems.isEmpty) return null;

    final List<PurchaseOrderItem> poItems = lowStockItems
        .map(
          (p) => PurchaseOrderItem(
            productId: p.id,
            productName: p.name,
            quantity:
                (p.minimumStock * 2) -
                p.stockQuantity, // Heuristic: fill to 2x min
            unit: p.unit,
            estimatedCost:
                MonetaryValue(p.costPrice ?? (p.price * 0.8)).toDouble() *
                ((p.minimumStock * 2) - p.stockQuantity),
          ),
        )
        .toList();

    double total = poItems.fold(
      0.0,
      (total, item) => total + item.estimatedCost,
    );

    return PurchaseOrder(
      id: 'po_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      distributorName: 'Default Mandi Supplier',
      items: poItems,
      totalAmount: total,
      createdAt: DateTime.now(),
    );
  }

  Future<void> savePO(PurchaseOrder po) async {
    await _db.collection('purchase_orders').doc(po.id).set(po.toMap());
  }

  /// Create a PurchaseOrder from bill scan results (challan already received)
  Future<PurchaseOrder> createPOFromBillScan({
    required String shopId,
    required String supplierName,
    required String billNumber,
    required String billDate,
    required List<Map<String, dynamic>> items,
  }) async {
    final poItems = items.map((item) => PurchaseOrderItem(
      productId: item['matchedProductId']?.toString() ?? '',
      productName: item['name']?.toString() ?? 'Unknown',
      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
      unit: item['unit']?.toString() ?? 'kg',
      estimatedCost: (item['total'] as num?)?.toDouble() ?? 0.0,
    )).toList();

    final total = poItems.fold<double>(
      0.0,
      (sum, item) => sum + item.estimatedCost,
    );

    final po = PurchaseOrder(
      id: 'po_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      distributorName: supplierName,
      items: poItems,
      totalAmount: total,
      createdAt: DateTime.now(),
      status: 'received', // Goods already arrived (scanned from challan)
    );

    // Save to Firestore
    await savePO(po);

    // Also log the bill reference
    await _db.collection('purchase_orders').doc(po.id).update({
      'billNumber': billNumber,
      'billDate': billDate,
      'source': 'bill_scan_ocr',
    });

    return po;
  }

  String formatPOForWhatsApp(PurchaseOrder po) {
    String buffer = "*PURCHASE ORDER: Fufaji Super Store*\n";
    buffer += "Date: ${po.createdAt.toString().substring(0, 10)}\n";
    buffer += "Supplier: ${po.distributorName}\n";
    buffer += "--------------------------\n";
    for (var item in po.items) {
      buffer += "• ${item.productName}: ${item.quantity} ${item.unit}";
      if (item.estimatedCost > 0) {
        buffer += " (₹${item.estimatedCost.round()})";
      }
      buffer += "\n";
    }
    buffer += "--------------------------\n";
    buffer += "*Estimated Total: ₹${po.totalAmount.round()}*";
    return buffer;
  }

  /// Get summary text for display
  String formatPOSummary(PurchaseOrder po) {
    return '${po.items.length} items from ${po.distributorName} — ₹${po.totalAmount.round()}';
  }
}
