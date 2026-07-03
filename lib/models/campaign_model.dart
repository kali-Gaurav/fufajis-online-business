import 'package:cloud_firestore/cloud_firestore.dart';

enum CampaignType { push, banner, whatsapp, email }

enum CampaignStatus { draft, scheduled, active, completed, cancelled }

class CampaignModel {
  final String id;
  final String title;
  final String messageBody;
  final CampaignType type;
  final CampaignStatus status;

  // Segmentation
  final List<String> targetSegments; // e.g., 'all', 'vip', 'dormant', 'new'
  final int estimatedAudienceSize;

  // Scheduling
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime createdAt;

  // Content details
  final String? imageUrl;
  final String? actionUrl; // Deep link when clicked
  final String? couponCode;

  // Analytics tracking
  final int impressions;
  final int clicks;
  final int conversions;
  final double revenueAttributed;

  // Send-time optimization: when true, delivery is staggered per-recipient
  // based on each user's historical active hour instead of sent immediately.
  final bool sendTimeOptimization;

  const CampaignModel({
    required this.id,
    required this.title,
    required this.messageBody,
    required this.type,
    required this.status,
    this.targetSegments = const ['all'],
    this.estimatedAudienceSize = 0,
    this.scheduledAt,
    this.sentAt,
    required this.createdAt,
    this.imageUrl,
    this.actionUrl,
    this.couponCode,
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.revenueAttributed = 0.0,
    this.sendTimeOptimization = false,
  });

  factory CampaignModel.fromMap(Map<String, dynamic> map, String docId) {
    return CampaignModel(
      id: docId,
      title: map['title'] as String? ?? '',
      messageBody: map['messageBody'] as String? ?? '',
      type: CampaignType.values.firstWhere(
        (e) => e.name == map['type'] as String?,
        orElse: () => CampaignType.push,
      ),
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => CampaignStatus.draft,
      ),
      targetSegments: List<String>.from(map['targetSegments'] as Iterable? ?? ['all']),
      estimatedAudienceSize: map['estimatedAudienceSize'] as int? ?? 0,
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      sentAt: (map['sentAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'] as String?,
      actionUrl: map['actionUrl'] as String?,
      couponCode: map['couponCode'] as String?,
      impressions: map['impressions'] as int? ?? 0,
      clicks: map['clicks'] as int? ?? 0,
      conversions: map['conversions'] as int? ?? 0,
      revenueAttributed: (map['revenueAttributed'] as num? ?? 0.0).toDouble(),
      sendTimeOptimization: map['sendTimeOptimization'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'messageBody': messageBody,
      'type': type.name,
      'status': status.name,
      'targetSegments': targetSegments,
      'estimatedAudienceSize': estimatedAudienceSize,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'couponCode': couponCode,
      'impressions': impressions,
      'clicks': clicks,
      'conversions': conversions,
      'revenueAttributed': revenueAttributed,
      'sendTimeOptimization': sendTimeOptimization,
    };
  }

  CampaignModel copyWith({
    String? title,
    String? messageBody,
    CampaignType? type,
    CampaignStatus? status,
    List<String>? targetSegments,
    int? estimatedAudienceSize,
    DateTime? scheduledAt,
    DateTime? sentAt,
    String? imageUrl,
    String? actionUrl,
    String? couponCode,
    int? impressions,
    int? clicks,
    int? conversions,
    double? revenueAttributed,
    bool? sendTimeOptimization,
  }) {
    return CampaignModel(
      id: id,
      title: title ?? this.title,
      messageBody: messageBody ?? this.messageBody,
      type: type ?? this.type,
      status: status ?? this.status,
      targetSegments: targetSegments ?? this.targetSegments,
      estimatedAudienceSize: estimatedAudienceSize ?? this.estimatedAudienceSize,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      couponCode: couponCode ?? this.couponCode,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      conversions: conversions ?? this.conversions,
      revenueAttributed: revenueAttributed ?? this.revenueAttributed,
      sendTimeOptimization: sendTimeOptimization ?? this.sendTimeOptimization,
    );
  }
}
