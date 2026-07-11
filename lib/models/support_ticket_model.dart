class SupportTicket {
  final String id;
  final String orderId;
  final String customerId;
  final String issueType; // "missing", "damaged", "wrong", "quantity", "delivery"
  final String description;
  final List<String>? photoUrls;
  final String status; // "open", "in_progress", "resolved", "closed"
  final List<SupportMessage> messages;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  SupportTicket({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.issueType,
    required this.description,
    this.photoUrls,
    required this.status,
    required this.messages,
    required this.createdAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromFirestore(Map<String, dynamic> data) {
    return SupportTicket(
      id: data['id'] as String,
      orderId: data['orderId'] as String,
      customerId: data['customerId'] as String,
      issueType: data['issueType'] as String,
      description: data['description'] as String,
      photoUrls: (data['photoUrls'] as List<dynamic>?)?.cast<String>(),
      status: data['status'] as String,
      messages: (data['messages'] as List<dynamic>?)?.map((e) => SupportMessage.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      createdAt: DateTime.parse(data['createdAt'] as String),
      resolvedAt: data['resolvedAt'] != null ? DateTime.parse(data['resolvedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'orderId': orderId,
    'customerId': customerId,
    'issueType': issueType,
    'description': description,
    'photoUrls': photoUrls,
    'status': status,
    'messages': messages.map((e) => e.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  SupportTicket copyWith({
    String? status,
    List<SupportMessage>? messages,
    DateTime? resolvedAt,
  }) {
    return SupportTicket(
      id: id,
      orderId: orderId,
      customerId: customerId,
      issueType: issueType,
      description: description,
      photoUrls: photoUrls,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

class SupportMessage {
  final String id;
  final String senderType; // "customer", "support", "agent"
  final String senderName;
  final String message;
  final String? attachmentUrl;
  final DateTime timestamp;

  SupportMessage({
    required this.id,
    required this.senderType,
    required this.senderName,
    required this.message,
    this.attachmentUrl,
    required this.timestamp,
  });

  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
    id: map['id'] as String,
    senderType: map['senderType'] as String,
    senderName: map['senderName'] as String,
    message: map['message'] as String,
    attachmentUrl: map['attachmentUrl'] as String?,
    timestamp: DateTime.parse(map['timestamp'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'senderType': senderType,
    'senderName': senderName,
    'message': message,
    'attachmentUrl': attachmentUrl,
    'timestamp': timestamp.toIso8601String(),
  };
}
