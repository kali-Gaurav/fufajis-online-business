import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Future<void> sendSupportMessage(ChatMessageModel msg) async {
    await _db.collection('support_chats').doc(msg.id).set(msg.toMap());
  }

  Stream<List<ChatMessageModel>> getRiderChatStream(String riderId) {
    return _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: riderId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Stream<List<ChatMessageModel>> getOwnerChatChannelsStream() {
    return _db
        .collection('support_chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final Map<String, ChatMessageModel> latestMessages = {};
          for (var doc in snapshot.docs) {
            final msg = ChatMessageModel.fromMap(doc.data());
            if (!latestMessages.containsKey(msg.chatChannelId)) {
              latestMessages[msg.chatChannelId] = msg;
            }
          }
          return latestMessages.values.toList();
        });
  }

  Stream<List<ChatMessageModel>> getCustomerChatStream(String customerId) {
    return _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: customerId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> markMessagesAsRead(String chatChannelId, String readerId) async {
    final batch = _db.batch();
    final unreadDocs = await _db
        .collection('support_chats')
        .where('chatChannelId', isEqualTo: chatChannelId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadDocs.docs) {
      if (doc.data()['senderId'] != readerId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
