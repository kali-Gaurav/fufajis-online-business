import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import '../models/product_model.dart';

// ─────────────── BILL SCAN RESULT MODEL ───────────────

class BillScanItem {
  String name;
  double quantity;
  String unit;
  double pricePerUnit;
  double total;
  bool isSelected;
  String? matchedProductId;
  String? matchedProductName;
  bool get isMatched => matchedProductId != null;

  BillScanItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.total,
    this.isSelected = true,
    this.matchedProductId,
    this.matchedProductName,
  });

  factory BillScanItem.fromMap(Map<String, dynamic> map) {
    return BillScanItem(
      name: map['name']?.toString() ?? 'Unknown',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit']?.toString() ?? 'kg',
      pricePerUnit: (map['pricePerUnit'] as num?)?.toDouble() ??
          (map['price'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BillScanResult {
  final String supplierName;
  final String billNumber;
  final String billDate;
  final List<BillScanItem> items;

  BillScanResult({
    required this.supplierName,
    required this.billNumber,
    required this.billDate,
    required this.items,
  });

  double get totalAmount => items
      .where((i) => i.isSelected)
      .fold(0.0, (sum, i) => sum + i.total);

  int get selectedCount => items.where((i) => i.isSelected).length;
  int get matchedCount => items.where((i) => i.isMatched).length;
}

// ─────────────── BILL OCR SERVICE ───────────────

class BillOCRService {
  static final BillOCRService _instance = BillOCRService._internal();
  factory BillOCRService() => _instance;
  BillOCRService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Legacy: Scans a bill image and returns a simple list of items (Feature 82)
  Future<List<Map<String, dynamic>>> scanBill(Uint8List imageBytes) async {
    try {
      debugPrint('[BillOCRService] Starting OCR scan for bill...');
      
      // 1. Extract raw text from image
      final rawText = await _geminiService.extractTextFromImage(imageBytes);
      
      if (rawText.isEmpty) {
        debugPrint('[BillOCRService] No text extracted from image.');
        return [];
      }

      // 2. Parse items from text
      final items = await _geminiService.parseBillItems(rawText);
      
      debugPrint('[BillOCRService] Successfully parsed ${items.length} items from bill.');
      return items;
    } catch (e) {
      debugPrint('[BillOCRService] Error during bill OCR: $e');
      return [];
    }
  }

  /// Enhanced: Scans bill and returns structured result with supplier info
  Future<BillScanResult> scanBillStructured(Uint8List imageBytes) async {
    try {
      debugPrint('[BillOCRService] Starting structured bill scan...');

      final result = await _geminiService.extractBillWithSupplierDetails(imageBytes);

      final rawItems = result['items'] as List? ?? [];
      final items = rawItems.map((m) {
        final map = m is Map<String, dynamic> ? m : Map<String, dynamic>.from(m);
        return BillScanItem.fromMap(map);
      }).toList();

      // Recalculate totals if missing
      for (final item in items) {
        if (item.total <= 0 && item.pricePerUnit > 0) {
          item.total = item.quantity * item.pricePerUnit;
        }
      }

      debugPrint('[BillOCRService] Structured scan: ${items.length} items from ${result['supplier']}');

      return BillScanResult(
        supplierName: result['supplier']?.toString() ?? 'Unknown',
        billNumber: result['billNumber']?.toString() ?? 'N/A',
        billDate: result['billDate']?.toString() ?? DateTime.now().toString().substring(0, 10),
        items: items,
      );
    } catch (e) {
      debugPrint('[BillOCRService] Structured scan error: $e');
      return BillScanResult(
        supplierName: 'Unknown',
        billNumber: 'N/A',
        billDate: DateTime.now().toString().substring(0, 10),
        items: [],
      );
    }
  }

  /// Match scanned items to existing products in inventory
  void matchItemsToProducts(BillScanResult result, List<ProductModel> products) {
    for (final item in result.items) {
      final itemNameLower = item.name.toLowerCase().trim();

      // Try exact match first, then partial match
      ProductModel? matched;
      for (final product in products) {
        final pNameLower = product.name.toLowerCase().trim();
        if (pNameLower == itemNameLower) {
          matched = product;
          break;
        }
      }

      // Partial match: product name contains item name or vice versa
      if (matched == null) {
        for (final product in products) {
          final pNameLower = product.name.toLowerCase().trim();
          if (pNameLower.contains(itemNameLower) || itemNameLower.contains(pNameLower)) {
            matched = product;
            break;
          }
        }
      }

      if (matched != null) {
        item.matchedProductId = matched.id;
        item.matchedProductName = matched.name;
      }
    }

    debugPrint('[BillOCRService] Matched ${result.matchedCount}/${result.items.length} items to existing products');
  }
}
