import 'package:cloud_firestore/cloud_firestore.dart';

enum BroadcastStatus { draft, scheduled, sending, sent, cancelled }

BroadcastStatus broadcastStatusFromString(String? value) {
  switch (value) {
    case 'scheduled':
      return BroadcastStatus.scheduled;
    case 'sending':
      return BroadcastStatus.sending;
    case 'sent':
      return BroadcastStatus.sent;
    case 'cancelled':
      return BroadcastStatus.cancelled;
    case 'draft':
    default:
      return BroadcastStatus.draft;
  }
}

class BroadcastAudience {
  final String type; // 'all' | 'segment' | 'manual'
  final String? segmentId;
  final List<String> userIds;

  const BroadcastAudience({required this.type, this.segmentId, this.userIds = const []});

  factory BroadcastAudience.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BroadcastAudience(type: 'all');
    final rawUserIds = map['userIds'] as List<dynamic>? ?? const [];
    return BroadcastAudience(
      type: map['type']?.toString() ?? 'all',
      segmentId: map['segmentId']?.toString(),
      userIds: rawUserIds.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, if (segmentId != null) 'segmentId': segmentId, 'userIds': userIds};
  }
}

class BroadcastStats {
  final int delivered;
  final int opened;
  final int clicked;
  final int optOuts;

  const BroadcastStats({this.delivered = 0, this.opened = 0, this.clicked = 0, this.optOuts = 0});

  factory BroadcastStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BroadcastStats();
    return BroadcastStats(
      delivered: (map['delivered'] as num?)?.toInt() ?? 0,
      opened: (map['opened'] as num?)?.toInt() ?? 0,
      clicked: (map['clicked'] as num?)?.toInt() ?? 0,
      optOuts: (map['optOuts'] as num?)?.toInt() ?? 0,
    );
  }
}

class BroadcastModel {
  final String id;
  final String title;
  final String body;
  final String? deepLink;
  final String? imageUrl;
  final BroadcastAudience audience;
  final int? estimatedReach;
  final BroadcastStatus status;
  final String channel; // 'push' | 'sms' | 'whatsapp'
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final String createdBy;
  final String? approvedBy;
  final BroadcastStats stats;
  final String? variant;
  final DateTime? createdAt;

  const BroadcastModel({
    required this.id,
    required this.title,
    required this.body,
    this.deepLink,
    this.imageUrl,
    required this.audience,
    this.estimatedReach,
    required this.status,
    required this.channel,
    this.scheduledFor,
    this.sentAt,
    required this.createdBy,
    this.approvedBy,
    required this.stats,
    this.variant,
    this.createdAt,
  });

  factory BroadcastModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BroadcastModel(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      deepLink: data['deepLink']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      audience: BroadcastAudience.fromMap(data['audience'] as Map<String, dynamic>?),
      estimatedReach: (data['estimatedReach'] as num?)?.toInt(),
      status: broadcastStatusFromString(data['status'] as String?),
      channel: data['channel']?.toString() ?? 'push',
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy']?.toString() ?? '',
      approvedBy: data['approvedBy']?.toString(),
      stats: BroadcastStats.fromMap(data['stats'] as Map<String, dynamic>?),
      variant: data['variant']?.toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
