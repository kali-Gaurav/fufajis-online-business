import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/purchase_order.dart';

class PurchaseOrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generates a draft PO based on items below reorder threshold
  Future<PurchaseOrder?> generateDraftPO(String shopId, List<ProductModel> catalog) async {
    final lowStockItems = catalog.where((p) => p.stockQuantity <= p.minimumStock).toList();
    
    if (lowStockItems.isEmpty) return null;

    final List<PurchaseOrderItem> poItems = lowStockItems.map((p) => PurchaseOrderItem(
      productId: p.id,
      productName: p.name,
      quantity: (p.minimumStock * 2) - p.stockQuantity, // Heuristic: fill to 2x min
      unit: p.unit,
      estimatedCost: (p.costPrice ?? (p.price * 0.8)) * ((p.minimumStock * 2) - p.stockQuantity),
    )).toList();

    double total = poItems.fold(0.0, (sum, item) => sum + item.estimatedCost);

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

  String formatPOForWhatsApp(PurchaseOrder po) {
    String buffer = "*PURCHASE ORDER: Fufaji Super Store*\n";
    buffer += "Date: ${po.createdAt.toString().substring(0, 10)}\n";
    buffer += "--------------------------\n";
    for (var item in po.items) {
      buffer += "• ${item.productName}: ${item.quantity} ${item.unit}\n";
    }
    buffer += "--------------------------\n";
    buffer += "*Estimated Total: ₹${po.totalAmount.round()}*";
    return buffer;
  }
}
