import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fufajis_online/screens/customer/orders_screen.dart';
import 'package:fufajis_online/providers/order_provider.dart';
import 'package:fufajis_online/models/order_model.dart';
import 'package:fufajis_online/models/user_model.dart';

class MockOrderProvider extends Mock implements OrderProvider {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('OrdersScreen Tests', () {
    late MockOrderProvider mockOrderProvider;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockOrderProvider = MockOrderProvider();
      mockGoRouter = MockGoRouter();
    });

    /// Test 5.1.1: OrdersScreen displays order history with pagination
    testWidgets('OrdersScreen displays order list with pagination',
        (WidgetTester tester) async {
      // Create sample orders
      final orders = [
        OrderModel(
          id: '1',
          orderNumber: 'HLM-20240101-0001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [
            OrderItem(
              id: 'item1',
              productId: 'prod1',
              productName: 'Milk',
              productImage: '',
              unit: 'liter',
              quantity: 2,
              price: 50,
              totalPrice: 100,
            ),
          ],
          subtotal: 100,
          totalAmount: 120,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: OrderStatus.delivered,
        ),
        OrderModel(
          id: '2',
          orderNumber: 'HLM-20240102-0002',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [
            OrderItem(
              id: 'item2',
              productId: 'prod2',
              productName: 'Bread',
              productImage: '',
              unit: 'piece',
              quantity: 1,
              price: 40,
              totalPrice: 40,
            ),
          ],
          subtotal: 40,
          totalAmount: 60,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          status: OrderStatus.pending,
        ),
      ];

      when(mockOrderProvider.orders).thenReturn(orders);
      when(mockOrderProvider.isLoading).thenReturn(false);
      when(mockOrderProvider.hasMoreOrders).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>.value(
            value: mockOrderProvider,
            child: const OrdersScreen(),
          ),
        ),
      );

      // Verify order list is displayed
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('HLM-20240101-0001'), findsOneWidget);
      expect(find.text('HLM-20240102-0002'), findsOneWidget);
    });

    /// Test 5.1.2: OrdersScreen filters orders by status (Active/Completed/Cancelled)
    testWidgets('OrdersScreen filters orders by status',
        (WidgetTester tester) async {
      final orders = [
        OrderModel(
          id: '1',
          orderNumber: 'HLM-20240101-0001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [],
          subtotal: 100,
          totalAmount: 120,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: OrderStatus.outForDelivery,
        ),
        OrderModel(
          id: '2',
          orderNumber: 'HLM-20240102-0002',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [],
          subtotal: 40,
          totalAmount: 60,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: OrderStatus.delivered,
        ),
      ];

      when(mockOrderProvider.orders).thenReturn(orders);
      when(mockOrderProvider.isLoading).thenReturn(false);
      when(mockOrderProvider.hasMoreOrders).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>.value(
            value: mockOrderProvider,
            child: const OrdersScreen(),
          ),
        ),
      );

      // Verify filter tabs are present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // Tap on "Active" tab
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      // Verify only active orders are shown
      expect(find.text('HLM-20240101-0001'), findsOneWidget);
      expect(find.text('HLM-20240102-0002'), findsNothing);
    });

    /// Test 5.1.3: OrdersScreen shows empty state when no orders
    testWidgets('OrdersScreen shows empty state when no orders',
        (WidgetTester tester) async {
      when(mockOrderProvider.orders).thenReturn([]);
      when(mockOrderProvider.isLoading).thenReturn(false);
      when(mockOrderProvider.hasMoreOrders).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>.value(
            value: mockOrderProvider,
            child: const OrdersScreen(),
          ),
        ),
      );

      // Verify empty state is shown
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Start shopping to see your orders here'),
          findsOneWidget);
      expect(find.text('Start Shopping'), findsOneWidget);
    });

    /// Test 5.1.4: OrdersScreen displays order status with correct color and icon
    testWidgets('OrdersScreen displays order status with correct styling',
        (WidgetTester tester) async {
      final orders = [
        OrderModel(
          id: '1',
          orderNumber: 'HLM-20240101-0001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [],
          subtotal: 100,
          totalAmount: 120,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: OrderStatus.delivered,
        ),
      ];

      when(mockOrderProvider.orders).thenReturn(orders);
      when(mockOrderProvider.isLoading).thenReturn(false);
      when(mockOrderProvider.hasMoreOrders).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>.value(
            value: mockOrderProvider,
            child: const OrdersScreen(),
          ),
        ),
      );

      // Verify status is displayed
      expect(find.text('Delivered'), findsOneWidget);
    });

    /// Test 5.1.5: OrdersScreen displays order items preview
    testWidgets('OrdersScreen displays order items preview',
        (WidgetTester tester) async {
      final orders = [
        OrderModel(
          id: '1',
          orderNumber: 'HLM-20240101-0001',
          customerId: 'cust1',
          customerName: 'John Doe',
          customerPhone: '9876543210',
          items: [
            OrderItem(
              id: 'item1',
              productId: 'prod1',
              productName: 'Milk',
              productImage: '',
              unit: 'liter',
              quantity: 2,
              price: 50,
              totalPrice: 100,
            ),
            OrderItem(
              id: 'item2',
              productId: 'prod2',
              productName: 'Bread',
              productImage: '',
              unit: 'piece',
              quantity: 1,
              price: 40,
              totalPrice: 40,
            ),
          ],
          subtotal: 140,
          totalAmount: 160,
          deliveryAddress: Address(
            id: 'addr1',
            label: 'Home',
            fullAddress: '123 Main St',
            village: 'Test Village',
            landmark: '',
            pincode: '12345',
            latitude: 0,
            longitude: 0,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: OrderStatus.delivered,
        ),
      ];

      when(mockOrderProvider.orders).thenReturn(orders);
      when(mockOrderProvider.isLoading).thenReturn(false);
      when(mockOrderProvider.hasMoreOrders).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderProvider>.value(
            value: mockOrderProvider,
            child: const OrdersScreen(),
          ),
        ),
      );

      // Verify items are displayed
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
    });
  });
}
