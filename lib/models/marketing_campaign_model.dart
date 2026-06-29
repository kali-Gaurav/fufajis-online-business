import 'package:cloud_firestore/cloud_firestore.dart';

enum MarketingCampaignStatus { pending, approved, rejected, executed }

class MarketingCampaignModel {
  final String id;
  final String title;
  final String description;
  final String targetAudience; // e.g., "Dormant Users", "High Value", "Frequent Buyers"
  final String campaignType; // e.g., "Push Notification", "Wallet Cashback", "Festival"
  final String? branchId; // Optional branch specific
  final double estimatedCost;
  final double expectedRoi; // percentage
  final int estimatedReach;
  final MarketingCampaignStatus status;
  final DateTime createdAt;

  MarketingCampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAudience,
    required this.campaignType,
    this.branchId,
    required this.estimatedCost,
    required this.expectedRoi,
    required this.estimatedReach,
    this.status = MarketingCampaignStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'targetAudience': targetAudience,
      'campaignType': campaignType,
      'branchId': branchId,
      'estimatedCost': estimatedCost,
      'expectedRoi': expectedRoi,
      'estimatedReach': estimatedReach,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MarketingCampaignModel.fromMap(Map<String, dynamic> map, String docId) {
    return MarketingCampaignModel(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      targetAudience: map['targetAudience'] as String? ?? '',
      campaignType: map['campaignType'] as String? ?? '',
      branchId: map['branchId'] as String?,
      estimatedCost: (map['estimatedCost'] as num? ?? 0.0).toDouble(),
      expectedRoi: (map['expectedRoi'] as num? ?? 0.0).toDouble(),
      estimatedReach: map['estimatedReach'] as int? ?? 0,
      status: MarketingCampaignStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => MarketingCampaignStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
