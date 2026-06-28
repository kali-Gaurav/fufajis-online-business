import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import 'sentiment_service.dart';

// Legacy ChatService — backward-compat with support_chats collection
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Future<void> sendSupportMessage(ChatMessageModel msg) async {
    await _db.collection('support_chats').doc(msg.id).set(msg.toMap());
  }

  Stream<List<ChatMessageModel>> getCustomerChatStream(String customerId) {
    return _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: customerId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessageModel.fromMap(d.data())).toList());
  }

  Future<void> markMessagesAsRead(String channelId, String readerId) async {
    final batch = _db.batch();
    final docs = await _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: channelId)
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in docs.docs) {
      if (doc.data()['senderId'] != readerId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  Stream<List<ChatMessageModel>> getOwnerChatChannelsStream() {
    return _db
        .collection('support_chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessageModel.fromMap(d.data())).toList());
  }

  Stream<List<ChatMessageModel>> getRiderChatStream(String riderId) {
    return getCustomerChatStream(riderId);
  }

  /// Send a message to a support chat (legacy unified interface)
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String text,
    MessageType messageType = MessageType.text,
  }) async {
    final msgId = _db.collection('support_chats').doc().id;
    final msg = ChatMessageModel(
      id: msgId,
      chatChannelId: chatId,
      senderId: senderId,
      senderName: senderName,
      message: text,
      timestamp: DateTime.now(),
      isRead: false,
      receiverId: 'admin', // Placeholder
    );
    await sendSupportMessage(msg);
  }

  /// Update the typing indicator for a chat session.
  Future<void> updateTypingStatus({
    required String chatId,
    required bool isTyping,
    SenderRole? role,
  }) async {
    try {
      await _db
          .collection('support_chats')
          .doc(chatId)
          .set({
        'isTyping': isTyping,
        if (role != null) 'typingRole': role.name,
        'typingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] updateTypingStatus failed: $e');
    }
  }
}

// Task #64-#70 — SupportChatService
// support_conversations/{chatId}           — ChatConversationModel
// support_conversations/{chatId}/messages/ — ChatMessage
class SupportChatService {
  static final SupportChatService _instance = SupportChatService._internal();
  factory SupportChatService() => _instance;
  SupportChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SentimentService _sentiment = SentimentService();

  CollectionReference<Map<String, dynamic>> get _convCol =>
      _db.collection('support_conversations');

  CollectionReference<Map<String, dynamic>> _msgCol(String chatId) =>
      _convCol.doc(chatId).collection('messages');

  // Streams
  Stream<List<ChatConversationModel>> watchAllConversations() {
    return _convCol
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatConversationModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<ChatConversationModel?> watchConversation(String chatId) {
    return _convCol.doc(chatId).snapshots().map((snap) =>
        snap.exists ? ChatConversationModel.fromMap(snap.id, snap.data()!) : null);
  }

  Stream<List<ChatMessage>> watchMessages(String chatId,
      {bool customerView = true}) {
    return _msgCol(chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
      final msgs =
          snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();
      return customerView ? msgs.where((m) => !m.isInternalNote).toList() : msgs;
    });
  }

  // Send
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String text,
    MessageType messageType = MessageType.text,
    String? productId,
    String? productName,
    String? productImage,
    double? productPrice,
  }) async {
    final isCustomer = senderRole == SenderRole.customer;
    double? scoreVal;
    SentimentLabel? labelVal;
    if (isCustomer) {
      final r = _sentiment.analyze(text);
      scoreVal = r.score;
      labelVal = r.label;
    }

    final msgRef = _msgCol(chatId).doc();
    final batch = _db.batch();
    final msgData = <String, dynamic>{
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'messageType': messageType.name,
      'isInternalNote': false,
      'mentions': <String>[],
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (productId != null) msgData['productId'] = productId;
    if (productName != null) msgData['productName'] = productName;
    if (productImage != null) msgData['productImage'] = productImage;
    if (productPrice != null) msgData['productPrice'] = productPrice;
    if (scoreVal != null) msgData['sentimentScore'] = scoreVal;
    if (labelVal != null) msgData['sentimentLabel'] = labelVal.name;
    batch.set(msgRef, msgData);

    final convUpdate = <String, dynamic>{
      'lastMessage': text,
      'lastUpdated': FieldValue.serverTimestamp(),
      'status': ChatStatus.active.name,
    };
    if (isCustomer) {
      convUpdate['unreadCountOwner'] = FieldValue.increment(1);
      if (scoreVal != null) {
        convUpdate['sentimentScore'] = scoreVal;
        convUpdate['overallSentiment'] = labelVal!.name;
      }
    } else {
      convUpdate['unreadCountCustomer'] = FieldValue.increment(1);
    }
    batch.update(_convCol.doc(chatId), convUpdate);
    await batch.commit();

    if (labelVal == SentimentLabel.angry) {
      await _sendSystemMessage(chatId,
          'Sentiment Alert: Customer appears very frustrated. Consider escalating.');
    }
  }

  Future<void> sendInternalNote({
    required String chatId,
    required String senderId,
    required String senderName,
    required SenderRole senderRole,
    required String text,
    List<String> mentions = const [],
  }) async {
    await _msgCol(chatId).doc().set({
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'messageType': MessageType.internalNote.name,
      'isInternalNote': true,
      'mentions': mentions,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _sendSystemMessage(String chatId, String text) async {
    await _msgCol(chatId).doc().set({
      'chatId': chatId,
      'senderId': 'system',
      'senderName': 'System',
      'senderRole': SenderRole.system.name,
      'text': text,
      'messageType': MessageType.systemMessage.name,
      'isInternalNote': false,
      'mentions': <String>[],
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Conversation management
  Future<String> createConversation({
    required String customerId,
    required String customerName,
    required String customerPhone,
    String? orderId,
    String? orderNumber,
    String initialMessage = '',
  }) async {
    final ref = _convCol.doc();
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      if (orderId != null) 'orderId': orderId,
      if (orderNumber != null) 'orderNumber': orderNumber,
      'status': ChatStatus.open.name,
      'lastMessage': initialMessage,
      'lastUpdated': now,
      'createdAt': now,
      'unreadCountOwner': initialMessage.isNotEmpty ? 1 : 0,
      'unreadCountCustomer': 0,
      'isTypingCustomer': false,
      'isTypingStaff': false,
      'sentimentScore': 0.0,
    });
    if (initialMessage.isNotEmpty) {
      await sendMessage(
        chatId: ref.id,
        senderId: customerId,
        senderName: customerName,
        senderRole: SenderRole.customer,
        text: initialMessage,
      );
    }
    return ref.id;
  }

  Future<void> closeConversation(String chatId) async {
    await _convCol.doc(chatId).update({
      'status': ChatStatus.closed.name,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignConversation({
    required String chatId,
    required String assignedToId,
    required String assignedToName,
  }) async {
    await _convCol.doc(chatId).update({
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    await _sendSystemMessage(chatId, 'Chat assigned to $assignedToName.');
  }

  Future<void> markAsRead(String chatId, SenderRole readerRole) async {
    final field =
        (readerRole == SenderRole.owner || readerRole == SenderRole.employee)
            ? 'unreadCountOwner'
            : 'unreadCountCustomer';
    await _convCol.doc(chatId).update({field: 0});
  }

  Future<void> setTyping(String chatId, bool isTyping, SenderRole role) async {
    final field =
        role == SenderRole.customer ? 'isTypingCustomer' : 'isTypingStaff';
    await _convCol.doc(chatId).update({field: isTyping});
  }

  // Export (Task #70)
  Future<List<ChatMessage>> fetchAllMessages(String chatId) async {
    final snap = await _msgCol(chatId)
        .orderBy('timestamp', descending: false)
        .get();
    return snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList();
  }

  Future<ChatConversationModel?> fetchConversation(String chatId) async {
    final snap = await _convCol.doc(chatId).get();
    if (!snap.exists) return null;
    return ChatConversationModel.fromMap(snap.id, snap.data()!);
  }
}
