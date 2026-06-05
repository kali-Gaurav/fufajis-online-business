import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/purchase_order.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartScanService
//
// Context-aware auto-complete engine. Each scan mode gets its own method
// that auto-fetches everything the UI needs so screens require zero typing
// for data the system already knows.
//
// General contract:
//   1. Scan happens
//   2. Call the matching autoXxx() method
//   3. Result contains pre-filled data + recommended action
//   4. Screen applies data, auto-focuses next input or auto-confirms
// ─────────────────────────────────────────────────────────────────────────────

class SmartScanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 1. Product lookup (receiving / audit / shelf) ───────────────────────────

  /// Looks up a product by barcode. Also fetches the most recent open
  /// Purchase Order line for this product so quantity can be pre-filled.
  Future<ProductScanResult> autoProduct({
    required String barcode,
    required String shopId,
    required String branchId,
  }) async {
    ProductModel? product;
    PurchaseOrderLine? openPoLine;
    int dbStock = 0;

    try {
      // Try branch-scoped product first, then shop-level fallback
      final branchSnap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('branches')
          .doc(branchId)
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (branchSnap.docs.isNotEmpty) {
        product = ProductModel.fromMap(
          branchSnap.docs.first.data()
            ..['id'] = branchSnap.docs.first.id,
        );
        dbStock = (product.stockQuantity).toInt();
      } else {
        // Fallback: shop-level product catalog
        final shopSnap = await _db
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .limit(1)
            .get();

        if (shopSnap.docs.isNotEmpty) {
          product = ProductModel.fromMap(
            shopSnap.docs.first.data()
              ..['id'] = shopSnap.docs.first.id,
          );
          dbStock = (product.stockQuantity).toInt();
        }
      }

      // Look for an open PO containing this barcode
      if (product != null) {
        final poSnap = await _db
            .collection('shops')
            .doc(shopId)
            .collection('purchase_orders')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        for (final doc in poSnap.docs) {
          final po = PurchaseOrder.fromMap(doc.data()..['id'] = doc.id);
          for (final item in po.items) {
            if (item.barcode == barcode || item.productId == product.id) {
              openPoLine = PurchaseOrderLine(
                poId: po.id,
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unit: item.unit,
                supplier: po.distributorName,
              );
              break;
            }
          }
          if (openPoLine != null) break;
        }
      }
    } catch (_) {}

    return ProductScanResult(
      barcode: barcode,
      product: product,
      dbStock: dbStock,
      openPoLine: openPoLine,
      // Recommended receive quantity: PO line qty, else 1
      suggestedQuantity: openPoLine?.quantity ?? 1,
    );
  }

  // ── 2. Order packing — verify one scanned item ─────────────────────────────

  /// Matches a scanned barcode against the current order's items.
  /// Returns which item was verified and whether the order is now complete.
  PackScanResult autoPack({
    required String barcode,
    required OrderModel order,
    required List<String> alreadyVerified, // productIds already scanned
  }) {
    // Build barcode→productId map from order items
    String? matchedProductId;
    String? matchedProductName;
    bool alreadyDone = false;

    for (final item in order.items) {
      // Match by product barcode if embedded, or name similarity
      final itemBarcode = item.barcode ?? '';
      if (itemBarcode == barcode ||
          itemBarcode.isNotEmpty &&
              barcode.isNotEmpty &&
              itemBarcode.toLowerCase() == barcode.toLowerCase()) {
        matchedProductId = item.productId;
        matchedProductName = item.productName;
        alreadyDone = alreadyVerified.contains(item.productId);
        break;
      }
    }

    final updatedVerified = List<String>.from(alreadyVerified);
    if (matchedProductId != null && !alreadyDone) {
      updatedVerified.add(matchedProductId);
    }

    final isOrderComplete =
        updatedVerified.length == order.items.length;

    // Next unverified item (to auto-highlight in UI)
    OrderItem? nextItem;
    if (!isOrderComplete) {
      for (final item in order.items) {
        if (!updatedVerified.contains(item.productId)) {
          nextItem = item;
          break;
        }
      }
    }

    return PackScanResult(
      barcode: barcode,
      matchedProductId: matchedProductId,
      matchedProductName: matchedProductName,
      wasAlreadyVerified: alreadyDone,
      notFound: matchedProductId == null,
      updatedVerifiedList: updatedVerified,
      isOrderComplete: isOrderComplete,
      nextItemToPack: nextItem,
    );
  }

  // ── 3. Proof of Delivery — GPS auto-confirm ─────────────────────────────────

  /// Checks if the rider's current GPS is close enough to the delivery address
  /// to auto-confirm delivery (within [thresholdMeters], default 150m).
  PodAutoConfirmResult autoCheckPodGps({
    required OrderModel order,
    required Position? riderPosition,
    double thresholdMeters = 150.0,
  }) {
    if (riderPosition == null) {
      return PodAutoConfirmResult(
        canAutoConfirm: false,
        distanceMeters: null,
        reason: 'GPS not available',
      );
    }

    final addr = order.deliveryAddress;
    final lat = addr.latitude;
    final lng = addr.longitude;

    if (lat == null || lng == null || lat == 0 || lng == 0) {
      return PodAutoConfirmResult(
        canAutoConfirm: false,
        distanceMeters: null,
        reason: 'Delivery address has no GPS coordinates',
      );
    }

    final distance = _haversineDistance(
      riderPosition.latitude,
      riderPosition.longitude,
      lat.toDouble(),
      lng.toDouble(),
    );

    return PodAutoConfirmResult(
      canAutoConfirm: distance <= thresholdMeters,
      distanceMeters: distance,
      reason: distance <= thresholdMeters
          ? 'Within ${distance.toStringAsFixed(0)}m — auto-confirming'
          : '${distance.toStringAsFixed(0)}m from address (>${thresholdMeters.toStringAsFixed(0)}m)',
    );
  }

  // ── 4. Dispatch — verify packed status ─────────────────────────────────────

  /// Loads an order and confirms it's in "packed" or "ready_to_dispatch" state.
  Future<DispatchReadyResult> autoCheckDispatch({
    required String orderId,
    required String shopId,
  }) async {
    try {
      final snap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!snap.exists) {
        return DispatchReadyResult(
          orderId: orderId,
          isReady: false,
          reason: 'Order not found',
        );
      }

      final data = snap.data()!;
      final status = data['status'] as String? ?? '';
      final isPacked =
          status == 'packed' || status == 'ready_to_dispatch';

      return DispatchReadyResult(
        orderId: orderId,
        orderData: data,
        isReady: isPacked,
        currentStatus: status,
        reason: isPacked
            ? 'Ready to dispatch'
            : 'Cannot dispatch — status is "$status"',
      );
    } catch (e) {
      return DispatchReadyResult(
        orderId: orderId,
        isReady: false,
        reason: 'Error: $e',
      );
    }
  }

  // ── 5. Haptic + visual feedback helpers ─────────────────────────────────────

  /// Strong success pulse
  static Future<void> hapticSuccess() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Double error buzz
  static Future<void> hapticError() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Completion celebration
  static Future<void> hapticComplete() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in metres
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLam = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────────────────────

class ProductScanResult {
  final String barcode;
  final ProductModel? product;
  final int dbStock;
  final PurchaseOrderLine? openPoLine;
  final int suggestedQuantity;

  bool get found => product != null;

  const ProductScanResult({
    required this.barcode,
    required this.product,
    required this.dbStock,
    required this.openPoLine,
    required this.suggestedQuantity,
  });
}

class PurchaseOrderLine {
  final String poId;
  final String productId;
  final String? productName;
  final int quantity;
  final String? unit;
  final String? supplier;

  PurchaseOrderLine({
    required this.poId,
    required this.productId,
    this.productName,
    required this.quantity,
    this.unit,
    this.supplier,
  });
}

class PackScanResult {
  final String barcode;
  final String? matchedProductId;
  final String? matchedProductName;
  final bool wasAlreadyVerified;
  final bool notFound;
  final List<String> updatedVerifiedList;
  final bool isOrderComplete;
  final OrderItem? nextItemToPack;

  bool get success =>
      matchedProductId != null && !wasAlreadyVerified;

  const PackScanResult({
    required this.barcode,
    required this.matchedProductId,
    required this.matchedProductName,
    required this.wasAlreadyVerified,
    required this.notFound,
    required this.updatedVerifiedList,
    required this.isOrderComplete,
    required this.nextItemToPack,
  });
}

class PodAutoConfirmResult {
  final bool canAutoConfirm;
  final double? distanceMeters;
  final String reason;

  const PodAutoConfirmResult({
    required this.canAutoConfirm,
    required this.distanceMeters,
    required this.reason,
  });
}

class DispatchReadyResult {
  final String orderId;
  final Map<String, dynamic>? orderData;
  final bool isReady;
  final String? currentStatus;
  final String reason;

  const DispatchReadyResult({
    required this.orderId,
    this.orderData,
    required this.isReady,
    this.currentStatus,
    required this.reason,
  });
}
