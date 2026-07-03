import 'package:flutter/material.dart';
import '../providers/product_provider.dart';
import 'package:provider/provider.dart';

class ProcurementService {
  static final ProcurementService _instance = ProcurementService._internal();
  factory ProcurementService() => _instance;
  ProcurementService._internal();

  /// Generates a list of items that need to be ordered from suppliers
  List<Map<String, dynamic>> generatePurchaseList(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final lowStockItems = productProvider.products
        .where((p) => p.stockQuantity <= p.minimumStock)
        .toList();

    return lowStockItems.map((p) {
      final orderQty = (p.minimumStock * 2) - p.stockQuantity;
      return {
        'productId': p.id,
        'name': p.name,
        'currentStock': p.stockQuantity,
        'minStock': p.minimumStock,
        'suggestedOrder': orderQty > 0 ? orderQty : p.minimumStock,
        'unit': p.unit,
        'lastCost': p.costPrice ?? 0.0,
      };
    }).toList();
  }

  /// Formats the purchase list for WhatsApp sharing
  String formatForWhatsApp(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return "No items need restocking today! ✅";

    final buffer = StringBuffer();
    buffer.writeln("📋 *Fufaji Restock List*");
    buffer.writeln("Date: ${DateTime.now().toString().split(' ')[0]}");
    buffer.writeln("--------------------------");

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln("${i + 1}. *${item['name']}*");
      buffer.writeln("   Qty: ${item['suggestedOrder']} ${item['unit']}");
      buffer.writeln("   (Stock: ${item['currentStock']})");
    }

    buffer.writeln("--------------------------");
    buffer.writeln("Total Items: ${items.length}");
    return buffer.toString();
  }
}
