import '../models/order_model.dart';
import '../constants/order_status.dart';

/// Provides intelligent suggested questions/prompts in chat based on order state
/// Helps customers find quick answers without typing
class ChatSuggestionsService {
  static final ChatSuggestionsService _instance = ChatSuggestionsService._internal();
  factory ChatSuggestionsService() => _instance;
  ChatSuggestionsService._internal();

  /// Get suggested questions based on order status
  List<SuggestedQuestion> getSuggestedQuestions(OrderModel order) {
    final suggestions = <SuggestedQuestion>[];

    // Common questions for all statuses
    suggestions.add(
      SuggestedQuestion(
        id: 'track_order',
        question: '📍 Where is my order?',
        category: 'tracking',
        emoji: '📍',
        autoResponse: _getTrackingResponse(order),
      ),
    );

    suggestions.add(
      SuggestedQuestion(
        id: 'delivery_address',
        question: '📍 Will it deliver to my address?',
        category: 'delivery',
        emoji: '📍',
      ),
    );

    // Status-specific suggestions
    if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed) {
      suggestions.add(
        SuggestedQuestion(
          id: 'can_modify',
          question: '✏️ Can I modify my order?',
          category: 'order_management',
          emoji: '✏️',
          autoResponse: order.status == OrderStatus.pending
              ? 'Yes, you can modify your order before confirmation. Click "Edit Order" to make changes.'
              : 'Sorry, your order is already confirmed and cannot be modified. You can place a new order.',
        ),
      );

      suggestions.add(
        SuggestedQuestion(
          id: 'cancel_order',
          question: '❌ Can I cancel this order?',
          category: 'order_management',
          emoji: '❌',
          autoResponse: order.status == OrderStatus.pending
              ? 'Yes, you can cancel pending orders. Tap "Cancel Order" for a full refund.'
              : 'Your order is confirmed. To cancel, contact support and we\'ll process a refund.',
        ),
      );
    }

    if (order.status == OrderStatus.outForDelivery) {
      suggestions.add(
        SuggestedQuestion(
          id: 'delivery_time',
          question: '⏰ What time will it arrive?',
          category: 'delivery',
          emoji: '⏰',
          autoResponse: _getDeliveryTimeResponse(order),
        ),
      );

      suggestions.add(
        SuggestedQuestion(
          id: 'contact_rider',
          question: '📞 Can I contact the delivery person?',
          category: 'delivery',
          emoji: '📞',
          autoResponse: order.deliveryAgentPhone != null
              ? 'Yes! Your rider ${order.deliveryAgentName} can be reached at ${order.deliveryAgentPhone}'
              : 'The rider details will be updated once the package is picked up.',
        ),
      );
    }

    if (order.status == OrderStatus.delivered) {
      suggestions.add(
        SuggestedQuestion(
          id: 'download_invoice',
          question: '📄 Download invoice',
          category: 'invoice',
          emoji: '📄',
          autoResponse: 'Your invoice is attached below. Swipe up to download or share.',
        ),
      );

      suggestions.add(
        SuggestedQuestion(
          id: 'return_item',
          question: '↩️ I want to return/exchange',
          category: 'returns',
          emoji: '↩️',
          autoResponse:
              'We offer 7-day returns for unopened items. Click "Request Return" to start the process.',
        ),
      );

      suggestions.add(
        SuggestedQuestion(
          id: 'rate_experience',
          question: '⭐ Rate this order',
          category: 'feedback',
          emoji: '⭐',
          autoResponse: 'Thank you for your purchase! Your feedback helps us improve.',
        ),
      );
    }

    return suggestions;
  }

  /// Get quick-reply templates for employees
  List<QuickReplyTemplate> getEmployeeQuickReplies(OrderModel order) {
    return [
      QuickReplyTemplate(
        id: 'acknowledge',
        text: 'Thank you for reaching out! We\'re here to help. 😊',
        category: 'greeting',
      ),
      QuickReplyTemplate(
        id: 'processing',
        text: 'Your order is being processed. We\'ll send updates shortly.',
        category: 'status',
      ),
      QuickReplyTemplate(
        id: 'packed',
        text: 'Your order has been packed and will be dispatched soon.',
        category: 'status',
      ),
      QuickReplyTemplate(
        id: 'on_way',
        text: 'Your order is on the way! You\'ll receive it by ${_getEstimatedTime(order)}.',
        category: 'status',
      ),
      QuickReplyTemplate(
        id: 'delivery_issue',
        text:
            'We\'re sorry for the delivery issue. Let us know the problem and we\'ll resolve it immediately.',
        category: 'support',
      ),
      QuickReplyTemplate(
        id: 'refund_initiated',
        text:
            'Your refund has been initiated. The amount will be credited to your account within 3-5 business days.',
        category: 'refund',
      ),
      QuickReplyTemplate(
        id: 'quality_issue',
        text:
            'We apologize for the quality issue. Please send us photos and we\'ll arrange a replacement or refund.',
        category: 'support',
      ),
      QuickReplyTemplate(
        id: 'apology',
        text:
            'We sincerely apologize for the inconvenience. We\'re committed to making this right.',
        category: 'support',
      ),
    ];
  }

  /// Get contextual FAQs for displaying in chat
  List<FAQItem> getContextualFAQs(OrderModel order) {
    final faqs = <FAQItem>[];

    faqs.add(
      FAQItem(
        question: 'What\'s your return policy?',
        answer:
            'We offer 7-day returns for unopened, unused items. Return shipping is covered by us. To initiate a return, contact us within 7 days of delivery.',
        category: 'returns',
      ),
    );

    faqs.add(
      FAQItem(
        question: 'How long does delivery take?',
        answer:
            'We deliver within 24-48 hours in metro areas and 2-5 days in other locations. You\'ll receive real-time tracking updates.',
        category: 'delivery',
      ),
    );

    faqs.add(
      FAQItem(
        question: 'Can I track my order?',
        answer:
            'Yes! Once your order is dispatched, you\'ll get a tracking link with real-time location updates.',
        category: 'tracking',
      ),
    );

    faqs.add(
      FAQItem(
        question: 'What payment methods do you accept?',
        answer:
            'We accept credit/debit cards, UPI, net banking, wallets, and Cash on Delivery (where available).',
        category: 'payment',
      ),
    );

    faqs.add(
      FAQItem(
        question: 'Is my order covered by insurance?',
        answer:
            'All orders include damage protection. If your package arrives damaged, we\'ll replace it free of charge.',
        category: 'insurance',
      ),
    );

    // Add status-specific FAQs
    if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed) {
      faqs.add(
        FAQItem(
          question: 'Can I modify my order?',
          answer:
              'Pending orders can be modified until confirmation. Confirmed orders cannot be modified.',
          category: 'order_management',
        ),
      );
    }

    if (order.status == OrderStatus.delivered) {
      faqs.add(
        FAQItem(
          question: 'How do I return an item?',
          answer:
              'Click "Request Return" in your order details. Provide the reason and we\'ll arrange a pickup from your address.',
          category: 'returns',
        ),
      );
    }

    return faqs;
  }

  /// Get chatbot responses for common questions
  String? getChatbotResponse(String question, OrderModel order) {
    final lowerQuestion = question.toLowerCase();

    // Tracking questions
    if (lowerQuestion.contains('where') ||
        lowerQuestion.contains('track') ||
        lowerQuestion.contains('location')) {
      return _getTrackingResponse(order);
    }

    // Delivery time questions
    if (lowerQuestion.contains('when') ||
        lowerQuestion.contains('arrive') ||
        lowerQuestion.contains('time') ||
        lowerQuestion.contains('eta')) {
      return _getDeliveryTimeResponse(order);
    }

    // Return/refund questions
    if (lowerQuestion.contains('return') ||
        lowerQuestion.contains('refund') ||
        lowerQuestion.contains('exchange')) {
      return _getReturnResponse(order);
    }

    // Cancellation questions
    if (lowerQuestion.contains('cancel')) {
      return _getCancellationResponse(order);
    }

    // Payment questions
    if (lowerQuestion.contains('payment') ||
        lowerQuestion.contains('pay') ||
        lowerQuestion.contains('price')) {
      return 'Your order total is ₹${order.totalAmount.toStringAsFixed(0)} (including ₹${order.tax.toStringAsFixed(0)} tax). Payment received on ${_formatDate(order.createdAt)}.';
    }

    // Contact/support
    if (lowerQuestion.contains('contact') ||
        lowerQuestion.contains('call') ||
        lowerQuestion.contains('phone')) {
      return 'You can reach our support team at:📞 1800-FUFAJI (1800-383524)\nTiming: 9 AM - 9 PM, 7 days a week\nEmail: support@fufajis.online';
    }

    return null; // No response - escalate to human
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RESPONSE BUILDERS
  // ════════════════════════════════════════════════════════════════════════

  String _getTrackingResponse(OrderModel order) {
    if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed) {
      return 'Your order is being prepared. Once dispatched, you\'ll receive a tracking link. Expected dispatch: ${_formatDate(order.createdAt.add(const Duration(hours: 12)))}';
    } else if (order.status == OrderStatus.processing) {
      return 'Your order is being prepared in our warehouse. Expected dispatch tomorrow.';
    } else if (order.status == OrderStatus.packed) {
      return 'Your order has been packed and is ready for dispatch. Updates coming within the next 2 hours.';
    } else if (order.status == OrderStatus.outForDelivery) {
      return 'Your order is out for delivery! 🚗 Real-time tracking:\n📍 Current Location: ${order.liveLocation != null ? '${order.liveLocation!.latitude}, ${order.liveLocation!.longitude}' : "Loading..."}\n🚗 Rider: ${order.deliveryAgentName ?? "Assigned"}\n⏰ ETA: ${_getEstimatedTime(order)}';
    } else if (order.status == OrderStatus.delivered) {
      return 'Your order was delivered on ${_formatDate(order.deliveredAt)}. If you didn\'t receive it, please let us know.';
    }

    return 'No tracking info available yet.';
  }

  String _getDeliveryTimeResponse(OrderModel order) {
    if (order.status == OrderStatus.outForDelivery) {
      return 'Your package will arrive by ${_getEstimatedTime(order)}. The rider ${order.deliveryAgentName} will call you 15 minutes before arrival.';
    } else if (order.status == OrderStatus.delivered) {
      return 'Your order was delivered on ${_formatDate(order.deliveredAt)}.';
    } else {
      return 'Expected delivery: ${_formatDate(order.scheduledDeliveryDate)}. You\'ll receive more precise ETA once the order is dispatched.';
    }
  }

  String _getReturnResponse(OrderModel order) {
    if (order.status != OrderStatus.delivered) {
      return 'You can request returns after your order is delivered.';
    }

    final daysElapsed = DateTime.now().difference(order.deliveredAt ?? DateTime.now()).inDays;
    final daysRemaining = 7 - daysElapsed;

    if (daysRemaining > 0) {
      return '✅ Return eligible! You have $daysRemaining days left to request a return.\n\n1. Click "Request Return"\n2. Choose items and reason\n3. We\'ll arrange pickup\n4. Refund processed in 3-5 days';
    } else {
      return '❌ Return window closed. Returns are only available within 7 days of delivery. Contact support if you have a quality issue.';
    }
  }

  String _getCancellationResponse(OrderModel order) {
    switch (order.status) {
      case OrderStatus.pending:
        return '✅ You can cancel this pending order. Tap "Cancel Order" for a full refund to your original payment method.';
      case OrderStatus.confirmed:
      case OrderStatus.processing:
        return 'Your order is already confirmed/processing. Cancellations may not be possible. Please contact support immediately.';
      case OrderStatus.packed:
      case OrderStatus.outForDelivery:
        return 'Your order is already packed/out for delivery and cannot be cancelled. Once delivered, you can request a return.';
      default:
        return 'This order cannot be cancelled. Please contact support for assistance.';
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPER METHODS
  // ════════════════════════════════════════════════════════════════════════

  String _getEstimatedTime(OrderModel order) {
    if (order.scheduledDeliveryDate == null) {
      return 'Soon';
    }

    final estTime = order.scheduledDeliveryDate!.hour;
    if (estTime >= 22 || estTime < 9) {
      return 'by 10 PM today';
    } else if (estTime >= 14) {
      return 'by 4 PM today';
    } else {
      return 'by noon today';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ════════════════════════════════════════════════════════════════════════
//  DATA MODELS
// ════════════════════════════════════════════════════════════════════════

class SuggestedQuestion {
  final String id;
  final String question;
  final String category; // tracking, delivery, order_management, returns, feedback, invoice
  final String emoji;
  final String? autoResponse; // If null, escalate to human

  SuggestedQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.emoji,
    this.autoResponse,
  });
}

class QuickReplyTemplate {
  final String id;
  final String text;
  final String category; // greeting, status, support, refund

  QuickReplyTemplate({required this.id, required this.text, required this.category});
}

class FAQItem {
  final String question;
  final String answer;
  final String category;

  FAQItem({required this.question, required this.answer, required this.category});
}
