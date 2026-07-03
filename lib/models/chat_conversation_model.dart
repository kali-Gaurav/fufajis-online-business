import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatStatus { open, active, closed }

enum MessageType { text, image, invoice, systemMessage, internalNote, voiceNote, productInquiry }

enum SenderRole { customer, owner, employee, deliveryAgent, system }

/// Task #68 — Sentiment label produced by SentimentService.
/// Scores range from -1.0 (angry) to +1.0 (positive).
enum SentimentLabel {
  positive, // score ≥ 0.2
  neutral, // -0.2 < score < 0.2
  negative, // -0.6 ≤ score < -0.2
  angry; // score < -0.6  — triggers escalation alert

  String get emoji {
    switch (this) {
      case positive:
        return '😊';
      case neutral:
        return '😐';
      case negative:
        return '😞';
      case angry:
        return '😡';
    }
  }

  String get label {
    switch (this) {
      case positive:
        return 'Positive';
      case neutral:
        return 'Neutral';
      case negative:
        return 'Negative';
      case angry:
        return 'Angry';
    }
  }

  static SentimentLabel fromScore(double score) {
    if (score >= 0.2) return positive;
    if (score >= -0.2) return neutral;
    if (score >= -0.6) return negative;
    return angry;
  }
}

class ChatConversationModel {
  final String chatId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? orderId;
  final String? orderNumber;
  final ChatStatus status;
  final String lastMessage;
  final DateTime lastUpdated;
  final String? assignedToId;
  final String? assignedToName;
  final int unreadCountOwner;
  final int unreadCountCustomer;
  final bool isTypingCustomer;
  final bool isTypingStaff;
  final DateTime createdAt;
  // Task #68 — conversation-level sentiment (rolling average of customer msgs)
  final SentimentLabel? overallSentiment;
  final double sentimentScore;

  ChatConversationModel({
    required this.chatId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.orderId,
    this.orderNumber,
    this.status = ChatStatus.open,
    this.lastMessage = '',
    required this.lastUpdated,
    this.assignedToId,
    this.assignedToName,
    this.unreadCountOwner = 0,
    this.unreadCountCustomer = 0,
    this.isTypingCustomer = false,
    this.isTypingStaff = false,
    required this.createdAt,
    this.overallSentiment,
    this.sentimentScore = 0.0,
  });

  factory ChatConversationModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatConversationModel(
      chatId: id,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      orderId: map['orderId'] as String?,
      orderNumber: map['orderNumber'] as String?,
      status: ChatStatus.values.firstWhere(
        (s) => s.name == map['status'] as String?,
        orElse: () => ChatStatus.open,
      ),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      assignedToId: map['assignedToId'] as String?,
      assignedToName: map['assignedToName'] as String?,
      unreadCountOwner: map['unreadCountOwner'] as int? ?? 0,
      unreadCountCustomer: map['unreadCountCustomer'] as int? ?? 0,
      isTypingCustomer: map['isTypingCustomer'] as bool? ?? false,
      isTypingStaff: map['isTypingStaff'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      sentimentScore: (map['sentimentScore'] as num?)?.toDouble() ?? 0.0,
      overallSentiment: map['overallSentiment'] != null
          ? SentimentLabel.values.firstWhere(
              (s) => s.name == map['overallSentiment'],
              orElse: () => SentimentLabel.neutral,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'status': status.name,
      'lastMessage': lastMessage,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'assignedToId': assignedToId,
      'assignedToName': assignedToName,
      'unreadCountOwner': unreadCountOwner,
      'unreadCountCustomer': unreadCountCustomer,
      'isTypingCustomer': isTypingCustomer,
      'isTypingStaff': isTypingStaff,
      'createdAt': Timestamp.fromDate(createdAt),
      'sentimentScore': sentimentScore,
      if (overallSentiment != null) 'overallSentiment': overallSentiment!.name,
    };
  }

  ChatConversationModel copyWith({
    String? chatId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? orderId,
    String? orderNumber,
    ChatStatus? status,
    String? lastMessage,
    DateTime? lastUpdated,
    String? assignedToId,
    String? assignedToName,
    int? unreadCountOwner,
    int? unreadCountCustomer,
    bool? isTypingCustomer,
    bool? isTypingStaff,
    DateTime? createdAt,
    SentimentLabel? overallSentiment,
    double? sentimentScore,
  }) {
    return ChatConversationModel(
      chatId: chatId ?? this.chatId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      unreadCountOwner: unreadCountOwner ?? this.unreadCountOwner,
      unreadCountCustomer: unreadCountCustomer ?? this.unreadCountCustomer,
      isTypingCustomer: isTypingCustomer ?? this.isTypingCustomer,
      isTypingStaff: isTypingStaff ?? this.isTypingStaff,
      createdAt: createdAt ?? this.createdAt,
      overallSentiment: overallSentiment ?? this.overallSentiment,
      sentimentScore: sentimentScore ?? this.sentimentScore,
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final SenderRole senderRole;
  final String text;
  final MessageType messageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final bool isInternalNote;
  final List<String> mentions; // e.g. ['@owner', '@delivery']
  final bool isRead;
  final DateTime timestamp;

  // Task #64: product-card context, populated when [messageType] is
  // [MessageType.productInquiry] — lets the vendor see at a glance which
  // product the customer is asking about.
  final String? productId;
  final String? productName;
  final String? productImage;
  final double? productPrice;

  // Task #68: per-message sentiment (only scored for customer messages)
  final double? sentimentScore;
  final SentimentLabel? sentimentLabel;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.messageType = MessageType.text,
    this.attachmentUrl,
    this.attachmentName,
    this.isInternalNote = false,
    this.mentions = const [],
    this.isRead = false,
    required this.timestamp,
    this.productId,
    this.productName,
    this.productImage,
    this.productPrice,
    this.sentimentScore,
    this.sentimentLabel,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      senderRole: SenderRole.values.firstWhere(
        (r) => r.name == map['senderRole'] as String?,
        orElse: () => SenderRole.customer,
      ),
      text: map['text'] as String? ?? '',
      messageType: MessageType.values.firstWhere(
        (t) => t.name == map['messageType'] as String?,
        orElse: () => MessageType.text,
      ),
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      isInternalNote: map['isInternalNote'] as bool? ?? false,
      mentions: List<String>.from(map['mentions'] as Iterable? ?? []),
      isRead: map['isRead'] as bool? ?? false,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      productId: map['productId'] as String?,
      productName: map['productName'] as String?,
      productImage: map['productImage'] as String?,
      productPrice: (map['productPrice'] as num?)?.toDouble(),
      sentimentScore: (map['sentimentScore'] as num?)?.toDouble(),
      sentimentLabel: map['sentimentLabel'] != null
          ? SentimentLabel.values.firstWhere(
              (s) => s.name == map['sentimentLabel'],
              orElse: () => SentimentLabel.neutral,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'text': text,
      'messageType': messageType.name,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isInternalNote': isInternalNote,
      'mentions': mentions,
      'isRead': isRead,
      'timestamp': FieldValue.serverTimestamp(),
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      if (productImage != null) 'productImage': productImage,
      if (productPrice != null) 'productPrice': productPrice,
      if (sentimentScore != null) 'sentimentScore': sentimentScore,
      if (sentimentLabel != null) 'sentimentLabel': sentimentLabel!.name,
    };
  }
}
