import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/cart_item.dart';
import 'diagnostics_service.dart';

class CartValidationException implements Exception {
  final String message;
  final CartItem? corruptedItem;

  CartValidationException(this.message, {this.corruptedItem});

  @override
  String toString() => 'CartValidationException: $message';
}

class CartValidator {
  static const String _module = 'CartValidator';

  /// Check if a single cart item is valid
  static bool validateItem(CartItem item) {
    try {
      final price = item.price.toDouble();
      final qty = item.quantity;

      // Must have positive price and quantity
      if (price <= 0) {
        DiagnosticsService().log(
          _module,
          '🚨 Invalid price: $price for product ${item.productId}',
          level: AppLogSeverity.error,
        );
        return false;
      }

      if (qty <= 0) {
        DiagnosticsService().log(
          _module,
          '🚨 Invalid quantity: $qty for product ${item.productId}',
          level: AppLogSeverity.error,
        );
        return false;
      }

      // Must have product ID
      if (item.productId.isEmpty) {
        DiagnosticsService().log(
          _module,
          '🚨 Missing product ID',
          level: AppLogSeverity.error,
        );
        return false;
      }

      return true;
    } catch (e) {
      DiagnosticsService().log(
        _module,
        '🚨 Validation error: $e',
        level: AppLogSeverity.error,
        error: e,
      );
      return false;
    }
  }

  /// Validate and throw if invalid
  static void validateItemOrThrow(CartItem item) {
    if (!validateItem(item)) {
      throw CartValidationException(
        'Cart item validation failed for ${item.productId}',
        corruptedItem: item,
      );
    }
  }

  /// Compute hash for integrity checking
  static String computeHash(CartItem item) {
    final hashInput = '${item.productId}|${item.quantity}|${item.price.toDouble()}';
    return sha256.convert(utf8.encode(hashInput)).toString();
  }

  /// Verify item hasn't been corrupted since last save
  static bool verifyItemHash(CartItem item, String storedHash) {
    final currentHash = computeHash(item);

    if (currentHash != storedHash) {
      DiagnosticsService().log(
        _module,
        '🚨 HASH MISMATCH for ${item.productId}: stored=$storedHash, current=$currentHash',
        level: AppLogSeverity.error,
      );
      return false;
    }

    return true;
  }

  /// Validate entire cart
  static List<CartItem> validateAndFilterCart(List<CartItem> items) {
    final validItems = <CartItem>[];
    final corruptedItems = <CartItem>[];

    DiagnosticsService().log(
      _module,
      'Validating ${items.length} cart items...',
      level: AppLogSeverity.info,
    );

    for (final item in items) {
      if (validateItem(item)) {
        validItems.add(item);
        DiagnosticsService().log(
          _module,
          '✅ Valid: ${item.productId} (qty=${item.quantity}, price=${item.price.toDouble()})',
          level: AppLogSeverity.debug,
        );
      } else {
        corruptedItems.add(item);
        DiagnosticsService().logCartItem(item.toMap(), valid: false);
      }
    }

    if (corruptedItems.isNotEmpty) {
      DiagnosticsService().log(
        _module,
        '⚠️  Filtered out ${corruptedItems.length} corrupted items',
        level: AppLogSeverity.warning,
      );
    }

    DiagnosticsService().log(
      _module,
      '✅ Cart validation complete: ${validItems.length}/${items.length} valid',
      level: AppLogSeverity.info,
    );

    return validItems;
  }
}
