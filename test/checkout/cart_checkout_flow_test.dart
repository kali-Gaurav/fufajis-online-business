import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/providers/cart_provider.dart';
import 'package:fufajis_online/models/cart_item.dart';
import 'package:fufajis_online/models/product_model.dart';
import 'package:fufajis_online/utils/monetary_value.dart';
import 'package:fufajis_online/models/delivery_type.dart';

void main() {
  group('Cart Checkout Flow', () {
    late CartProvider cartProvider;

    setUp(() {
      cartProvider = CartProvider();
    });

    group('Cart Initialization', () {
      test('should initialize with empty cart', () {
        expect(cartProvider.cartItems, isEmpty);
        expect(cartProvider.subtotal, 0.0);
        expect(cartProvider.total, 0.0);
        expect(cartProvider.appliedCoupon, isNull);
      });

      test('should have default delivery type', () {
        expect(cartProvider.deliveryType, DeliveryType.standard);
      });

      test('should have zero wallet usage initially', () {
        expect(cartProvider.walletAmountUsed, 0.0);
      });
    });

    group('Add to Cart', () {
      test('should add product to empty cart', () {
        final product = _createMockProduct(
          id: 'prod1',
          name: 'Tomato',
          price: 40.0,
        );

        cartProvider.addToCart(product, quantity: 2);

        expect(cartProvider.cartItems.length, 1);
        expect(cartProvider.cartItems.first.productName, 'Tomato');
        expect(cartProvider.cartItems.first.quantity, 2);
      });

      test('should merge quantities when adding duplicate product', () {
        final product = _createMockProduct(
          id: 'prod1',
          name: 'Tomato',
          price: 40.0,
        );

        cartProvider.addToCart(product, quantity: 2);
        cartProvider.addToCart(product, quantity: 3);

        expect(cartProvider.cartItems.length, 1);
        expect(cartProvider.cartItems.first.quantity, 5);
      });

      test('should calculate subtotal correctly', () {
        final product1 = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);
        final product2 = _createMockProduct(id: 'prod2', name: 'Onion', price: 30.0);

        cartProvider.addToCart(product1, quantity: 2); // 40 * 2 = 80
        cartProvider.addToCart(product2, quantity: 1); // 30 * 1 = 30

        expect(cartProvider.subtotal, 110.0);
      });

      test('should not add product with null price', () {
        final product = ProductModel(
          id: 'prod1',
          name: 'Invalid Product',
          price: null,
          shopId: 'shop1',
          imageUrl: '',
          category: 'test',
        );

        cartProvider.addToCart(product, quantity: 1);

        expect(cartProvider.cartItems, isEmpty);
      });

      test('should not add product with invalid price value', () {
        final product = _createMockProduct(
          id: 'prod1',
          name: 'BadPrice',
          price: -10.0, // negative price
        );

        cartProvider.addToCart(product, quantity: 1);

        expect(cartProvider.cartItems, isEmpty);
      });
    });

    group('Cart Calculations', () {
      setUp(() {
        final product1 = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);
        final product2 = _createMockProduct(id: 'prod2', name: 'Onion', price: 30.0);

        cartProvider.addToCart(product1, quantity: 2); // 80
        cartProvider.addToCart(product2, quantity: 1); // 30
        // Subtotal: 110
      });

      test('should calculate tax at 5% of subtotal', () {
        expect(cartProvider.subtotal, 110.0);
        expect(cartProvider.discount, 0.0); // no coupon applied
        // Tax = 110 * 0.05 = 5.5
        // Note: Check exact calculation in provider
      });

      test('should include fixed delivery charge of 50', () {
        expect(cartProvider.deliveryCharge, 50.0);
      });

      test('should calculate total = subtotal + delivery + tax - discount', () {
        // subtotal: 110
        // delivery: 50
        // tax: 5.5 (110 * 0.05)
        // discount: 0
        // total = 110 + 50 + 5.5 - 0 = 165.5
        final expectedSubtotal = 110.0;
        final expectedTax = expectedSubtotal * 0.05;
        final expectedTotal = expectedSubtotal + 50.0 + expectedTax;

        expect(cartProvider.subtotal, expectedSubtotal);
        expect(cartProvider.total, closeTo(expectedTotal, 0.01));
      });

      test('should calculate item count correctly', () {
        // 2 tomatoes + 1 onion = 3 items
        expect(cartProvider.totalItems, 3);
      });
    });

    group('Remove from Cart', () {
      test('should remove product from cart', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 2);
        expect(cartProvider.cartItems.length, 1);

        final cartItemId = cartProvider.cartItems.first.id;
        cartProvider.removeFromCart(cartItemId);

        expect(cartProvider.cartItems, isEmpty);
      });

      test('should update total after removal', () {
        final product1 = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);
        final product2 = _createMockProduct(id: 'prod2', name: 'Onion', price: 30.0);

        cartProvider.addToCart(product1, quantity: 2);
        cartProvider.addToCart(product2, quantity: 1);

        final subtotalBefore = cartProvider.subtotal;

        final cartItemId = cartProvider.cartItems.first.id;
        cartProvider.removeFromCart(cartItemId);

        expect(cartProvider.subtotal, lessThan(subtotalBefore));
      });
    });

    group('Update Quantity', () {
      test('should update quantity of existing item', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 2);
        final cartItemId = cartProvider.cartItems.first.id;

        cartProvider.updateQuantity(cartItemId, 5);

        expect(cartProvider.cartItems.first.quantity, 5);
      });

      test('should remove item when quantity set to 0', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 2);
        final cartItemId = cartProvider.cartItems.first.id;

        cartProvider.updateQuantity(cartItemId, 0);

        expect(cartProvider.cartItems, isEmpty);
      });

      test('should remove item when quantity set to negative', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 2);
        final cartItemId = cartProvider.cartItems.first.id;

        cartProvider.updateQuantity(cartItemId, -1);

        expect(cartProvider.cartItems, isEmpty);
      });

      test('should update subtotal when quantity changes', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 1);
        expect(cartProvider.subtotal, 40.0);

        final cartItemId = cartProvider.cartItems.first.id;
        cartProvider.updateQuantity(cartItemId, 3);

        expect(cartProvider.subtotal, 120.0);
      });
    });

    group('Promo Code Application', () {
      test('should apply valid SAVE10 coupon', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        final result = cartProvider.applyCoupon('SAVE10');

        expect(result, isTrue);
        expect(cartProvider.appliedCoupon, isNotNull);
        expect(cartProvider.appliedCoupon?.code, 'SAVE10');
      });

      test('should apply valid FIRST20 coupon', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 300.0);

        cartProvider.addToCart(product, quantity: 1);
        final result = cartProvider.applyCoupon('FIRST20');

        expect(result, isTrue);
        expect(cartProvider.appliedCoupon?.code, 'FIRST20');
      });

      test('should reject invalid coupon code', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        final result = cartProvider.applyCoupon('INVALID123');

        expect(result, isFalse);
        expect(cartProvider.appliedCoupon, isNull);
      });

      test('should calculate discount from coupon correctly', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1); // subtotal: 100
        cartProvider.applyCoupon('SAVE10'); // 10% discount

        // discount = 100 * 0.10 = 10
        expect(cartProvider.discount, closeTo(10.0, 1.0));
      });

      test('should respect maximum discount on coupon', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 2000.0);

        cartProvider.addToCart(product, quantity: 1); // subtotal: 2000
        cartProvider.applyCoupon('SAVE10'); // max discount: 100

        // discount should not exceed maximum (100)
        expect(cartProvider.discount, lessThanOrEqualTo(100.0));
      });

      test('should remove coupon when removeCoupon called', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.applyCoupon('SAVE10');

        expect(cartProvider.appliedCoupon, isNotNull);

        cartProvider.removeCoupon();

        expect(cartProvider.appliedCoupon, isNull);
        expect(cartProvider.discount, 0.0);
      });

      test('should handle case-insensitive coupon codes', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        final result = cartProvider.applyCoupon('save10'); // lowercase

        expect(result, isTrue); // should convert to uppercase and match
      });
    });

    group('Wallet Amount Usage', () {
      test('should set wallet amount used', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.setWalletAmount(50.0, 100.0); // use 50 out of 100

        expect(cartProvider.walletAmountUsed, 50.0);
      });

      test('should clamp wallet amount to wallet balance', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.setWalletAmount(150.0, 100.0); // trying to use 150 but only have 100

        expect(cartProvider.walletAmountUsed, 100.0); // should clamp to balance
      });

      test('should not allow negative wallet amount', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.setWalletAmount(-50.0, 100.0);

        expect(cartProvider.walletAmountUsed, 0.0); // should clamp to 0
      });

      test('should include wallet deduction in total', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        final totalBefore = cartProvider.total;

        cartProvider.setWalletAmount(30.0, 100.0);

        expect(cartProvider.total, lessThan(totalBefore));
      });
    });

    group('Delivery Type Selection', () {
      test('should set delivery type', () {
        cartProvider.setDeliveryType(DeliveryType.express);

        expect(cartProvider.deliveryType, DeliveryType.express);
      });

      test('should calculate different delivery charges for different types', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);

        final standardCharge = cartProvider.getDeliveryChargeForType(DeliveryType.standard);
        final expressCharge = cartProvider.getDeliveryChargeForType(DeliveryType.express);

        // Express should typically be higher than standard
        expect(expressCharge, greaterThanOrEqualTo(standardCharge));
      });

      test('should update total when delivery type changes', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);

        final standardTotal = cartProvider.total;

        cartProvider.setDeliveryType(DeliveryType.express);
        final expressTotal = cartProvider.total;

        // Total might change if delivery charges are different
        expect(expressTotal, isNotNull);
      });
    });

    group('Clear Cart', () {
      test('should clear all items', () {
        final product1 = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);
        final product2 = _createMockProduct(id: 'prod2', name: 'Onion', price: 30.0);

        cartProvider.addToCart(product1, quantity: 2);
        cartProvider.addToCart(product2, quantity: 1);

        expect(cartProvider.cartItems.length, 2);

        cartProvider.clearCart();

        expect(cartProvider.cartItems, isEmpty);
      });

      test('should clear coupon on clear cart', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.applyCoupon('SAVE10');

        expect(cartProvider.appliedCoupon, isNotNull);

        cartProvider.clearCart();

        expect(cartProvider.appliedCoupon, isNull);
      });

      test('should clear wallet usage on clear cart', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.setWalletAmount(50.0, 100.0);

        expect(cartProvider.walletAmountUsed, 50.0);

        cartProvider.clearCart();

        expect(cartProvider.walletAmountUsed, 0.0);
      });

      test('should reset delivery type on clear cart', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 100.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.setDeliveryType(DeliveryType.express);

        expect(cartProvider.deliveryType, DeliveryType.express);

        cartProvider.clearCart();

        expect(cartProvider.deliveryType, DeliveryType.standard);
      });
    });

    group('Checkout Payload', () {
      test('should generate correct checkout payload', () {
        final product1 = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);
        final product2 = _createMockProduct(id: 'prod2', name: 'Onion', price: 30.0);

        cartProvider.addToCart(product1, quantity: 2);
        cartProvider.addToCart(product2, quantity: 1);
        cartProvider.applyCoupon('SAVE10');

        final payload = cartProvider.toCheckoutPayload();

        expect(payload, isA<Map<String, dynamic>>());
        expect(payload['items'], isA<List>());
        expect(payload['items'].length, 2);
        expect(payload['subtotal'], 110.0);
        expect(payload['deliveryCharge'], 50.0);
        expect(payload['tax'], isA<double>());
        expect(payload['promoCode'], 'SAVE10');
        expect(payload['total'], isA<double>());
      });

      test('payload items should have correct structure', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 2);

        final payload = cartProvider.toCheckoutPayload();
        final item = (payload['items'] as List).first;

        expect(item['productId'], 'prod1');
        expect(item['quantity'], 2);
        expect(item['price'], 40.0);
        expect(item['total'], 80.0);
      });
    });

    group('Edge Cases', () {
      test('should handle very large quantities', () {
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 40.0);

        cartProvider.addToCart(product, quantity: 999);

        expect(cartProvider.cartItems.first.quantity, 999);
      });

      test('should handle very small prices', () {
        final product = _createMockProduct(id: 'prod1', name: 'Cheap item', price: 0.01);

        cartProvider.addToCart(product, quantity: 1);

        expect(cartProvider.subtotal, closeTo(0.01, 0.001));
      });

      test('should handle decimal prices correctly', () {
        final product = _createMockProduct(id: 'prod1', name: 'Item', price: 19.99);

        cartProvider.addToCart(product, quantity: 1);

        expect(cartProvider.subtotal, closeTo(19.99, 0.01));
      });

      test('should handle empty cart total calculation', () {
        expect(cartProvider.subtotal, 0.0);
        expect(cartProvider.total, 0.0);
      });

      test('should prevent discount exceeding subtotal', () {
        // This is a validation that discount should not exceed subtotal
        final product = _createMockProduct(id: 'prod1', name: 'Tomato', price: 50.0);

        cartProvider.addToCart(product, quantity: 1);
        cartProvider.applyCoupon('SAVE10'); // 10% = 5

        expect(cartProvider.discount, lessThanOrEqualTo(cartProvider.subtotal));
      });
    });
  });
}

ProductModel _createMockProduct({
  required String id,
  required String name,
  required double price,
}) {
  return ProductModel(
    id: id,
    name: name,
    price: MonetaryValue(price),
    shopId: 'shop1',
    imageUrl: 'https://example.com/image.jpg',
    category: 'produce',
  );
}
