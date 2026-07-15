import 'package:flutter/material.dart';
import '../../services/smart_analytics_service.dart';
import '../../utils/app_theme.dart';

/// Task #72 — Customer Segmentation Dashboard
/// Shows VIP / At-Risk / Dormant segments by wiring SmartAnalyticsService.
/// Action buttons: Send Campaign, Offer Discount, Export List.
class CustomerSegmentationScreen extends StatefulWidget {
  const CustomerSegmentationScreen({super.key});

  @override
  State<CustomerSegmentationScreen> createState() => _CustomerSegmentationScreenState();
}

class _CustomerSegmentationScreenState extends State<CustomerSegmentationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  List<Map<String, dynamic>> _winBackList = [];
  List<Map<String, dynamic>> _churnRiskList = [];
  List<Map<String, dynamic>> _vipList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSegments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSegments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SmartAnalyticsService();
      final winBack = await svc.getWinBackSegmentList(daysSinceLastOrder: 30);
      final churn = await svc.predictChurnRiskList(thresholdScore: 0.6);
      final vip = await svc.getVipCustomersList(minLifetimeValue: 5000);

      if (mounted) {
        setState(() {
          _winBackList = winBack;
          _churnRiskList = churn;
          _vipList = vip;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Segments', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSegments)],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'At-Risk (${_churnRiskList.length})'),
            Tab(text: 'Win-Back (${_winBackList.length})'),
            Tab(text: 'VIP (${_vipList.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _loadSegments, child: const Text('Retry')),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _SegmentListView(
                  customers: _churnRiskList,
                  chipLabel: 'Churn Risk',
                  chipColor: AppTheme.error.withOpacity(0.15),
                  chipTextColor: AppTheme.error,
                  actionLabel: 'Send Offer',
                  actionIcon: Icons.local_offer_outlined,
                  onAction: (c) => _sendCampaign(context, c, 'churn_prevention'),
                ),
                _SegmentListView(
                  customers: _winBackList,
                  chipLabel: 'Dormant',
                  chipColor: AppTheme.primaryLight,
                  chipTextColor: AppTheme.warning,
                  actionLabel: 'Win Back',
                  actionIcon: Icons.campaign_outlined,
                  onAction: (c) => _sendCampaign(context, c, 'win_back'),
                ),
                _SegmentListView(
                  customers: _vipList,
                  chipLabel: 'VIP',
                  chipColor: Colors.purple.shade100,
                  chipTextColor: Colors.purple.shade800,
                  actionLabel: 'Reward',
                  actionIcon: Icons.star_outline,
                  onAction: (c) => _sendCampaign(context, c, 'vip_reward'),
                ),
              ],
            ),
    );
  }

  Future<void> _sendCampaign(
    BuildContext context,
    Map<String, dynamic> customer,
    String campaignType,
  ) async {
    try {
      await SmartAnalyticsService().triggerCampaignForCustomer(
        customerId: customer['userId'] ?? customer['id'] ?? '',
        campaignType: campaignType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campaign sent to ${customer['name'] ?? 'customer'}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}

class _SegmentListView extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  final String chipLabel;
  final Color chipColor;
  final Color chipTextColor;
  final String actionLabel;
  final IconData actionIcon;
  final void Function(Map<String, dynamic>) onAction;

  const _SegmentListView({
    required this.customers,
    required this.chipLabel,
    required this.chipColor,
    required this.chipTextColor,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No $chipLabel customers', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      itemBuilder: (ctx, i) {
        final c = customers[i];
        final name = c['name'] ?? c['displayName'] ?? 'Customer';
        final email = c['email'] ?? '';
        final ltv = (c['lifetimeValue'] ?? c['totalSpend'] ?? 0.0);
        final orders = c['totalOrders'] ?? c['orderCount'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: chipColor,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: chipTextColor, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email.isNotEmpty)
                  Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: chipTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${(ltv as num).toStringAsFixed(0)} · $orders orders',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: TextButton.icon(
              icon: Icon(actionIcon, size: 14),
              label: Text(actionLabel, style: const TextStyle(fontSize: 12)),
              onPressed: () => onAction(c),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
