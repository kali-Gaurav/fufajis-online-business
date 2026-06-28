import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_conversation_model.dart';
import '../services/chat_service.dart';

/// Task #64-#70 — ChatProvider wrapping SupportChatService.
class ChatProvider with ChangeNotifier {
  final SupportChatService _svc = SupportChatService();

  List<ChatConversationModel> _conversations = [];
  List<ChatMessage> _messages = [];
  ChatConversationModel? _activeConversation;
  bool _isLoading = false;
  bool _isSending = false;

  List<ChatConversationModel> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  ChatConversationModel? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;

  StreamSubscription<List<ChatConversationModel>>? _convsSub;
  StreamSubscription<List<ChatMessage>>? _msgsSub;
  StreamSubscription<ChatConversationModel?>? _metaSub;

  void listenToAllConversations() {
    _convsSub?.cancel();
    _convsSub = _svc.watchAllConversations().listen((list) {
      _conversations = list;
      notifyListeners();
    });
  }

  void listenToMessages(String chatId, {bool customerView = false}) {
    _isLoading = true;
    notifyListeners();
    _msgsSub?.cancel();
    _msgsSub =
        _svc.watchMessages(chatId, customerView: customerView).listen((msgs) {
      _messages = msgs;
      _isLoading = false;
      notifyListeners();
    });
  }

  void listenToConversationMeta(String chatId) {
    _metaSub?.cancel();
    _metaSub = _svc.watchConversation(chatId).listen((conv) {
      _activeConversation = conv;
      notifyListeners();
    });
  }

  void listenToAssignedConversations(String employeeId) {
    _convsSub?.cancel();
    _convsSub = _svc.watchAllConversations().listen((list) {
      _conversations = list;
      notifyListeners();
    });
  }

  void listenToUnassignedConversations() {
    if (_convsSub == null) {
      listenToAllConversations();
    }
  }

  void clearActiveChat() {
    _msgsSub?.cancel();
    _metaSub?.cancel();
    _messages = [];
    _activeConversation = null;
    notifyListeners();
  }

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
    _isSending = true;
    notifyListeners();
    try {
      await _svc.sendMessage(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        messageType: messageType,
        productId: productId,
        productName: productName,
        productImage: productImage,
        productPrice: productPrice,
      );
    } finally {
      _isSending = false;
      notifyListeners();
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
    _isSending = true;
    notifyListeners();
    try {
      await _svc.sendInternalNote(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        mentions: mentions,
      );
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> closeConversation(String chatId) async {
    await _svc.closeConversation(chatId);
  }

  Future<void> assignConversation({
    required String chatId,
    required String assignedToId,
    required String assignedToName,
  }) async {
    await _svc.assignConversation(
      chatId: chatId,
      assignedToId: assignedToId,
      assignedToName: assignedToName,
    );
  }

  Future<void> markAsRead(String chatId, SenderRole role) async {
    await _svc.markAsRead(chatId, role);
  }

  Future<String> createConversation({
    required String customerId,
    required String customerName,
    required String customerPhone,
    String? orderId,
    String? orderNumber,
    String initialMessage = '',
  }) async {
    return _svc.createConversation(
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      orderId: orderId,
      orderNumber: orderNumber,
      initialMessage: initialMessage,
    );
  }

  /// Conversations not yet assigned to any employee.
  List<ChatConversationModel> get unassignedConversations =>
      _conversations.where((c) => c.assignedToId == null || c.assignedToId!.isEmpty).toList();

  /// Claim an unassigned conversation for the current employee.
  Future<void> claimConversation({
    required String chatId,
    required String employeeId,
    required String employeeName,
  }) async {
    await assignConversation(
      chatId: chatId,
      assignedToId: employeeId,
      assignedToName: employeeName,
    );
  }

  @override
  void dispose() {
    _convsSub?.cancel();
    _msgsSub?.cancel();
    _metaSub?.cancel();
    super.dispose();
  }
}
