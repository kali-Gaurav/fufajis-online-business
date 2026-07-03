import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/chat_conversation_model.dart';
import 'chat_service.dart';
import 'audit_service.dart';

class SupportAiAgentService {
  static final SupportAiAgentService _instance = SupportAiAgentService._internal();
  factory SupportAiAgentService() => _instance;
  SupportAiAgentService._internal();

  late GenerativeModel _model;
  final ChatService _chatService = ChatService();
  final AuditService _auditService = AuditService();

  // Keep track of which chats the AI is currently helping with
  final Set<String> _activeAiChats = {};

  /// Phrases in the AI's own reply that indicate it could not resolve the
  /// query and is handing off to a human. Used to decide whether to open
  /// a support ticket for follow-up.
  static const List<String> _escalationPhrases = [
    'connect you to a human agent',
    'transfer this to our human support team',
    'connect you to our human support team',
  ];

  void initialize() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-1.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.3, // Lower temp for more deterministic support responses
      ),
    );
  }

  /// Attempts to automatically reply to a customer message.
  Future<void> attemptAutoReply({
    required String chatId,
    required String customerMessage,
    required String customerId,
  }) async {
    if (_activeAiChats.contains(chatId)) return; // Already processing

    _activeAiChats.add(chatId);

    try {
      // 1. Show AI is typing
      await _chatService.updateTypingStatus(
        chatId: chatId,
        isTyping: true,
        role: SenderRole.system,
      );

      final lowerMsg = customerMessage.toLowerCase();
      bool isFrustrated = false;
      final frustrationWords = [
        'angry',
        'terrible',
        'worst',
        'cheat',
        'fraud',
        'useless',
        'waste',
        'disappointed',
        'hate',
        'furious',
        'bad service',
        'stole',
        'stolen',
        'cheated',
      ];
      for (final word in frustrationWords) {
        if (lowerMsg.contains(word)) {
          isFrustrated = true;
          break;
        }
      }

      String replyText = '';
      bool escalated = false;

      if (isFrustrated) {
        replyText =
            'I understand you are frustrated and I apologize for the inconvenience. Let me immediately connect you to our human support team to resolve this right away!';
        escalated = true;

        // Mark conversation as urgent/frustrated in Firestore
        await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
          'sentiment': 'frustrated',
          'isUrgent': true,
        });
      } else {
        // FAQ Auto-Linking check
        String? faqAnswer;
        String? faqTopic;
        if (lowerMsg.contains('refund') || lowerMsg.contains('money')) {
          faqTopic = 'Refunds';
          faqAnswer =
              'Refunds typically process in 3-5 business days to your original payment method or Fufaji Wallet.';
        } else if (lowerMsg.contains('cancel')) {
          faqTopic = 'Cancellation';
          faqAnswer =
              'Pending orders can be cancelled directly from the app for a full refund. Once packed, cancellations may incur a fee.';
        } else if (lowerMsg.contains('delivery') ||
            lowerMsg.contains('eta') ||
            lowerMsg.contains('arrive')) {
          faqTopic = 'Delivery Tracking';
          faqAnswer =
              'You can track your order in real-time under the \'Track Order\' section of your app.';
        } else if (lowerMsg.contains('cod') || lowerMsg.contains('cash')) {
          faqTopic = 'Cash on Delivery';
          faqAnswer =
              'We support Cash on Delivery up to your account limit. You can check your COD limit in user settings.';
        }

        if (faqAnswer != null) {
          replyText =
              '📚 [FAQ Auto-Link: $faqTopic]\n$faqAnswer\n\nHope this helps! Let me know if you need to speak to a human.';
        } else {
          // Fallback to Gemini
          final prompt =
              '''
You are the Fufaji Level 1 AI Support Agent. 
You handle queries for a hyperlocal delivery app in India.

User Query: "$customerMessage"

Instructions:
1. Keep it short, professional, and friendly. Do NOT make up policies.
2. If you are unsure or the query is complex, say: "Let me transfer this to our human support team. They will reply shortly!"
''';
          final response = await _model.generateContent([Content.text(prompt)]);
          replyText = response.text?.trim() ?? "Let me connect you to our human support team.";
        }
      }

      // Add a slight delay to feel natural
      await Future.delayed(const Duration(seconds: 1));

      // 3. Send message
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: 'ai_support_agent',
        senderName: 'Fufaji AI Support',
        senderRole: SenderRole.system,
        text: replyText,
      );

      // 4. Audit trail
      final bool actuallyEscalated =
          escalated || _escalationPhrases.any((phrase) => replyText.toLowerCase().contains(phrase));

      unawaited(
        _auditService.logAction(
          userId: 'ai_support_agent',
          userName: 'Fufaji AI Support',
          action: actuallyEscalated ? AuditAction.aiSupportEscalated : AuditAction.aiSupportReply,
          description: actuallyEscalated
              ? 'AI support agent could not resolve query and flagged for human follow-up'
              : 'AI support agent auto-replied to customer query',
          targetId: chatId,
          targetType: 'chat',
          metadata: {
            'customerId': customerId,
            'customerMessage': customerMessage,
            'replyText': replyText,
            'sentiment': isFrustrated ? 'frustrated' : 'neutral',
          },
        ),
      );

      // 5. If the AI handed off, open a support ticket
      if (actuallyEscalated) {
        await FirebaseFirestore.instance.collection('support_tickets').add({
          'userId': customerId,
          'subject': isFrustrated
              ? 'Urgent escalation: chat $chatId'
              : 'AI escalation: chat $chatId',
          'description': 'Customer asked: "$customerMessage"\n\nAI reply: "$replyText"',
          'priority': isFrustrated ? 'high' : 'normal',
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[SupportAiAgentService] Auto-reply failed: $e');
    } finally {
      // 6. Stop typing
      await _chatService.updateTypingStatus(
        chatId: chatId,
        isTyping: false,
        role: SenderRole.system,
      );
      _activeAiChats.remove(chatId);
    }
  }
}
