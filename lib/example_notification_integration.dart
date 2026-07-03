/// ============================================================================
///  FUFAJI NOTIFICATION SYSTEM - COMPLETE INTEGRATION EXAMPLE
///
///  This file demonstrates how all notification, chat, and invoice systems
///  work together in a real e-commerce order flow.
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'models/order_model.dart';
import 'models/user_model.dart';
import 'models/payment_method.dart';
import 'models/chat_conversation_model.dart';
import 'services/order_service.dart';
import 'services/chat_service.dart';
import 'services/chat_suggestions_service.dart';
import 'widgets/chat_with_suggestions.dart';
import 'utils/monetary_value.dart';
import 'constants/order_status.dart';

/// ════════════════════════════════════════════════════════════════════════
///  SCENARIO 1: Customer Places Order
/// ════════════════════════════════════════════════════════════════════════

Future<void> exampleOrderPlacement() async {
  final orderService = OrderService();

  // Create a sample order
  final order = OrderModel(
    id: 'order_20260609_001',
    customerId: 'customer_123',
    customerName: 'Rajesh Kumar',
    customerPhone: '+919876543210',
    orderNumber: 'A2B3',
    items: [
      OrderItem(
        id: 'item_1',
        productId: 'milk_001',
        productName: 'Amul Milk 1L',
        productImage: '',
        quantity: 2,
        unit: 'L',
        price: MonetaryValue(60),
        totalPrice: MonetaryValue(120),
      ),
      OrderItem(
        id: 'item_2',
        productId: 'atta_001',
        productName: 'Aashirvaad Atta 1kg',
        productImage: '',
        quantity: 1,
        unit: 'kg',
        price: MonetaryValue(45),
        totalPrice: MonetaryValue(45),
      ),
    ],
    subtotal: MonetaryValue(165),
    tax: MonetaryValue(20),
    deliveryCharge: MonetaryValue(30),
    discount: MonetaryValue(15),
    totalAmount: MonetaryValue(200),
    status: OrderStatus.pending,
    paymentMethod: PaymentMethod.upi,
    deliveryAddress: Address(
      id: 'addr_1',
      label: 'Home',
      fullAddress: '123 Main Street, Jaipur',
      village: 'Jaipur',
      landmark: 'Near Temple',
      pincode: '302001',
      latitude: 26.9124,
      longitude: 75.7873,
    ),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  debugPrint('[EXAMPLE] 📋 Placing order: ${order.orderNumber}');

  try {
    await orderService.createOrder(order);
    debugPrint('[EXAMPLE] ✅ Order placed successfully');
  } catch (e) {
    debugPrint('[EXAMPLE] ❌ Error placing order: $e');
  }
}

/// ════════════════════════════════════════════════════════════════════════
///  SCENARIO 2: Order Status Updates
/// ════════════════════════════════════════════════════════════════════════

Future<void> exampleOrderStatusUpdates() async {
  final orderService = OrderService();
  const orderId = 'order_20260609_001';

  try {
    await orderService.updateOrderStatus(orderId, 'confirmed');
    await orderService.updateOrderStatus(orderId, 'processing', employeeId: 'employee_456');
    await orderService.updateOrderStatus(orderId, 'packed');
    await orderService.updateOrderStatus(orderId, 'outForDelivery');
    await orderService.updateOrderStatus(orderId, 'delivered');
  } catch (e) {
    debugPrint('[EXAMPLE] ❌ Error: $e');
  }
}

/// ════════════════════════════════════════════════════════════════════════
///  SCENARIO 3: Customer Opens Chat with Smart Suggestions
/// ════════════════════════════════════════════════════════════════════════

class ExampleChatScreen extends StatefulWidget {
  final OrderModel order;
  const ExampleChatScreen({super.key, required this.order});

  @override
  State<ExampleChatScreen> createState() => _ExampleChatScreenState();
}

class _ExampleChatScreenState extends State<ExampleChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SupportChatService _chatService = SupportChatService();
  final ChatSuggestionsService _suggestionsService = ChatSuggestionsService();

  @override
  Widget build(BuildContext context) {
    return ChatWithSuggestions(
      order: widget.order,
      chatMessages: _buildChatMessages(),
      messageController: _messageController,
      onQuestionSelected: (question) {
        _handleQuestionSelection(question);
      },
      onSendMessage: (message) async {
        await _chatService.sendMessage(
          chatId: 'order_${widget.order.id}',
          senderId: widget.order.customerId,
          senderName: widget.order.customerName,
          senderRole: SenderRole.customer,
          text: message,
        );
      },
    );
  }

  void _handleQuestionSelection(String question) {
    final autoResponse = _suggestionsService.getChatbotResponse(question, widget.order);
    if (autoResponse != null) {
      _showAutoResponseDialog(question, autoResponse);
    }
  }

  void _showAutoResponseDialog(String question, String response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question),
        content: Text(response),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }

  Widget _buildChatMessages() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${widget.order.orderNumber}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSystemMessage('Welcome! 👋 We\'re here to help with your order.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Text(message),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await exampleOrderPlacement();
  await exampleOrderStatusUpdates();
}
