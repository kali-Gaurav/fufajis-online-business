import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;

  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;

  StreamSubscription? _chatSubscription;

  void listenToChat(String channelId) {
    _isLoading = true;
    notifyListeners();

    _chatSubscription?.cancel();
    _chatSubscription = _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: channelId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          _messages = snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data()))
              .toList();
          _isLoading = false;
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String message,
    required String channelId,
  }) async {
    final msg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      message: message,
      timestamp: DateTime.now(),
      isRead: false,
      chatChannelId: channelId,
    );

    await _chatService.sendSupportMessage(msg);
  }

  // Feature: Voice Note Order Request
  Future<void> sendVoiceNoteOrder({
    required String senderId,
    required String senderName,
    required String voiceNoteUrl,
    required String channelId,
  }) async {
    await sendMessage(
      senderId: senderId,
      senderName: senderName,
      receiverId: 'shop_owner',
      message: '🎤 Voice Order Request: $voiceNoteUrl',
      channelId: channelId,
    );
  }
}
