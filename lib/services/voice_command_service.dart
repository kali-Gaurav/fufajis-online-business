import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product_model.dart';
import 'hinglish_voice_search_parser.dart';
import 'hindi_product_dictionary.dart';

// ─────────────── COMMAND TYPE ENUM ───────────────

enum VoiceCommandType {
  updateStock,
  checkStock,
  markOrderDelivered,
  getTodayOrders,
  getRevenue,
  addToCart,
  searchProduct,
  getLowStock,
  getExpiringItems,
  setPrice,
  addProduct,
  unknown,
}

// ─────────────── VOICE COMMAND MODEL ───────────────

class VoiceCommand {
  final VoiceCommandType type;
  final Map<String, dynamic> parameters;
  final String originalText;
  final double confidence; // 0.0–1.0

  const VoiceCommand({
    required this.type,
    required this.parameters,
    required this.originalText,
    this.confidence = 1.0,
  });

  factory VoiceCommand.unknown(String text) => VoiceCommand(
        type: VoiceCommandType.unknown,
        parameters: const {},
        originalText: text,
        confidence: 0.0,
      );

  /// Human-readable confirmation string (Hindi/Hinglish)
  String get confirmationText {
    switch (type) {
      case VoiceCommandType.updateStock:
        final product = parameters['product'] ?? '';
        final qty = parameters['quantity'] ?? '';
        final unit = parameters['unit'] ?? '';
        return 'Stock update karunga: $product +$qty$unit. Confirm?';
      case VoiceCommandType.checkStock:
        return '${parameters['product'] ?? ''} ka stock check karunga. Confirm?';
      case VoiceCommandType.markOrderDelivered:
        return 'Order #${parameters['orderNumber']} deliver mark karunga. Confirm?';
      case VoiceCommandType.getTodayOrders:
        return 'Aaj ke saare orders dikhaunga. Confirm?';
      case VoiceCommandType.getRevenue:
        return 'Aaj ki kamai dikhaunga. Confirm?';
      case VoiceCommandType.addToCart:
        final product = parameters['product'] ?? '';
        final qty = parameters['quantity'] ?? '';
        final unit = parameters['unit'] ?? '';
        return 'Cart mein daalunga: $qty$unit $product. Confirm?';
      case VoiceCommandType.searchProduct:
        return '"${parameters['query'] ?? ''}" search karunga. Confirm?';
      case VoiceCommandType.getLowStock:
        return 'Low stock items check karunga. Confirm?';
      case VoiceCommandType.getExpiringItems:
        return 'Jaldi expire hone wale items check karunga. Confirm?';
      case VoiceCommandType.setPrice:
        final product = parameters['product'] ?? '';
        final price = parameters['price'] ?? '';
        return '$product ka price ₹$price set karunga. Confirm?';
      case VoiceCommandType.addProduct:
        final product = parameters['name'] ?? '';
        final price = parameters['price'] ?? '';
        final qty = parameters['quantity'] ?? '';
        return 'Naya product: $product (₹$price, Qty: $qty) add karunga. Confirm?';
      case VoiceCommandType.unknown:
        return 'Samajh nahi aaya: "$originalText"';
    }
  }

  @override
  String toString() =>
      'VoiceCommand(type=$type, params=$parameters, text="$originalText", conf=${confidence.toStringAsFixed(2)})';
}

// ─────────────── VOICE COMMAND SERVICE ───────────────

class VoiceCommandService {
  static final VoiceCommandService _instance =
      VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final HinglishVoiceSearchParser _parser = HinglishVoiceSearchParser();

  // ── Pattern Groups ──────────────────────────────────

  static final _updateStockPatterns = [
    RegExp(
      r'(.+?)\s+(?:ka\s+)?stock\s+(\d+(?:\.\d+)?)\s*(kilo|kg|gram|gm|g|litre|l|liter|packet|bottle|piece|pcs)?\s*(?:kar|karo|update|set)',
      caseSensitive: false,
    ),
    RegExp(
      r'(\d+(?:\.\d+)?)\s*(kilo|kg|gram|gm|g|litre|l|liter|packet|bottle|piece)?\s+(.+?)\s+(?:stock\s+)?(?:mein\s+)?(?:add|daal|daalo|update|kar|karo)',
      caseSensitive: false,
    ),
    RegExp(
      r'(.+?)\s+(?:ka\s+)?(?:stock|maal)\s+(\d+(?:\.\d+)?)\s*(kilo|kg|gram|gm|litre|l|liter|packet|bottle|piece)?',
      caseSensitive: false,
    ),
  ];

  static final _checkStockPatterns = [
    RegExp(
      r'(.+?)\s+kitna(?:\s+hai|\s+bacha|\s+bachha)?',
      caseSensitive: false,
    ),
    RegExp(
      r'kitna\s+(.+?)\s+(?:hai|bacha|bachha|left)',
      caseSensitive: false,
    ),
    RegExp(
      r'(.+?)\s+(?:ka\s+)?stock\s+(?:check|batao|kitna)',
      caseSensitive: false,
    ),
  ];

  static final _deliverOrderPatterns = [
    RegExp(
      r'order\s+(?:number\s+)?#?(\d+)\s+(?:deliver|complete|ho\s+gaya|delivered|done)',
      caseSensitive: false,
    ),
    RegExp(
      r'#?(\d+)\s+(?:number\s+)?order\s+(?:deliver|complete|ho\s+gaya)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:deliver|delivered|complete)\s+order\s+#?(\d+)',
      caseSensitive: false,
    ),
  ];

  static final _todayOrdersPatterns = [
    RegExp(
      r'aaj\s+(?:kitne|ke|ke\s+saare)\s+order',
      caseSensitive: false,
    ),
    RegExp(r"today['s\s]+orders?", caseSensitive: false),
    RegExp(r'aaj\s+ke\s+orders?', caseSensitive: false),
    RegExp(r'orders?\s+(?:aaj|today)', caseSensitive: false),
  ];

  static final _revenuePatterns = [
    RegExp(
      r'aaj\s+(?:kitni\s+)?(?:kamai|revenue|income|sale|bikri)',
      caseSensitive: false,
    ),
    RegExp(r"today['s\s]+(?:revenue|sales?|income|earning)", caseSensitive: false),
    RegExp(r"(?:aaj\s+ka|today['s\s]+)\s*(?:revenue|sale)", caseSensitive: false),
  ];

  static final _addToCartPatterns = [
    RegExp(
      r'(\d+(?:\.\d+)?|ek|do|teen|char|paanch|aadha|pav)\s*(kilo|kg|gram|gm|g|litre|l|liter|packet|bottle|piece)?\s+(.+?)\s+(?:cart\s+mein\s+daal|cart\s+mein\s+add|cart|add)',
      caseSensitive: false,
    ),
    RegExp(
      r'(.+?)\s+(\d+(?:\.\d+)?)\s*(kilo|kg|gram|gm|g|litre|l|packet|bottle|piece)?\s+(?:cart\s+mein|add\s+to\s+cart|cart)',
      caseSensitive: false,
    ),
  ];

  static final _searchPatterns = [
    RegExp(r'(.+?)\s+(?:dhundo|search|find|dekho|dikhao)', caseSensitive: false),
    RegExp(r'(?:search|find|dhundo)\s+(.+)', caseSensitive: false),
  ];

  static final _lowStockPatterns = [
    RegExp(r'kya\s+khatam\s+ho\s+raha\s+hai', caseSensitive: false),
    RegExp(r'(?:kaunsa|konsa)\s+(?:maal|saman|item)\s+khatam', caseSensitive: false),
    RegExp(r'low\s+stock', caseSensitive: false),
    RegExp(r'stock\s+(?:khatam|kam)', caseSensitive: false),
  ];

  static final _expiringPatterns = [
    RegExp(r'kya\s+expire', caseSensitive: false),
    RegExp(r'(?:kaunsa|konsa)\s+(?:item|saman|maal)\s+expire', caseSensitive: false),
    RegExp(r'expiring\s+(?:soon|items)', caseSensitive: false),
  ];

  static final _setPricePatterns = [
    RegExp(r'(.+?)\s+ka\s+(?:price|bhav|daam|rate)\s+(\d+)\s*(?:rupaye|rs|rupya)?\s*(?:kar|karo|set|update)', caseSensitive: false),
  ];

  static final _addProductPatterns = [
    RegExp(r'(?:naya|new)\s+(?:product|item)\s+(?:add\s+kar|daal|bana)\s+(.+?)\s+(\d+)\s*(?:rupaye|rs|rupya)\s+(\d+)\s*(?:packet|kilo|kg|piece)', caseSensitive: false),
  ];

  static const Map<String, double> _wordNumbers = {
    'ek': 1.0, 'do': 2.0, 'teen': 3.0, 'char': 4.0, 'paanch': 5.0,
    'chhe': 6.0, 'sat': 7.0, 'aath': 8.0, 'nau': 9.0, 'das': 10.0,
    'aadha': 0.5, 'pav': 0.25,
  };

  static const Map<String, String> _unitNorm = {
    'kilo': 'kg', 'kg': 'kg', 'gram': 'g', 'gm': 'g', 'g': 'g',
    'litre': 'l', 'liter': 'l', 'l': 'l',
    'packet': 'packet', 'bottle': 'bottle', 'piece': 'piece', 'pcs': 'piece',
  };

  Future<VoiceCommand> parse(String rawText) async {
    if (rawText.trim().isEmpty) return VoiceCommand.unknown(rawText);

    final text = rawText.trim().toLowerCase();

    if (_matchesAny(text, _todayOrdersPatterns)) {
      return VoiceCommand(
        type: VoiceCommandType.getTodayOrders,
        parameters: const {},
        originalText: rawText,
        confidence: 0.95,
      );
    }

    if (_matchesAny(text, _revenuePatterns)) {
      return VoiceCommand(
        type: VoiceCommandType.getRevenue,
        parameters: const {},
        originalText: rawText,
        confidence: 0.95,
      );
    }

    if (_matchesAny(text, _lowStockPatterns)) {
      return VoiceCommand(
        type: VoiceCommandType.getLowStock,
        parameters: const {},
        originalText: rawText,
        confidence: 0.95,
      );
    }

    if (_matchesAny(text, _expiringPatterns)) {
      return VoiceCommand(
        type: VoiceCommandType.getExpiringItems,
        parameters: const {},
        originalText: rawText,
        confidence: 0.95,
      );
    }

    for (final pattern in _setPricePatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        return VoiceCommand(
          type: VoiceCommandType.setPrice,
          parameters: {
            'product': _translateProduct(m.group(1)!.trim()),
            'price': double.tryParse(m.group(2) ?? '0') ?? 0.0,
          },
          originalText: rawText,
          confidence: 0.9,
        );
      }
    }

    for (final pattern in _addProductPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        return VoiceCommand(
          type: VoiceCommandType.addProduct,
          parameters: {
            'name': m.group(1)!.trim(),
            'price': double.tryParse(m.group(2) ?? '0') ?? 0.0,
            'quantity': double.tryParse(m.group(3) ?? '0') ?? 0.0,
          },
          originalText: rawText,
          confidence: 0.9,
        );
      }
    }

    for (final pattern in _deliverOrderPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        return VoiceCommand(
          type: VoiceCommandType.markOrderDelivered,
          parameters: {'orderNumber': m.group(1)!.trim()},
          originalText: rawText,
          confidence: 0.95,
        );
      }
    }

    final updateCmd = _tryParseUpdateStock(text, rawText);
    if (updateCmd != null) return updateCmd;

    final cartCmd = _tryParseAddToCart(text, rawText);
    if (cartCmd != null) return cartCmd;

    final checkCmd = _tryParseCheckStock(text, rawText);
    if (checkCmd != null) return checkCmd;

    for (final pattern in _searchPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        final rawProduct = (m.groupCount >= 1 ? m.group(1) : null) ?? '';
        final intent = await _parser.parse(rawProduct);
        return VoiceCommand(
          type: VoiceCommandType.searchProduct,
          parameters: {
            'query': intent.productQuery.isNotEmpty
                ? intent.productQuery
                : _translateProduct(rawProduct),
          },
          originalText: rawText,
          confidence: 0.8,
        );
      }
    }

    final intent = await _parser.parse(rawText);
    if (intent.productQuery.isNotEmpty && intent.confidence > 0.6) {
      return VoiceCommand(
        type: VoiceCommandType.searchProduct,
        parameters: {'query': intent.productQuery},
        originalText: rawText,
        confidence: intent.confidence * 0.7,
      );
    }

    return VoiceCommand.unknown(rawText);
  }

  VoiceCommand? _tryParseUpdateStock(String text, String rawText) {
    final p1 = _updateStockPatterns[0].firstMatch(text);
    if (p1 != null) {
      final productRaw = p1.group(1)?.trim() ?? '';
      final qty = double.tryParse(p1.group(2) ?? '') ?? 1.0;
      final unit = _normalizeUnit(p1.group(3) ?? 'kg');
      return VoiceCommand(
        type: VoiceCommandType.updateStock,
        parameters: {
          'product': _translateProduct(productRaw),
          'quantity': qty,
          'unit': unit,
        },
        originalText: rawText,
        confidence: 0.9,
      );
    }

    final p2 = _updateStockPatterns[1].firstMatch(text);
    if (p2 != null) {
      final qtyRaw = p2.group(1)?.trim() ?? '1';
      final qty = _wordNumbers[qtyRaw] ?? double.tryParse(qtyRaw) ?? 1.0;
      final unit = _normalizeUnit(p2.group(2) ?? 'kg');
      final productRaw = p2.group(3)?.trim() ?? '';
      return VoiceCommand(
        type: VoiceCommandType.updateStock,
        parameters: {
          'product': _translateProduct(productRaw),
          'quantity': qty,
          'unit': unit,
        },
        originalText: rawText,
        confidence: 0.85,
      );
    }

    final p3 = _updateStockPatterns[2].firstMatch(text);
    if (p3 != null) {
      final productRaw = p3.group(1)?.trim() ?? '';
      final qty = double.tryParse(p3.group(2) ?? '') ?? 1.0;
      final unit = _normalizeUnit(p3.group(3) ?? 'kg');
      return VoiceCommand(
        type: VoiceCommandType.updateStock,
        parameters: {
          'product': _translateProduct(productRaw),
          'quantity': qty,
          'unit': unit,
        },
        originalText: rawText,
        confidence: 0.8,
      );
    }

    return null;
  }

  VoiceCommand? _tryParseCheckStock(String text, String rawText) {
    for (final pattern in _checkStockPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        final rawProduct = (m.groupCount >= 1 ? m.group(1) : null) ?? '';
        return VoiceCommand(
          type: VoiceCommandType.checkStock,
          parameters: {'product': _translateProduct(rawProduct.trim())},
          originalText: rawText,
          confidence: 0.85,
        );
      }
    }
    return null;
  }

  VoiceCommand? _tryParseAddToCart(String text, String rawText) {
    final p1 = _addToCartPatterns[0].firstMatch(text);
    if (p1 != null) {
      final qtyRaw = p1.group(1)?.trim() ?? '1';
      final qty = _wordNumbers[qtyRaw] ?? double.tryParse(qtyRaw) ?? 1.0;
      final unit = _normalizeUnit(p1.group(2) ?? 'piece');
      final productRaw = p1.group(3)?.trim() ?? '';
      return VoiceCommand(
        type: VoiceCommandType.addToCart,
        parameters: {
          'product': _translateProduct(productRaw),
          'quantity': qty,
          'unit': unit,
        },
        originalText: rawText,
        confidence: 0.9,
      );
    }

    final p2 = _addToCartPatterns[1].firstMatch(text);
    if (p2 != null) {
      final productRaw = p2.group(1)?.trim() ?? '';
      final qty = double.tryParse(p2.group(2) ?? '') ?? 1.0;
      final unit = _normalizeUnit(p2.group(3) ?? 'piece');
      return VoiceCommand(
        type: VoiceCommandType.addToCart,
        parameters: {
          'product': _translateProduct(productRaw),
          'quantity': qty,
          'unit': unit,
        },
        originalText: rawText,
        confidence: 0.85,
      );
    }

    return null;
  }

  bool _matchesAny(String text, List<RegExp> patterns) =>
      patterns.any((p) => p.hasMatch(text));

  String _normalizeUnit(String raw) =>
      _unitNorm[raw.toLowerCase().trim()] ?? raw.toLowerCase().trim();

  String _translateProduct(String raw) {
    if (raw.isEmpty) return raw;
    return translateHindiProduct(raw);
  }
}

// ─────────────── VOICE COMMAND EXECUTOR ───────────────

class VoiceCommandExecutor {
  static Future<String> execute(
    VoiceCommand command,
    BuildContext context,
  ) async {
    switch (command.type) {
      case VoiceCommandType.updateStock:
        return _executeUpdateStock(command, context);
      case VoiceCommandType.checkStock:
        return _executeCheckStock(command, context);
      case VoiceCommandType.markOrderDelivered:
        return _executeMarkOrderDelivered(command, context);
      case VoiceCommandType.getTodayOrders:
        return _executeGetTodayOrders(command, context);
      case VoiceCommandType.getRevenue:
        return _executeGetRevenue(command, context);
      case VoiceCommandType.addToCart:
        return _executeAddToCart(command, context);
      case VoiceCommandType.searchProduct:
        return _executeSearchProduct(command, context);
      case VoiceCommandType.getLowStock:
        return _executeGetLowStock(command, context);
      case VoiceCommandType.getExpiringItems:
        return _executeGetExpiringItems(command, context);
      case VoiceCommandType.setPrice:
        return _executeSetPrice(command, context);
      case VoiceCommandType.addProduct:
        return _executeAddProduct(command, context);
      case VoiceCommandType.unknown:
        return 'Samajh nahi aaya. Phir se boliye.';
    }
  }

  static Future<String> _executeUpdateStock(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final productName = (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 0;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product not found: $productName'),
      );

      final updated = product.copyWith(
        stockQuantity: product.stockQuantity + qty,
        updatedAt: DateTime.now(),
      );
      await productProvider.updateProduct(updated);

      return '${product.name} ka stock ${updated.stockQuantity} ho gaya!';
    } catch (e) {
      return 'Stock update nahi hua: $e';
    }
  }

  static Future<String> _executeCheckStock(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final productName =
        (cmd.parameters['product'] as String? ?? '').toLowerCase();

    final product = productProvider.products.firstWhere(
      (p) => p.name.toLowerCase().contains(productName),
      orElse: () => throw Exception('Product not found'),
    );

    return '${product.name} ka stock: ${product.stockQuantity} ${product.unit}';
  }

  static Future<String> _executeMarkOrderDelivered(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final orderNumber = cmd.parameters['orderNumber'] as String? ?? '';
      final db = FirebaseFirestore.instance;

      final snap = await db
          .collection('orders')
          .where('orderNumber', isEqualTo: orderNumber)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return 'Order #$orderNumber nahi mila.';
      }

      await snap.docs.first.reference.update({
        'status': 'OrderStatus.delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return 'Order #$orderNumber deliver mark ho gaya!';
    } catch (e) {
      return 'Order update nahi hua: $e';
    }
  }

  static Future<String> _executeGetTodayOrders(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = auth.currentUser?.role;

      final db = FirebaseFirestore.instance;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final query = db.collection('orders').where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );

      // If customer, only show their orders
      final snap = role == UserRole.customer
          ? await query.where('customerId', isEqualTo: auth.currentUser?.id).get()
          : await query.get();

      final count = snap.docs.length;

      if (role == UserRole.shopOwner) {
        context.push('/owner/orders');
      } else if (role == UserRole.customer) {
        context.push('/customer/orders');
      }

      return 'Aaj $count order aaye hain.';
    } catch (e) {
      return 'Orders fetch nahi hue: $e';
    }
  }

  static Future<String> _executeGetRevenue(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser?.role == UserRole.shopOwner) {
        context.push('/owner/analytics');
      }

      final db = FirebaseFirestore.instance;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snap = await db
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('status', whereIn: [
            'OrderStatus.delivered',
            'OrderStatus.confirmed',
            'OrderStatus.processing',
            'OrderStatus.packed',
            'OrderStatus.outForDelivery',
          ])
          .get();

      double total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        total += (data['totalAmount'] as num? ?? 0).toDouble();
      }

      return 'Aaj ki kamai: Rs. ${total.toStringAsFixed(0)}';
    } catch (e) {
      return 'Revenue fetch nahi hua: $e';
    }
  }

  static Future<String> _executeAddToCart(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final productName =
          (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 1;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product not found: $productName'),
      );

      for (int i = 0; i < qty; i++) {
        cartProvider.addItem(product);
      }
      return '${product.name} x$qty cart mein daal diya!';
    } catch (e) {
      return 'Cart mein add nahi hua: $e';
    }
  }

  static Future<String> _executeSearchProduct(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    final query = cmd.parameters['query'] as String? ?? '';
    if (query.isNotEmpty) {
      context.push('/customer/search?q=${Uri.encodeComponent(query)}');
      return 'Main "$query" search kar raha hoon.';
    }
    return 'Search query nahi mili.';
  }

  static Future<String> _executeGetLowStock(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.role == UserRole.shopOwner) {
      context.push('/owner/inventory-alerts');
    }

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final lowStock = productProvider.products
        .where((p) => p.stockQuantity < p.minimumStock)
        .toList();

    if (lowStock.isEmpty) {
      return 'Saara maal stock mein hai!';
    }

    final items =
        lowStock.map((p) => '${p.name} (${p.stockQuantity})').join(', ');
    return 'Ye items kam hain: $items';
  }

  static Future<String> _executeGetExpiringItems(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.currentUser?.role == UserRole.shopOwner) {
      context.push('/owner/expiry-tracking');
    }

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 7));

    final expiring = productProvider.products.where((p) {
      if (p.expiryDate == null) return false;
      return p.expiryDate!.isAfter(now) && p.expiryDate!.isBefore(soon);
    }).toList();

    if (expiring.isEmpty) {
      return 'Agli ek hafte mein koi item expire nahi ho raha.';
    }

    final items = expiring.map((p) => p.name).join(', ');
    return 'Ye items jaldi expire hone wale hain: $items';
  }

  static Future<String> _executeSetPrice(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final productName =
          (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final price = (cmd.parameters['price'] as num?)?.toDouble() ?? 0.0;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product not found: $productName'),
      );

      final updated = product.copyWith(
        price: price,
        updatedAt: DateTime.now(),
      );
      await productProvider.updateProduct(updated);

      return '${product.name} ka naya price Rs. $price ho gaya!';
    } catch (e) {
      return 'Price update nahi hua: $e';
    }
  }

  static Future<String> _executeAddProduct(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      final name = cmd.parameters['name'] as String? ?? 'Naya Product';
      final price = (cmd.parameters['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 0;

      final newProduct = ProductModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: 'Voice added product',
        price: price,
        stockQuantity: qty,
        unit: 'piece',
        category: 'other',
        shopId: productProvider.currentShopId ?? 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: '',
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await productProvider.addProduct(newProduct);
      return '$name add ho gaya!';
    } catch (e) {
      return 'Product add nahi hua: $e';
    }
  }
}
