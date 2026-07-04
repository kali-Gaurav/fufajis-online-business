import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/services/customer_analyst_service.dart';
import 'package:fufajis_online/models/customer_models.dart';
import 'package:fufajis_online/widgets/mission_control/churn_alert_card.dart';
import 'package:fufajis_online/widgets/mission_control/customer_segment_card.dart';
import 'package:fufajis_online/widgets/mission_control/feedback_synthesis_card.dart';
import 'package:fufajis_online/utils/logger.dart';

/// Customer Insights Screen
/// Displays customer segments, churn alerts, and feedback synthesis
class CustomerInsightsScreen extends StatefulWidget {
  final String shopId;

  const CustomerInsightsScreen({super.key, required this.shopId});

  @override
  State<CustomerInsightsScreen> createState() => _CustomerInsightsScreenState();
}

class _CustomerInsightsScreenState extends State<CustomerInsightsScreen> {
  late CustomerAnalystService analyzerService;
  List<CustomerSegment> segments = [];
  List<ChurnAlert> churnAlerts = [];
  FeedbackSynthesis? feedbackSynthesis;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    analyzerService = context.read<CustomerAnalystService>();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      setState(() => isLoading = true);

      // Load all insights in parallel
      final segmentsResult = analyzerService.generateWeeklySegments();
      final churnsResult = analyzerService.generateChurnAlerts();
      final feedbackResult = analyzerService.synthesizeFeedback();

      final results = await Future.wait([segmentsResult, churnsResult, feedbackResult]);

      setState(() {
        segments = results[0] as List<CustomerSegment>;
        churnAlerts = results[1] as List<ChurnAlert>;
        feedbackSynthesis = results[2] as FeedbackSynthesis?;
        isLoading = false;
      });

      Logger.info(
        'Loaded insights: ${segments.length} segments, ${churnAlerts.length} churn alerts',
      );
    } catch (e) {
      Logger.error('Error loading insights: $e');
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading insights: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleChurnAction(ChurnAlert alert, String action) async {
    try {
      // In production, call service to mark action as taken
      Logger.info('Churn action: $action for ${alert.customerId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action recorded: $action'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      Logger.error('Error handling churn action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📊 Customer Insights'),
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people, size: 20),
                    const SizedBox(height: 4),
                    Text('Segments (${segments.length})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber, size: 20),
                    const SizedBox(height: 4),
                    Text('Churn (${churnAlerts.length})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.comment, size: 20),
                    SizedBox(height: 4),
                    Text('Feedback', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInsights,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // ============ SEGMENTS TAB ============
                  _buildSegmentsTab(),

                  // ============ CHURN ALERTS TAB ============
                  _buildChurnTab(),

                  // ============ FEEDBACK SYNTHESIS TAB ============
                  _buildFeedbackTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildSegmentsTab() {
    if (segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No customer segments yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Run analysis to generate segments', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final segment = segments[index];
          return CustomerSegmentCard(segment: segment);
        },
      ),
    );
  }

  Widget _buildChurnTab() {
    if (churnAlerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No churn alerts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Your customers are healthy!', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    // Sort by risk level (critical first)
    final sortedAlerts = List<ChurnAlert>.from(churnAlerts)
      ..sort((a, b) {
        const riskOrder = {'CRITICAL': 0, 'AT_RISK': 1, 'LOW': 2};
        return (riskOrder[a.riskLevel] ?? 99).compareTo(riskOrder[b.riskLevel] ?? 99);
      });

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedAlerts.length,
        itemBuilder: (context, index) {
          final alert = sortedAlerts[index];
          return ChurnAlertCard(
            alert: alert,
            onAction: (action) => _handleChurnAction(alert, action),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackTab() {
    if (feedbackSynthesis == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No feedback yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Feedback will appear once reviews are available',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [FeedbackSynthesisCard(synthesis: feedbackSynthesis!)],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
