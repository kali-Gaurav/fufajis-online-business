import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import 'whatsapp_notification_service.dart';
import '../utils/monetary_value.dart';

class ReplacementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Suggests replacements for an out-of-stock product
  List<ProductModel> suggestReplacements(ProductModel original, List<ProductModel> catalog) {
    // Strategy: Same category, similar price point, in stock
    final available = catalog.where((p) => p.id != original.id && p.stockQuantity > 0).toList();

    // 1. Filter by category
    var matches = available.where((p) => p.category == original.category).toList();

    // 2. Score by tag overlap
    matches.sort((a, b) {
      final aOverlap = a.tags.where((t) => original.tags.contains(t)).length;
      final bOverlap = b.tags.where((t) => original.tags.contains(t)).length;
      return bOverlap.compareTo(aOverlap);
    });

    return matches.take(3).toList();
  }

  /// Suggests replacements querying Firestore by category
  Future<List<ProductModel>> findSubstitutes(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) return [];
      final original = ProductModel.fromMap(doc.data()!);

      final snapshot = await _firestore
          .collection('products')
          .where('category', isEqualTo: original.category)
          .where('stockQuantity', isGreaterThan: 0)
          .get();

      final catalog = snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data()))
          .where((p) => p.id != productId)
          .toList();

      return suggestReplacements(original, catalog);
    } catch (e) {
      return [];
    }
  }

  /// Get user-specific substitution preferences
  Future<bool> getCustomerPreference(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['allowSubstitutions'] ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Proposes a substitution for an item in an order and triggers the WhatsApp notification
  Future<void> proposeSubstitution({
    required String orderId,
    required OrderItem item,
    required ProductModel replacement,
    required String customerPhone,
    required String customerName,
    required String orderNumber,
  }) async {
    try {
      final docRef = _firestore.collection('orders').doc(orderId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final order = OrderModel.fromMap(docSnapshot.data()!);
      final updatedItems = order.items.map((it) {
        if (it.id == item.id) {
          return it.copyWith(
            substitutionStatus: 'pending',
            proposedReplacementId: replacement.id,
            proposedReplacementName: replacement.name,
            proposedReplacementPrice: replacement.price,
            substitutionTimestamp: DateTime.now(),
          );
        }
        return it;
      }).toList();

      await docRef.update({
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (customerPhone.isNotEmpty) {
        await WhatsAppNotificationService.sendSubstitutionNotification(
          phoneNumber: customerPhone,
          customerName: customerName,
          orderNumber: orderNumber,
          originalName: item.productName,
          replacementName: replacement.name,
          replacementPrice: replacement.price.toDouble(),
        );
      }
    } catch (e) {
      print('Error proposing substitution: $e');
    }
  }

  /// Checks and auto-approves pending substitutions that have exceeded the 10-minute timeout window.
  Future<void> autoApproveOrTimeoutSubstitutions(String orderId) async {
    try {
      final docRef = _firestore.collection('orders').doc(orderId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final order = OrderModel.fromMap(docSnapshot.data()!);
      bool didChange = false;

      final updatedItems = order.items.map((it) {
        if (it.substitutionStatus == 'pending' && it.substitutionTimestamp != null) {
          final diff = DateTime.now().difference(it.substitutionTimestamp!);
          if (diff.inMinutes >= 10) {
            didChange = true;
            return it.copyWith(
              productId: it.proposedReplacementId,
              productName: it.proposedReplacementName,
              price: it.proposedReplacementPrice,
              totalPrice: (it.proposedReplacementPrice ?? MonetaryValue(0.0)) * it.quantity,
              substitutionStatus: 'approved',
              isPacked: true,
            );
          }
        }
        return it;
      }).toList();

      if (didChange) {
        final newSubtotal = updatedItems.fold(0.0, (total, it) => total + it.totalPrice.toDouble());
        final newTotal = newSubtotal + order.deliveryCharge.toDouble() - order.discount.toDouble();

        await docRef.update({
          'items': updatedItems.map((e) => e.toMap()).toList(),
          'subtotal': newSubtotal,
          'totalAmount': newTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error auto-approving substitutions: $e');
    }
  }

  /// Explicitly handle a customer's approve or decline response
  Future<void> handleSubstitutionResponse({
    required String orderId,
    required String itemId,
    required bool approved,
  }) async {
    try {
      final docRef = _firestore.collection('orders').doc(orderId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final order = OrderModel.fromMap(docSnapshot.data()!);
      final updatedItems = order.items.map((it) {
        if (it.id == itemId) {
          if (approved) {
            return it.copyWith(
              productId: it.proposedReplacementId,
              productName: it.proposedReplacementName,
              price: it.proposedReplacementPrice,
              totalPrice: (it.proposedReplacementPrice ?? MonetaryValue(0.0)) * it.quantity,
              substitutionStatus: 'approved',
              isPacked: true,
            );
          } else {
            return it.copyWith(
              substitutionStatus: 'declined',
              isOutOfStock: true,
              isPacked: false,
              totalPrice: MonetaryValue(0.0),
            );
          }
        }
        return it;
      }).toList();

      final newSubtotal = updatedItems.fold(0.0, (total, it) => total + it.totalPrice.toDouble());
      final newTotal = newSubtotal + order.deliveryCharge.toDouble() - order.discount.toDouble();

      await docRef.update({
        'items': updatedItems.map((e) => e.toMap()).toList(),
        'subtotal': newSubtotal,
        'totalAmount': newTotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error handling substitution response: $e');
    }
  }

  /// Sends substitution request via WhatsApp (Legacy)
  Future<void> sendWhatsAppApprovalRequest(
    String phoneNumber,
    ProductModel original,
    ProductModel replacement,
  ) async {
    await WhatsAppNotificationService.sendSubstitutionNotification(
      phoneNumber: phoneNumber,
      customerName: "Valued Customer",
      orderNumber: "TEMP",
      originalName: original.name,
      replacementName: replacement.name,
      replacementPrice: replacement.price.toDouble(),
    );
  }

  String formatReplacementMessage(ProductModel original, ProductModel replacement) {
    return "Sorry, ${original.name} is out of stock. Would you like ${replacement.name} instead (₹${replacement.price})?";
  }
}
