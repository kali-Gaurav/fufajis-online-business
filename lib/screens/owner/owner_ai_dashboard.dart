import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/business_forecast_model.dart';
import '../../models/inventory_recommendation_model.dart';
import '../../models/pricing_recommendation_model.dart';
import '../../models/branch_ai_score_model.dart';
import '../../models/marketing_campaign_model.dart';
import '../../models/delivery_intelligence_model.dart';
import '../../services/auto_reorder_service.dart';
import '../../services/pricing_advisor_service.dart';
import '../../services/marketing_ai_service.dart';
import '../../providers/owner_analytics_provider.dart';

import '../../utils/app_theme.dart';

class OwnerAiDashboard extends StatefulWidget {
  const OwnerAiDashboard({super.key});

  @override
  State<OwnerAiDashboard> createState() => _OwnerAiDashboardState();
}

class _OwnerAiDashboardState extends State<OwnerAiDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AutoReorderService _autoReorderService = AutoReorderService();
  final PricingAdvisorService _pricingAdvisorService = PricingAdvisorService();
  final MarketingAiService _marketingAiService = MarketingAiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Business Intelligence', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Consumer<OwnerAnalyticsProvider>(
        builder: (context, provider, child) {
          final String currentBranchId = provider.selectedBranchId ?? 'global';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBranchSelector(provider),
                const SizedBox(height: 24),
                _buildSectionTitle('AI Forecasts'),
                const SizedBox(height: 16),
                _buildForecastPanel(currentBranchId),
                const SizedBox(height: 32),
                _buildSectionTitle('AI Action Center (Inventory Reorders)'),
                const SizedBox(height: 16),
                _buildActionCenter(currentBranchId),
                const SizedBox(height: 32),
                _buildSectionTitle('Pricing Suggestions'),
                const SizedBox(height: 16),
                _buildPricingSuggestions(currentBranchId),
                const SizedBox(height: 32),
                _buildSectionTitle('Smart Marketing AI'),
                const SizedBox(height: 16),
                _buildMarketingSuggestions(currentBranchId),
                const SizedBox(height: 32),
                _buildSectionTitle('Delivery Intelligence'),
                const SizedBox(height: 16),
                _buildDeliveryIntelligence(currentBranchId),
                const SizedBox(height: 32),
                _buildSectionTitle('Branch Health AI Score'),
                const SizedBox(height: 16),
                _buildBranchHealth(currentBranchId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranchSelector(OwnerAnalyticsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.ownerAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.ownerAccent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analyzing Data For',
                style: TextStyle(fontSize: 12, color: AppTheme.grey600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                provider.selectedBranchId == null ? 'Global Operations' : 'Branch: ${provider.selectedBranchId}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.ownerAccent),
              ),
            ],
          ),
          Icon(
            Icons.store,
            size: 32,
            color: AppTheme.ownerAccent.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildForecastPanel(String branchId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('business_forecasts').doc(branchId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Forecast data is generating...')),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final forecast = BusinessForecastModel.fromMap(data);

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildForecastCard('Predicted Rev (7d)', '₹${forecast.predictedRevenue7Days.toStringAsFixed(0)}', Icons.trending_up, AppTheme.success),
                _buildForecastCard('Predicted Rev (30d)', '₹${forecast.predictedRevenue30Days.toStringAsFixed(0)}', Icons.attach_money, AppTheme.info),
                _buildForecastCard('Predicted Orders (7d)', '${forecast.predictedOrders7Days}', Icons.shopping_bag, AppTheme.warning),
                _buildForecastCard('Predicted Orders (30d)', '${forecast.predictedOrders30Days}', Icons.inventory, Colors.purple),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildForecastCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.05),
              AppTheme.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: AppTheme.grey600, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCenter(String branchId) {
    Query query = _firestore
        .collection('inventory_recommendations')
        .where('status', isEqualTo: InventoryRecommendationStatus.pending.name);

    if (branchId != 'global') {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: AppTheme.success),
                    SizedBox(height: 16),
                    Text('No pending auto-reorder approvals.', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        }

        final recommendations = snapshot.data!.docs.map((doc) => InventoryRecommendationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recommendations.length,
          itemBuilder: (context, index) {
            final rec = recommendations[index];
            return _buildActionCard(rec);
          },
        );
      },
    );
  }

  Widget _buildActionCard(InventoryRecommendationModel rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Predicted Low Stock: ${rec.productId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.error),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Action Required', style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _buildDetailCol('Current Stock', '${rec.currentStock}')),
                Expanded(child: _buildDetailCol('Predicted Demand', '${rec.predictedDemand}')),
                Expanded(child: _buildDetailCol('Recommended Qty', '${rec.recommendedOrderQty}')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Reason: ${rec.reason}', style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _handleReject(rec.id),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _handleApprove(rec.id),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                  child: const Text('Approve & Auto-Order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _handleApprove(String recommendationId) async {
    final ownerId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_owner';
    await _autoReorderService.approveRecommendation(recommendationId, ownerId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendation Approved. Purchase Request created.')));
    }
  }

  void _handleReject(String recommendationId) async {
    final ownerId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_owner';
    await _autoReorderService.rejectRecommendation(recommendationId, ownerId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendation Rejected.')));
    }
  }

  // ---- Pricing Suggestions (Phase 9B) ----
  Widget _buildPricingSuggestions(String branchId) {
    Query query = _firestore
        .collection('pricing_recommendations')
        .where('status', isEqualTo: PricingRecommendationStatus.pending.name);

    if (branchId != 'global') {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('No pricing suggestions at this time.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        }

        final recs = snapshot.data!.docs.map((doc) => PricingRecommendationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recs.length,
          itemBuilder: (ctx, index) {
            final rec = recs[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.price_change, color: AppTheme.info),
                title: Text('Adjust Price: ${rec.productId}'),
                subtitle: Text('Current: ₹${rec.currentPrice} → Suggested: ₹${rec.suggestedPrice}\nReason: ${rec.reason}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.error),
                      onPressed: () async {
                        await _pricingAdvisorService.rejectPricing(rec.id, FirebaseAuth.instance.currentUser?.uid ?? 'system');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: AppTheme.success),
                      onPressed: () async {
                        await _pricingAdvisorService.approvePricing(rec.id, FirebaseAuth.instance.currentUser?.uid ?? 'system');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price updated.')));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Branch Health (Phase 9E) ----
  Widget _buildBranchHealth(String branchId) {
    if (branchId == 'global') {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Select a specific branch to view its health score.')),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('branch_ai_scores').doc(branchId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('Health score is being calculated...')),
            ),
          );
        }

        final score = BranchAiScoreModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
        
        Color healthColor = AppTheme.success;
        if (score.healthScore < 70) healthColor = AppTheme.warning;
        if (score.healthScore < 50) healthColor = AppTheme.error;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: score.healthScore / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                      ),
                    ),
                    Text(
                      '${score.healthScore.toInt()}',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: healthColor),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHealthRow('Revenue Growth', '${score.revenueGrowth}%', score.revenueGrowth >= 0),
                      _buildHealthRow('Order Growth', '${score.orderGrowth}%', score.orderGrowth >= 0),
                      _buildHealthRow('Inventory Accuracy', '${score.inventoryAccuracy}%', score.inventoryAccuracy >= 90),
                      _buildHealthRow('Employee Productivity', '${score.employeeProductivity}%', score.employeeProductivity >= 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Icon(isGood ? Icons.arrow_upward : Icons.arrow_downward, color: isGood ? AppTheme.success : AppTheme.error, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Smart Marketing Manager (Phase 9C) ----
  Widget _buildMarketingSuggestions(String branchId) {
    Query query = _firestore
        .collection('marketing_campaigns')
        .where('status', isEqualTo: MarketingCampaignStatus.pending.name);

    if (branchId != 'global') {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: AppTheme.ownerAccent);
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No marketing campaigns pending.')));
        }

        final campaigns = snapshot.data!.docs.map((doc) => MarketingCampaignModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final c = campaigns[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.campaign, color: Colors.deepPurple),
                title: Text(c.title),
                subtitle: Text('${c.description}\nCost: ₹${c.estimatedCost} | Reach: ${c.estimatedReach} users'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.error),
                      onPressed: () => _marketingAiService.rejectCampaign(c.id, FirebaseAuth.instance.currentUser?.uid ?? 'sys'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: AppTheme.success),
                      onPressed: () => _marketingAiService.approveCampaign(c.id, FirebaseAuth.instance.currentUser?.uid ?? 'sys'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Delivery Intelligence (Phase 9D) ----
  Widget _buildDeliveryIntelligence(String branchId) {
    if (branchId == 'global') {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Select a specific branch for delivery intelligence.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('delivery_intelligence').doc(branchId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator(color: AppTheme.ownerAccent);
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Generating delivery intelligence...')));
        }

        final intel = DeliveryIntelligenceModel.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
        
        Color riskColor = AppTheme.success;
        if (intel.expectedDelayRisk == RiskLevel.medium) riskColor = AppTheme.warning;
        if (intel.expectedDelayRisk == RiskLevel.high) riskColor = Colors.deepOrange;
        if (intel.expectedDelayRisk == RiskLevel.critical) riskColor = AppTheme.error;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Delay Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Chip(
                      label: Text(intel.expectedDelayRisk.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: riskColor,
                    ),
                  ],
                ),
                const Divider(),
                if (intel.bottlenecks.isNotEmpty) ...[
                  const Text('Active Bottlenecks:', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                  ...intel.bottlenecks.map((b) => Text('• $b', style: const TextStyle(color: AppTheme.error))),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(child: _buildDetailCol('Peak Window', intel.peakWindow)),
                    Expanded(child: _buildDetailCol('Driver Utilization', '${intel.driverUtilization}%')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
