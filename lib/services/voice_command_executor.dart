import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import 'voice_command_service.dart';
import 'api_client.dart';
import '../utils/monetary_value.dart';

/// Centralized Voice Command Executor for Fufaji Online.
/// Handles execution of all parsed voice intents.
class VoiceCommandExecutor {
  static Future<String> execute(
    VoiceCommand command,
    BuildContext context,
  ) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    switch (command.type) {
      case VoiceCommandType.updateStock:
        return _executeUpdateStock(command, context, user);
      case VoiceCommandType.checkStock:
        return _executeCheckStock(command, context);
      case VoiceCommandType.markOrderDelivered:
        return _executeMarkOrderDelivered(command, context, user);
      case VoiceCommandType.getTodayOrders:
        return _executeGetTodayOrders(command, context, user);
      case VoiceCommandType.getRevenue:
        return _executeGetRevenue(command, context, user);
      case VoiceCommandType.addToCart:
        return _executeAddToCart(command, context);
      case VoiceCommandType.searchProduct:
        return _executeSearchProduct(command, context);
      case VoiceCommandType.getLowStock:
        return _executeGetLowStock(command, context, user);
      case VoiceCommandType.getExpiringItems:
        return _executeGetExpiringItems(command, context, user);
      case VoiceCommandType.setPrice:
        return _executeSetPrice(command, context, user);
      case VoiceCommandType.addProduct:
        return _executeAddProduct(command, context, user);
      case VoiceCommandType.getHelp:
        return _executeGetHelp(command, context, user);
      case VoiceCommandType.unknown:
        return 'Maaf kijiye, mujhe samajh nahi aaya.';
    }
  }

  // ─── CUSTOMER ACTIONS ──────────────────────────────────────────────────────

  static Future<String> _executeSearchProduct(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    final query = cmd.parameters['query'] as String? ?? '';
    if (query.isNotEmpty) {
      context.push('/customer/search?q=${Uri.encodeComponent(query)}');
      return 'Main "$query" dhundh raha hoon.';
    }
    return 'Dhundhne ke liye kuch boliye.';
  }

  static Future<String> _executeAddToCart(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      
      // Use Backend Gemini for smarter parsing and searching
      final response = await ApiClient.instance.post('/ai/voice-to-cart', {
        'transcript': cmd.parameters['raw_text'] ?? cmd.parameters['product'] ?? '',
      });

      if (response.data['success'] == true) {
        final List items = response.data['cartItems'];
        int addedCount = 0;
        String names = '';

        for (var item in items) {
          if (item['matchFound'] == true) {
            // Find in local cache to get full model
            final localProduct = productProvider.products.firstWhere(
              (p) => p.id == item['productId'],
              orElse: () => ProductModel.fromMap({...item, 'id': item['productId'], 'name': item['originalName']}),
            );

            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            for (int i = 0; i < qty; i++) {
              cartProvider.addItem(localProduct);
            }
            addedCount++;
            names += '${item['originalName']}, ';
          }
        }

        if (addedCount > 0) {
          return 'Theek hai, maine ${names.substring(0, names.length - 2)} cart mein daal diya hai.';
        }
      }

      // Fallback to local logic if AI fails or no matches
      final productName = (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 1;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product "$productName" nahi mila.'),
      );

      for (int i = 0; i < qty; i++) {
        cartProvider.addItem(product);
      }
      return '${product.name} ki $qty unit cart mein daal di hai.';
    } catch (e) {
      return 'Maaf kijiye, main ye add nahi kar paya. Dobara koshish karein.';
    }
  }

  // ─── OWNER / EMPLOYEE ACTIONS ──────────────────────────────────────────────

  static Future<String> _executeUpdateStock(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin && user?.role != UserRole.employee) {
      return 'Ye command sirf owner ya employee use kar sakte hain.';
    }

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final productName = (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 0;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product nahi mila.'),
      );

      final updated = product.copyWith(
        stockQuantity: product.stockQuantity + qty,
        updatedAt: DateTime.now(),
      );
      await productProvider.updateProduct(updated);

      return '${product.name} ka stock ab ${updated.stockQuantity} ho gaya hai.';
    } catch (e) {
      return 'Stock update fail ho gaya.';
    }
  }

  static Future<String> _executeCheckStock(
    VoiceCommand cmd,
    BuildContext context,
  ) async {
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final productName = (cmd.parameters['product'] as String? ?? '').toLowerCase();

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product nahi mila.'),
      );

      return '${product.name} ka stock abhi ${product.stockQuantity} ${product.unit} hai.';
    } catch (e) {
      return 'Maal check nahi ho paya.';
    }
  }

  static Future<String> _executeMarkOrderDelivered(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.rider) {
      return 'Sirf delivery agent ya owner ye kar sakte hain.';
    }

    try {
      final orderNumber = cmd.parameters['orderNumber'] as String? ?? '';
      final db = FirebaseFirestore.instance;

      final snap = await db
          .collection('orders')
          .where('orderNumber', isEqualTo: orderNumber)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return 'Order #$orderNumber nahi mila.';

      await snap.docs.first.reference.update({
        'status': 'OrderStatus.delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      return 'Order #$orderNumber delivered mark kar diya hai.';
    } catch (e) {
      return 'Order update fail ho gaya.';
    }
  }

  static Future<String> _executeGetRevenue(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin) {
      return 'Sirf owner hi kamai dekh sakte hain.';
    }

    try {
      final db = FirebaseFirestore.instance;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snap = await db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      double total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['totalAmount'] as num? ?? 0).toDouble();
      }

      if (context.mounted) {
        context.push('/owner/analytics');
      }
      return 'Aaj ki total kamai ₹${total.toStringAsFixed(0)} hai.';
    } catch (e) {
      return 'Data nahi mil raha.';
    }
  }

  static Future<String> _executeGetTodayOrders(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final query = db.collection('orders').where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      );

      final snap = user?.role == UserRole.customer
          ? await query.where('customerId', isEqualTo: user?.id).get()
          : await query.get();

      final count = snap.docs.length;
      
      if (user?.role == UserRole.owner) {
        context.push('/owner/orders');
      } else {
        context.push('/customer/orders');
      }

      return 'Aaj $count orders aaye hain.';
    } catch (e) {
      return 'Orders check nahi ho paye.';
    }
  }

  static Future<String> _executeGetLowStock(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin) {
      return 'Ye command aapke liye nahi hai.';
    }

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final lowStock = productProvider.products
        .where((p) => p.stockQuantity < p.minimumStock)
        .toList();

    if (lowStock.isEmpty) return 'Saara maal stock mein hai!';

    context.push('/owner/inventory-alerts');
    return '${lowStock.length} items kam hain. List screen par dikha raha hoon.';
  }

  static Future<String> _executeGetExpiringItems(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin) {
      return 'Ye command aapke liye nahi hai.';
    }

    context.push('/owner/expiry-tracking');
    return 'Expiry hone wale items ki list dikha raha hoon.';
  }

  static Future<String> _executeSetPrice(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin) {
      return 'Sirf owner price change kar sakte hain.';
    }

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final productName = (cmd.parameters['product'] as String? ?? '').toLowerCase();
      final price = (cmd.parameters['price'] as num?)?.toDouble() ?? 0.0;

      final product = productProvider.products.firstWhere(
        (p) => p.name.toLowerCase().contains(productName),
        orElse: () => throw Exception('Product nahi mila.'),
      );

      await productProvider.updateProduct(product.copyWith(price: MonetaryValue(price)));
      return '${product.name} ka price ₹$price set kar diya hai.';
    } catch (e) {
      return 'Price update fail ho gaya.';
    }
  }

  static Future<String> _executeAddProduct(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role != UserRole.owner && user?.role != UserRole.superAdmin) {
      return 'Sirf owner product add kar sakte hain.';
    }

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final name = cmd.parameters['name'] as String? ?? 'Naya Item';
      final price = (cmd.parameters['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (cmd.parameters['quantity'] as num?)?.toInt() ?? 0;

      final newProduct = ProductModel(
        id: 'v_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: 'Added via voice command',
        price: MonetaryValue(price),
        stockQuantity: qty,
        unit: 'piece',
        categoryId: 'other',
        category: 'other',
        shopId: productProvider.currentShopId ?? 'shop_001',
        shopName: 'Fufaji Online',
        imageUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        district: user?.district ?? 'Jaipur',
      );

      await productProvider.addProduct(newProduct);
      return '$name product add ho gaya hai.';
    } catch (e) {
      return 'Product add nahi hua.';
    }
  }

  static Future<String> _executeGetHelp(
    VoiceCommand cmd,
    BuildContext context,
    UserModel? user,
  ) async {
    if (user?.role == UserRole.owner || user?.role == UserRole.superAdmin) {
      return 'Aap stock update kar sakte hain, jaise "Aloo ka stock 10 kilo kar do". '
          'Ya aaj ki kamai puch sakte hain: "Aaj kitna revenue hua?". '
          'Saare orders dekhne ke liye boliye: "Aaj ke orders dikhao".';
    } else {
      return 'Aap koi bhi saman dhundh sakte hain, jaise "Taaza tamatar dikhao". '
          'Saman cart mein daalne ke liye boliye: "Do kilo chawal add karo". '
          'Apne orders dekhne ke liye boliye: "Mere orders dikhao".';
    }
  }
}
