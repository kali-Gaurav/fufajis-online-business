import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/services/pricing_expert_service.dart';
import 'package:fufajis_online/models/pricing_models.dart';
import 'package:fufajis_online/widgets/mission_control/pricing_recommendation_card.dart';
import 'package:fufajis_online/utils/logger.dart';

/// Pricing Recommendations Screen
/// Displays all pending pricing expert recommendations for approval
class PricingRecommendationsScreen extends StatefulWidget {
  final String shopId;

  const PricingRecommendationsScreen({super.key, required this.shopId});

  @override
  State<PricingRecommendationsScreen> createState() => _PricingRecommendationsScreenState();
}

class _PricingRecommendationsScreenState extends State<PricingRecommendationsScreen> {
  late PricingExpertService pricingService;
  List<PricingRecommendation> recommendations = [];
  bool isLoading = true;
  String filterStatus = 'PENDING'; // PENDING, APPROVED, REJECTED, ALL

  @override
  void initState() {
    super.initState();
    pricingService = context.read<PricingExpertService>();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      setState(() => isLoading = true);

      final recs = await pricingService.getPendingRecommendations();

      setState(() {
        recommendations = recs;
        isLoading = false;
      });

      Logger.info('Loaded ${recs.length} pricing recommendations');
    } catch (e) {
      Logger.error('Error loading recommendations: $e');
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recommendations: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleApprove(PricingRecommendation rec, {double? overridePrice}) async {
    try {
      final success = await pricingService.approveRecommendation(
        rec.id,
        overridePrice: overridePrice,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recommendation approved and applied'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await _loadRecommendations();
      }
    } catch (e) {
      Logger.error('Error approving recommendation: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleReject(PricingRecommendation rec) async {
    final reason = await _showRejectDialog();

    if (reason != null) {
      try {
        final success = await pricingService.rejectRecommendation(rec.id, reason: reason);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Recommendation rejected'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          await _loadRecommendations();
        }
      } catch (e) {
        Logger.error('Error rejecting recommendation: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Recommendation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you rejecting this recommendation? This helps improve the agent.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.isNotEmpty ? controller.text : 'No reason provided',
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Pricing Recommendations'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecommendations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recommendations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No pending recommendations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New recommendations will appear here',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecommendations,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final rec = recommendations[index];
                  return PricingRecommendationCard(
                    recommendation: rec,
                    onApprove: () => _handleApprove(rec),
                    onApproveWithEdit: (price) => _handleApprove(rec, overridePrice: price),
                    onReject: () => _handleReject(rec),
                  );
                },
              ),
            ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
