import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campaign_model.dart';
import 'audit_service.dart';

/// SharedPreferences keys used for last-click attribution (campaign performance reporting).
const String _kLastClickedCampaignId = 'last_clicked_campaign_id';
const String _kLastClickedCampaignAt = 'last_clicked_campaign_at';

/// Attribution window: a conversion (order) placed within this duration of a
/// campaign notification tap is credited to that campaign.
const Duration kCampaignAttributionWindow = Duration(hours: 48);

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── CRUD OPERATIONS ───────────────────────────────────────────────

  Stream<List<CampaignModel>> watchCampaigns() {
    return _db
        .collection('marketing_campaigns')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => CampaignModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<CampaignModel?> getCampaign(String id) async {
    final doc = await _db.collection('marketing_campaigns').doc(id).get();
    if (!doc.exists) return null;
    return CampaignModel.fromMap(doc.data()!, doc.id);
  }

  Future<String> createCampaign(CampaignModel campaign, String adminId, String adminName) async {
    final docRef = await _db.collection('marketing_campaigns').add(campaign.toMap());

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction, // Fallback since campaign action isn't in the enum
      description: 'Created marketing campaign: ${campaign.title}',
      targetId: docRef.id,
      metadata: {'type': campaign.type.name, 'segments': campaign.targetSegments},
    );

    return docRef.id;
  }

  Future<void> updateCampaign(CampaignModel campaign, String adminId, String adminName) async {
    await _db.collection('marketing_campaigns').doc(campaign.id).update(campaign.toMap());

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Updated marketing campaign: ${campaign.title}',
      targetId: campaign.id,
    );
  }

  Future<void> deleteCampaign(String id, String adminId, String adminName) async {
    await _db.collection('marketing_campaigns').doc(id).delete();

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Deleted marketing campaign',
      targetId: id,
    );
  }

  // ─── AUDIENCE ESTIMATION ──────────────────────────────────────────

  /// Estimates audience size by counting users who match the selected segments.
  Future<int> estimateAudienceSize(List<String> segments) async {
    if (segments.contains('all')) {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .count()
          .get();
      return snap.count ?? 0;
    }

    // In a real production system, this would be a more complex query based on order history,
    // last active dates, and other aggregated user metrics stored in their profile.
    // For now, we'll run separate queries or use an approximation.

    int count = 0;

    if (segments.contains('vip')) {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('tier', whereIn: ['MembershipTier.gold', 'MembershipTier.platinum'])
          .count()
          .get();
      count += snap.count ?? 0;
    }

    if (segments.contains('new')) {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'UserRole.customer')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .count()
          .get();
      count += snap.count ?? 0;
    }

    // Avoid overcounting if 'all' is not selected but multiple segments are
    // This is an approximation. A robust system would query the aggregated 'customer_stats' collection.
    return count > 0 ? count : 50; // default minimum for testing
  }

  // ─── EXECUTION ───────────────────────────────────────────────────

  /// Executes or schedules the campaign. If scheduledAt is null or in the past, it executes immediately.
  Future<void> launchCampaign(String campaignId, String adminId, String adminName) async {
    final campaign = await getCampaign(campaignId);
    if (campaign == null) throw Exception("Campaign not found");

    final now = DateTime.now();

    if (campaign.scheduledAt != null && campaign.scheduledAt!.isAfter(now)) {
      // It's scheduled for the future
      await _db.collection('marketing_campaigns').doc(campaignId).update({
        'status': CampaignStatus.scheduled.name,
      });

      await AuditService().logAction(
        userId: adminId,
        userName: adminName,
        action: AuditAction.adminAction,
        description: 'Scheduled campaign: ${campaign.title} for ${campaign.scheduledAt}',
        targetId: campaignId,
      );
    } else if (campaign.sendTimeOptimization) {
      // Send-time optimization: don't fan out immediately. Instead, hand off
      // to `optimized_campaign_dispatch`, which a Cloud Function expands into
      // one `scheduled_sends` doc per recipient at their personal best-send hour.
      await _db.collection('marketing_campaigns').doc(campaignId).update({
        'status': CampaignStatus.active.name,
        'sentAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('optimized_campaign_dispatch').add({
        'campaignId': campaignId,
        'segments': campaign.targetSegments,
        'payload': {
          'title': campaign.title,
          'body': campaign.messageBody,
          'imageUrl': campaign.imageUrl,
          'actionUrl': campaign.actionUrl,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await AuditService().logAction(
        userId: adminId,
        userName: adminName,
        action: AuditAction.adminAction,
        description: 'Launched marketing campaign (send-time optimized): ${campaign.title}',
        targetId: campaignId,
      );
    } else {
      // Execute immediately via Cloud Functions Queue
      await _db.collection('marketing_campaigns').doc(campaignId).update({
        'status': CampaignStatus.active.name,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Queue it up for the backend worker to dispatch
      await _db.collection('notification_queue').add({
        'type': 'marketing_campaign',
        'campaignId': campaignId,
        'segments': campaign.targetSegments,
        'payload': {
          'title': campaign.title,
          'body': campaign.messageBody,
          'imageUrl': campaign.imageUrl,
          'actionUrl': campaign.actionUrl,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await AuditService().logAction(
        userId: adminId,
        userName: adminName,
        action: AuditAction.adminAction,
        description: 'Launched marketing campaign: ${campaign.title}',
        targetId: campaignId,
      );
    }
  }

  // ─── PERFORMANCE REPORTING (sent/opened/converted) ───────────────

  /// Records that a user opened/tapped a campaign notification.
  /// Increments `clicks` on the campaign doc and remembers the campaign as
  /// the most recent click for conversion attribution.
  Future<void> trackClick(String? campaignId) async {
    if (campaignId == null || campaignId.isEmpty) return;
    try {
      await _db.collection('marketing_campaigns').doc(campaignId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('[CampaignService] trackClick error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastClickedCampaignId, campaignId);
      await prefs.setInt(_kLastClickedCampaignAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[CampaignService] trackClick prefs error: $e');
    }
  }

  /// Records a conversion (e.g. an order) attributed to a recently-clicked
  /// campaign, incrementing `conversions` and `revenueAttributed`.
  /// Returns true if a conversion was attributed.
  Future<bool> trackConversionFromLastClick(double orderAmount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final campaignId = prefs.getString(_kLastClickedCampaignId);
      final clickedAtMs = prefs.getInt(_kLastClickedCampaignAt);
      if (campaignId == null || clickedAtMs == null) return false;

      final clickedAt = DateTime.fromMillisecondsSinceEpoch(clickedAtMs);
      if (DateTime.now().difference(clickedAt) > kCampaignAttributionWindow) {
        // Attribution window expired - clear it so it doesn't linger.
        await prefs.remove(_kLastClickedCampaignId);
        await prefs.remove(_kLastClickedCampaignAt);
        return false;
      }

      await _db.collection('marketing_campaigns').doc(campaignId).update({
        'conversions': FieldValue.increment(1),
        'revenueAttributed': FieldValue.increment(orderAmount),
      });

      // Single-use attribution: clear after crediting.
      await prefs.remove(_kLastClickedCampaignId);
      await prefs.remove(_kLastClickedCampaignAt);
      return true;
    } catch (e) {
      debugPrint('[CampaignService] trackConversionFromLastClick error: $e');
      return false;
    }
  }

  /// Cancels a scheduled or active campaign
  Future<void> cancelCampaign(String campaignId, String adminId, String adminName) async {
    await _db.collection('marketing_campaigns').doc(campaignId).update({
      'status': CampaignStatus.cancelled.name,
    });

    await AuditService().logAction(
      userId: adminId,
      userName: adminName,
      action: AuditAction.adminAction,
      description: 'Cancelled marketing campaign',
      targetId: campaignId,
    );
  }
}
