import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineNotificationQueueModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? data;
  final String? deepLink;
  final bool isDelivered;

  OfflineNotificationQueueModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.deliveredAt,
    this.data,
    this.deepLink,
    this.isDelivered = false,
  });

  factory OfflineNotificationQueueModel.fromMap(Map<String, dynamic> map) {
    return OfflineNotificationQueueModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      data: map['data'],
      deepLink: map['deepLink'],
      isDelivered: map['isDelivered'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt': deliveredAt != null
          ? Timestamp.fromDate(deliveredAt!)
          : null,
      'data': data,
      'deepLink': deepLink,
      'isDelivered': isDelivered,
    };
  }

  OfflineNotificationQueueModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    DateTime? createdAt,
    DateTime? deliveredAt,
    Map<String, dynamic>? data,
    String? deepLink,
    bool? isDelivered,
  }) {
    return OfflineNotificationQueueModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      data: data ?? this.data,
      deepLink: deepLink ?? this.deepLink,
      isDelivered: isDelivered ?? this.isDelivered,
    );
  }
}
