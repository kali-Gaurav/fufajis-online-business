import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import 'package:provider/provider.dart';

/// Executes parsed voice commands (from GeminiService) against Firestore.
class VoiceCommandExecutor {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Main entry point. Takes the parsed command map and executes the intent.
  /// Returns a human-readable confirmation message.
  Future<String> execute(
    Map<String, dynamic> command,
    BuildContext context,
  ) async {
    try {
      final action = (command['action'] as String? ?? '').toUpperCase();
      final name = command['name'] as String? ?? '';
      final quantity = (command['quantity'] ?? 0).toDouble();
      final unit = command['unit'] as String? ?? 'kg';
      final price = (command['price'] ?? 0.0).toDouble();
      final orderId = command['orderId'] as String?;
      final status = command['status'] as String?;

      switch (action) {
        case 'ADD':
          return await _handleAdd(context, name, quantity, unit, price);

        case 'UPDATE':
          return await _handleUpdate(context, name, quantity, unit, price);

        case 'DELETE':
          return await _handleDelete(context, name);

        case 'ORDER_STATUS':
          return await _handleOrderStatus(context, orderId, name, status);

        case 'REPORT':
          return await _handleReport(context);

        default:
          return 'Samajh nahi aaya. Dobara boliye.';
      }
    } catch (e) {
      debugPrint('[VoiceCommandExecutor] execute error: $e');
      return 'Error: ${e.toString().substring(0, 50)}';
    }
  }

  // ─── ADD / UPDATE STOCK ────────────────────────────────────────────────────

  Future<String> _handleAdd(
    BuildContext context,
    String name,
    double quantity,
    String unit,
    double price,
  ) async {
    final existing = await findProductByName(name);

    if (existing != null) {
      // Product already exists — increment stock
      final currentQty = ((existing.data() as Map<String, dynamic>?)?['stockQuantity'] ?? 0).toDouble();
      final newQty = currentQty + quantity;
      await existing.reference.update({
        'stockQuantity': newQty,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Refresh provider
      if (context.mounted) {
        Provider.of<ProductProvider>(context, listen: false)
            .updateShopId(Provider.of<ProductProvider>(context, listen: false).currentShopId);
      }
      return 'Stock updated: ${name.capitalize()} — ${newQty.toStringAsFixed(0)} $unit total';
    } else {
      // New product
      final shopId = context.mounted
          ? Provider.of<ProductProvider>(context, listen: false).currentShopId ?? 'default'
          : 'default';
      final newProduct = ProductModel(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: name.capitalize(),
        price: price > 0 ? price : 0.0,
        stockQuantity: quantity.toInt(),
        unit: unit,
        category: 'vegetables',
        description: 'Voice added product',
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        shopId: shopId,
        shopName: 'Fufaji Online',
        imageUrl: '',
      );
      if (context.mounted) {
        await Provider.of<ProductProvider>(context, listen: false).addProduct(newProduct);
      }
      return 'New product added: ${name.capitalize()} — ${quantity.toStringAsFixed(0)} $unit';
    }
  }

  Future<String> _handleUpdate(
    BuildContext context,
    String name,
    double quantity,
    String unit,
    double price,
  ) async {
    final existing = await findProductByName(name);
    if (existing == null) {
      return 'Product not found: $name. "Add" se try karein.';
    }
    final updateData = <String, dynamic>{
      'stockQuantity': quantity.toInt(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (price > 0) updateData['price'] = price;
    await existing.reference.update(updateData);
    if (context.mounted) {
      Provider.of<ProductProvider>(context, listen: false)
          .updateShopId(Provider.of<ProductProvider>(context, listen: false).currentShopId);
    }
    return 'Stock set: ${name.capitalize()} — ${quantity.toStringAsFixed(0)} $unit';
  }

  Future<String> _handleDelete(BuildContext context, String name) async {
    final existing = await findProductByName(name);
    if (existing == null) {
      return 'Product not found: $name';
    }
    await existing.reference.update({
      'isAvailable': false,
      'stockQuantity': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      Provider.of<ProductProvider>(context, listen: false)
          .updateShopId(Provider.of<ProductProvider>(context, listen: false).currentShopId);
    }
    return 'Product unavailable: ${name.capitalize()} — stock 0 kar diya';
  }

  // ─── ORDER STATUS ──────────────────────────────────────────────────────────

  Future<String> _handleOrderStatus(
    BuildContext context,
    String? orderId,
    String name,
    String? status,
  ) async {
    try {
      // If orderId is a number string, try to find by orderNumber field
      DocumentSnapshot? orderDoc;

      if (orderId != null && orderId.isNotEmpty) {
        // Try direct doc ID first
        final directDoc = await _db.collection('orders').doc(orderId).get();
        if (directDoc.exists) {
          orderDoc = directDoc;
        } else {
          // Try orderNumber field
          final query = await _db
              .collection('orders')
              .where('orderNumber', isEqualTo: orderId)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) orderDoc = query.docs.first;
        }
      }

      if (orderDoc == null) {
        return 'Order #$orderId nahi mila.';
      }

      final newStatus = _normalizeOrderStatus(status ?? 'delivered');
      await orderDoc.reference.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        await Provider.of<OrderProvider>(context, listen: false)
            .updateOrderStatus(orderDoc.id, _parseOrderStatus(newStatus));
      }

      return 'Order #$orderId — status: ${newStatus.split('.').last}';
    } catch (e) {
      debugPrint('[VoiceCommandExecutor] order status error: $e');
      return 'Order update mein error aaya: ${e.toString().substring(0, 40)}';
    }
  }

  String _normalizeOrderStatus(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('deliver')) return 'OrderStatus.delivered';
    if (lower.contains('cancel')) return 'OrderStatus.cancelled';
    if (lower.contains('confirm')) return 'OrderStatus.confirmed';
    if (lower.contains('process')) return 'OrderStatus.processing';
    if (lower.contains('pack')) return 'OrderStatus.packed';
    if (lower.contains('outfor') || lower.contains('out for')) return 'OrderStatus.outForDelivery';
    return 'OrderStatus.delivered';
  }

  OrderStatus _parseOrderStatus(String status) {
    if (status.contains('delivered')) return OrderStatus.delivered;
    if (status.contains('cancelled')) return OrderStatus.cancelled;
    if (status.contains('confirmed')) return OrderStatus.confirmed;
    if (status.contains('processing')) return OrderStatus.processing;
    if (status.contains('packed')) return OrderStatus.packed;
    if (status.contains('outForDelivery')) return OrderStatus.outForDelivery;
    return OrderStatus.delivered;
  }

  // ─── REPORT ───────────────────────────────────────────────────────────────

  Future<String> _handleReport(BuildContext context) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final snap = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();
      final count = snap.docs.length;
      final revenue = snap.docs.fold<double>(
        0.0,
        (sum, d) => sum + ((d.data()['totalAmount'] ?? 0.0) as num).toDouble(),
      );
      return 'Aaj ke orders: $count, Revenue: ₹${revenue.toStringAsFixed(0)}';
    } catch (e) {
      return 'Report fetch mein error: $e';
    }
  }

  // ─── FUZZY PRODUCT SEARCH ─────────────────────────────────────────────────

  /// Tries exact match first, then partial name match (case insensitive).
  Future<DocumentSnapshot?> findProductByName(String name) async {
    if (name.isEmpty) return null;

    final nameLower = name.toLowerCase().trim();

    // 1. Try exact match on 'name' field (case insensitive via tags or lowercase fields)
    try {
      // Search in products collection group
      final exactQuery = await _db
          .collectionGroup('products')
          .where('nameLower', isEqualTo: nameLower)
          .limit(1)
          .get();
      if (exactQuery.docs.isNotEmpty) return exactQuery.docs.first;
    } catch (_) {}

    // 2. Search in root products collection
    try {
      final rootQuery = await _db
          .collection('products')
          .where('nameLower', isEqualTo: nameLower)
          .limit(1)
          .get();
      if (rootQuery.docs.isNotEmpty) return rootQuery.docs.first;
    } catch (_) {}

    // 3. Fallback: get all products and do a client-side fuzzy match
    try {
      final allSnap = await _db.collection('products').limit(200).get();
      for (final doc in allSnap.docs) {
        final docName = (doc.data()['name'] as String? ?? '').toLowerCase();
        if (docName.contains(nameLower) || nameLower.contains(docName)) {
          return doc;
        }
        // Also check tags
        final tags = List<String>.from(doc.data()['tags'] ?? []);
        if (tags.any((t) => t.toLowerCase().contains(nameLower))) {
          return doc;
        }
      }
    } catch (e) {
      debugPrint('[VoiceCommandExecutor] fuzzy search error: $e');
    }

    return null;
  }

  /// Build a confirmation message from the command map and success flag.
  String buildConfirmationMessage(
    Map<String, dynamic> command,
    bool success,
  ) {
    if (!success) return 'Command fail ho gaya. Dobara try karein.';

    final action = (command['action'] as String? ?? '').toUpperCase();
    final name = command['name'] as String? ?? '';
    final quantity = command['quantity'] ?? '';
    final unit = command['unit'] as String? ?? '';

    switch (action) {
      case 'ADD':
        return 'Stock added: $quantity$unit ${name.capitalize()}';
      case 'UPDATE':
        return 'Stock updated: ${name.capitalize()} — $quantity$unit';
      case 'DELETE':
        return 'Product removed: ${name.capitalize()}';
      case 'ORDER_STATUS':
        return 'Order ${command['orderId'] ?? ''} updated!';
      case 'REPORT':
        return 'Report ready!';
      default:
        return 'Done!';
    }
  }
}

// ─── EXTENSIONS ───────────────────────────────────────────────────────────────

extension _StringCap on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
