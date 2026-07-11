import 'package:flutter_test/flutter_test.dart';

void main() {
  group('End-to-End Checkout Flow', () {
    late CheckoutFlowService checkoutService;
    late MockPaymentGateway paymentGateway;
    late MockInventoryService inventoryService;
    late MockOrderService orderService;

    setUp(() {
      paymentGateway = MockPaymentGateway();
      inventoryService = MockInventoryService();
      orderService = MockOrderService();
      checkoutService = CheckoutFlowService(
        paymentGateway: paymentGateway,
        inventoryService: inventoryService,
        orderService: orderService,
      );
    });

    group('Happy Path - Complete Checkout', () {
      test('customer should complete checkout successfully', () async {
        // Step 1: Add items to cart
        await checkoutService.addToCart('prod_1', quantity: 2);
        await checkoutService.addToCart('prod_2', quantity: 1);

        expect(checkoutService.cartItemCount, 3);

        // Step 2: Apply promo code
        final promoApplied = checkoutService.applyPromo('SAVE10');
        expect(promoApplied, isTrue);

        // Step 3: Select delivery address
        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        expect(checkoutService.selectedAddress, address);

        // Step 4: Select payment method
        checkoutService.setPaymentMethod('razorpay');

        // Step 5: Place order
        final placeOrderResult = await checkoutService.placeOrder();

        expect(placeOrderResult['status'], 'success');
        expect(placeOrderResult['orderId'], isNotNull);

        // Step 6: Process payment
        const paymentResult = {
          'status': 'success',
          'paymentId': 'pay_123',
          'signature': 'valid_sig',
        };

        final paymentVerified = await checkoutService.verifyPayment(
          paymentId: paymentResult['paymentId']!,
          signature: paymentResult['signature']!,
        );

        expect(paymentVerified, isTrue);

        // Step 7: Order should be confirmed
        final orderStatus = await checkoutService.getOrderStatus(placeOrderResult['orderId']);

        expect(orderStatus, 'confirmed');

        // Step 8: Inventory should be updated
        expect(inventoryService.soldCount, greaterThan(0));

        // Step 9: Cart should be cleared
        expect(checkoutService.cartItemCount, 0);
      });

      test('should generate order confirmation with details', () async {
        await checkoutService.addToCart('prod_1', quantity: 2);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final orderResult = await checkoutService.placeOrder();
        final orderId = orderResult['orderId'];

        await checkoutService.verifyPayment(paymentId: 'pay_123', signature: 'sig_123');

        final confirmation = await checkoutService.getOrderConfirmation(orderId);

        expect(confirmation['orderId'], isNotNull);
        expect(confirmation['orderNumber'], isNotNull);
        expect(confirmation['totalAmount'], isA<double>());
        expect(confirmation['estimatedDeliveryTime'], isNotNull);
        expect(confirmation['deliveryAddress'], isNotNull);
        expect(confirmation['items'], isNotEmpty);
      });

      test('should send order confirmation notification', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('cod');

        final orderResult = await checkoutService.placeOrder();

        // For COD, order is immediately confirmed
        expect(orderResult['status'], 'success');

        // Notification should be sent
        final notificationSent = await checkoutService.hasNotificationBeenSent(
          orderResult['orderId'],
          'order_confirmed',
        );

        expect(notificationSent, isTrue);
      });
    });

    group('Payment Flow - Razorpay', () {
      test('should create Razorpay order on backend', () async {
        await checkoutService.addToCart('prod_1', quantity: 2);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final result = await checkoutService.createPaymentOrder();

        expect(result['razorpayOrderId'], isNotNull);
        expect(result['amount'], isA<int>()); // in paise
        expect(result['currency'], 'INR');
      });

      test('should verify Razorpay signature server-side', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        const validSignature = 'valid_razorpay_signature';
        const invalidSignature = 'invalid_signature';

        final validResult = await checkoutService.verifyPayment(
          paymentId: 'pay_123',
          signature: validSignature,
        );

        final invalidResult = await checkoutService.verifyPayment(
          paymentId: 'pay_456',
          signature: invalidSignature,
        );

        expect(validResult, isTrue);
        expect(invalidResult, isFalse);
      });

      test('should handle payment timeout gracefully', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        // Simulate payment timeout
        paymentGateway.simulateTimeout = true;

        final result = await checkoutService.processPayment(timeout: Duration(seconds: 5));

        expect(result['status'], 'timeout');
        expect(result['error'], contains('timeout'));

        paymentGateway.simulateTimeout = false;
      });
    });

    group('Error Handling - Payment Failures', () {
      test('should handle payment failure and release inventory', () async {
        await checkoutService.addToCart('prod_1', quantity: 5);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final orderResult = await checkoutService.placeOrder();
        final orderId = orderResult['orderId'];

        // Simulate payment failure
        final paymentResult = await checkoutService.processPayment();
        expect(paymentResult['status'], 'failed');

        // Inventory should be released
        final reservedStock = await inventoryService.getReservedStock('prod_1');
        expect(reservedStock, 0);

        // Order should be cancelled
        final orderStatus = await checkoutService.getOrderStatus(orderId);
        expect(orderStatus, 'cancelled');
      });

      test('should handle invalid card error', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        paymentGateway.simulateInvalidCard = true;

        final result = await checkoutService.processPayment();

        expect(result['status'], 'failed');
        expect(result['error'], contains('card'));

        paymentGateway.simulateInvalidCard = false;
      });

      test('should allow retry after payment failure', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        // First attempt fails
        paymentGateway.failNextPayment = true;
        var result = await checkoutService.processPayment();
        expect(result['status'], 'failed');

        // Retry succeeds
        paymentGateway.failNextPayment = false;
        result = await checkoutService.processPayment();
        expect(result['status'], 'success');
      });
    });

    group('Address Selection', () {
      test('should validate address is within delivery zone', () async {
        const invalidAddress = AddressModel(
          id: 'addr_invalid',
          street: '999 Far Away',
          city: 'Bangalore',
          postalCode: '560001',
        );

        final isValid = await checkoutService.validateAddress(invalidAddress);
        expect(isValid, isFalse);
      });

      test('should reject address outside delivery radius', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const farAddress = AddressModel(
          id: 'addr_far',
          street: 'Very Far',
          city: 'Delhi',
          postalCode: '110001',
        );

        expect(
          () => checkoutService.selectDeliveryAddress(farAddress),
          throwsException,
        );
      });

      test('should accept address within delivery zone', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const validAddress = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(validAddress);
        expect(checkoutService.selectedAddress, validAddress);
      });
    });

    group('Inventory Management During Checkout', () {
      test('should reserve inventory when order is placed', () async {
        await checkoutService.addToCart('prod_1', quantity: 5);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final orderResult = await checkoutService.placeOrder();

        // Inventory should be reserved
        final reserved = await inventoryService.getReservedStock('prod_1');
        expect(reserved, 5);
      });

      test('should confirm inventory sale after payment', () async {
        await checkoutService.addToCart('prod_1', quantity: 3);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final orderResult = await checkoutService.placeOrder();

        // Initially reserved
        var reserved = await inventoryService.getReservedStock('prod_1');
        expect(reserved, 3);

        // After payment verification
        await checkoutService.verifyPayment(paymentId: 'pay_123', signature: 'sig_123');

        // Should move to sold
        final sold = await inventoryService.getSoldStock('prod_1');
        expect(sold, greaterThanOrEqualTo(3));

        reserved = await inventoryService.getReservedStock('prod_1');
        expect(reserved, 0);
      });

      test('should release inventory if stock becomes unavailable', () async {
        await checkoutService.addToCart('prod_1', quantity: 10);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        // Simulate stock becoming unavailable
        inventoryService.simulateStockUnavailable('prod_1');

        final orderResult = await checkoutService.placeOrder();

        expect(orderResult['status'], 'failed');
        expect(orderResult['error'], contains('stock'));
      });
    });

    group('Cart Persistence', () {
      test('should save cart locally', () async {
        await checkoutService.addToCart('prod_1', quantity: 2);
        await checkoutService.addToCart('prod_2', quantity: 1);

        final savedCart = await checkoutService.getSavedCart();

        expect(savedCart.length, 2);
        expect(savedCart[0]['productId'], 'prod_1');
      });

      test('should clear cart after successful checkout', () async {
        await checkoutService.addToCart('prod_1', quantity: 2);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('cod');

        final orderResult = await checkoutService.placeOrder();

        // For COD, order is immediately confirmed
        expect(orderResult['status'], 'success');

        // Cart should be cleared
        final savedCart = await checkoutService.getSavedCart();
        expect(savedCart, isEmpty);
      });
    });

    group('Multiple Item Types', () {
      test('should handle checkout with various product types', () async {
        // Vegetables
        await checkoutService.addToCart('prod_vegetable_1', quantity: 2);

        // Dairy
        await checkoutService.addToCart('prod_dairy_1', quantity: 1);

        // Pantry
        await checkoutService.addToCart('prod_pantry_1', quantity: 5);

        expect(checkoutService.cartItemCount, 8);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('cod');

        final orderResult = await checkoutService.placeOrder();

        expect(orderResult['status'], 'success');

        // All items should be in order
        final orderItems = await checkoutService.getOrderItems(orderResult['orderId']);
        expect(orderItems.length, 3);
      });
    });

    group('Special Cases', () {
      test('should handle single item order', () async {
        await checkoutService.addToCart('prod_1', quantity: 1);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('cod');

        final orderResult = await checkoutService.placeOrder();

        expect(orderResult['status'], 'success');
      });

      test('should handle bulk order', () async {
        await checkoutService.addToCart('prod_1', quantity: 100);

        const address = AddressModel(
          id: 'addr_1',
          street: '123 Main St',
          city: 'Mumbai',
          postalCode: '400001',
        );

        await checkoutService.selectDeliveryAddress(address);
        checkoutService.setPaymentMethod('razorpay');

        final orderResult = await checkoutService.placeOrder();

        expect(orderResult['status'], 'success');
      });
    });
  });
}

class AddressModel {
  final String id;
  final String street;
  final String city;
  final String postalCode;

  const AddressModel({
    required this.id,
    required this.street,
    required this.city,
    required this.postalCode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          street == other.street &&
          city == other.city &&
          postalCode == other.postalCode;

  @override
  int get hashCode => Object.hash(id, street, city, postalCode);
}

class CheckoutFlowService {
  final MockPaymentGateway paymentGateway;
  final MockInventoryService inventoryService;
  final MockOrderService orderService;

  CheckoutFlowService({
    required this.paymentGateway,
    required this.inventoryService,
    required this.orderService,
  });

  int get cartItemCount => 0;
  AddressModel? get selectedAddress => null;

  Future<void> addToCart(String productId, {required int quantity}) async {}
  bool applyPromo(String code) => false;
  Future<void> selectDeliveryAddress(AddressModel address) async {}
  void setPaymentMethod(String method) {}
  Future<Map<String, dynamic>> placeOrder() async => {};
  Future<bool> verifyPayment({required String paymentId, required String signature}) async => false;
  Future<String> getOrderStatus(String orderId) async => '';
  Future<Map<String, dynamic>> getOrderConfirmation(String orderId) async => {};
  Future<bool> hasNotificationBeenSent(String orderId, String type) async => false;
  Future<Map<String, dynamic>> createPaymentOrder() async => {};
  Future<Map<String, dynamic>> processPayment({Duration? timeout}) async => {};
  Future<bool> validateAddress(AddressModel address) async => false;
  Future<List<Map<String, dynamic>>> getSavedCart() async => [];
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async => [];
}

class MockPaymentGateway {
  bool simulateTimeout = false;
  bool simulateInvalidCard = false;
  bool failNextPayment = false;
}

class MockInventoryService {
  int soldCount = 0;
  Future<int> getReservedStock(String productId) async => 0;
  Future<int> getSoldStock(String productId) async => 0;
  void simulateStockUnavailable(String productId) {}
}

class MockOrderService {
  Future<String> createOrder(Map<String, dynamic> data) async => 'order_123';
}
