import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/marketing_campaign_model.dart';
import 'audit_logger.dart';

class MarketingAiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLoggerService _auditLogger = AuditLoggerService();

  /// Approve and execute a marketing campaign
  Future<void> approveCampaign(String campaignId, String ownerId) async {
    try {
      final docRef = _firestore.collection('marketing_campaigns').doc(campaignId);
      final docSnap = await docRef.get();
      
      if (!docSnap.exists) return;
      
      final campaign = MarketingCampaignModel.fromMap(docSnap.data()!, campaignId);

      await docRef.update({
        'status': MarketingCampaignStatus.approved.name,
      });

      // Execute campaign: If Wallet Cashback, could invoke a cloud function or batch write.
      // We will simulate execution by marking it as executed and logging.
      await docRef.update({
        'status': MarketingCampaignStatus.executed.name,
      });

      await _auditLogger.logAdminAction(
        'Marketing Campaign Executed',
        targetUserId: ownerId,
        metadata: {
          'campaignId': campaignId,
          'campaignType': campaign.campaignType,
          'targetAudience': campaign.targetAudience,
          'estimatedCost': campaign.estimatedCost,
        },
      );

      debugPrint('[MarketingAI] Executed campaign: ${campaign.title}');
    } catch (e) {
      debugPrint('[MarketingAI] Error approving campaign: $e');
    }
  }

  /// Reject a marketing campaign
  Future<void> rejectCampaign(String campaignId, String ownerId) async {
    try {
      final docRef = _firestore.collection('marketing_campaigns').doc(campaignId);
      await docRef.update({
        'status': MarketingCampaignStatus.rejected.name,
      });

      await _auditLogger.logAdminAction(
        'Marketing Campaign Rejected',
        targetUserId: ownerId,
        metadata: {'campaignId': campaignId},
      );
    } catch (e) {
      debugPrint('[MarketingAI] Error rejecting campaign: $e');
    }
  }
}
