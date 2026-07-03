import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../models/permission_model.dart';
import '../../models/user_model.dart';
import '../../services/rbac_service.dart';
import '../../repositories/postgres_analytics_repository.dart';
import '../../utils/app_theme.dart';

/// Owner-facing view over the new Postgres/Supabase materialized-view
/// analytics (`sales_analytics`, `vendor_analytics`, `delivery_analytics`).
///
/// This is intentionally separate from [BiAnalyticsHubScreen], which reads
/// from the older Firestore-based BusinessIntelligenceProvider. Gated by
/// the `viewSalesAnalytics` / `viewVendorAnalytics` / `viewDeliveryAnalytics`
/// permissions.
class PostgresAnalyticsScreen extends StatefulWidget {
  const PostgresAnalyticsScreen({super.key});

  @override
  State<PostgresAnalyticsScreen> createState() => _PostgresAnalyticsScreenState();
}

class _PostgresAnalyticsScreenState extends State<PostgresAnalyticsScreen> {
  final PostgresAnalyticsRepository _repo = PostgresAnalyticsRepository();
  final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  bool _loading = true;
  String? _error;

  SalesAnalyticsSummary? _sales;
  Map<String, dynamic>? _vendor;
  DeliveryAnalyticsSummary? _delivery;

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final role = user?.role;
    final rbac = RBACService();

    try {
      final canSales = role != null && rbac.hasPermission(role, Permission.viewSalesAnalytics);
      final canVendor = role != null && rbac.hasPermission(role, Permission.viewVendorAnalytics);
      final canDelivery =
          role != null && rbac.hasPermission(role, Permission.viewDeliveryAnalytics);

      final sales = canSales ? await _repo.getSalesAnalytics(from: _from, to: _to) : null;
      final vendor = (canVendor && role == UserRole.supplier && user?.uid != null)
          ? await _repo.getVendorAnalytics(user!.uid)
          : null;
      final delivery = canDelivery ? await _repo.getDeliveryAnalytics(from: _from, to: _to) : null;

      if (!mounted) return;
      setState(() {
        _sales = sales;
        _vendor = vendor;
        _delivery = delivery;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load analytics: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.currentUser?.role;
    final rbac = RBACService();

    final hasAnyAccess =
        role != null &&
        rbac.hasAnyPermission(role, [
          Permission.viewSalesAnalytics,
          Permission.viewVendorAnalytics,
          Permission.viewDeliveryAnalytics,
          Permission.viewBranchAnalytics,
        ]);

    if (!hasAnyAccess) {
      return Scaffold(
        backgroundColor: AppTheme.grey50,
        appBar: AppBar(title: const Text('Backend Analytics')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "You don't have permission to view this dashboard.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Backend Analytics', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
            tooltip: 'Change date range',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM yyyy').format(_to)}',
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (_sales != null) ..._buildSalesSection(role),
                  if (_vendor != null) ..._buildVendorSection(),
                  if (_delivery != null) ..._buildDeliverySection(role),
                  _buildQueryPerformancePanel(),
                  if (_sales == null && _vendor == null && _delivery == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No analytics data available for your role yet.')),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildSalesSection(UserRole role) {
    final s = _sales!;
    return [
      _sectionTitle('Sales (Postgres)'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _kpiCard(
            'Total Revenue',
            _inr.format(s.totalRevenue),
            Icons.payments_outlined,
            AppTheme.primary,
          ),
          _kpiCard('Total Profit', _inr.format(s.totalProfit), Icons.trending_up, AppTheme.success),
          _kpiCard('Orders', '${s.totalOrders}', Icons.receipt_long_outlined, AppTheme.info),
          _kpiCard('Data Rows', '${s.rows.length}', Icons.table_chart_outlined, AppTheme.warning),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildVendorSection() {
    final v = _vendor!;
    return [
      _sectionTitle('My Vendor Performance'),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.grey100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: () {
              final entries = v.entries.toList();
              return List.generate(entries.length, (index) {
                final e = entries[index];
                final String key = e.key.toString().replaceAll('_', ' ').toUpperCase();
                final String val = e.value.toString();
                final isLast = index == entries.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(bottom: BorderSide(color: AppTheme.grey100, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey600,
                        ),
                      ),
                      Text(
                        val,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey900,
                        ),
                      ),
                    ],
                  ),
                );
              });
            }(),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildDeliverySection(UserRole role) {
    final d = _delivery!;
    return [
      _sectionTitle('Delivery Performance (Postgres)'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _kpiCard(
            'Total Deliveries',
            '${d.totalDeliveries}',
            Icons.local_shipping_outlined,
            AppTheme.primary,
          ),
          _kpiCard(
            'Avg Delivery Time',
            '${d.avgDeliveryMinutes.toStringAsFixed(1)} min',
            Icons.timer_outlined,
            AppTheme.info,
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.ownerAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.grey900.withValues(alpha: 0.03),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.grey100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryPerformancePanel() {
    final latencies = _repo.queryLatencies;
    if (latencies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Postgres Query Performance'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.grey100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: latencies.entries.map((entry) {
                final latency = entry.value;
                String status = 'Excellent';
                Color color = AppTheme.success;
                double latencyRatio = (latency / 500.0).clamp(0.0, 1.0);

                if (latency > 300) {
                  status = 'Slow';
                  color = AppTheme.error;
                } else if (latency > 100) {
                  status = 'Good';
                  color = AppTheme.warning;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.speed_outlined, size: 20, color: AppTheme.grey500),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${latency.toStringAsFixed(0)} ms',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.grey900,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: latencyRatio,
                          minHeight: 4,
                          backgroundColor: AppTheme.grey100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
