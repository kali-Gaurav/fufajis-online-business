import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_theme.dart';

class OwnerDashboardRedesigned extends StatefulWidget {
  const OwnerDashboardRedesigned({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardRedesigned> createState() =>
      _OwnerDashboardRedesignedState();
}

class _OwnerDashboardRedesignedState extends State<OwnerDashboardRedesigned> {
  final _supabase = Supabase.instance;
  bool _isLoading = true;
  DashboardMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _loadDashboardMetrics();
  }

  Future<void> _loadDashboardMetrics() async {
    setState(() => _isLoading = true);
    try {
      // Simulate loading metrics - in real app, fetch from backend
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _metrics = DashboardMetrics(
          totalRevenue: 125420.50,
          revenueGrowth: 12.5,
          totalOrders: 3847,
          ordersGrowth: 8.3,
          activeCustomers: 2450,
          customersGrowth: 5.2,
          supplierPayments: 89200.00,
          paymentsPending: 12500.00,
          inventoryItems: 1250,
          lowStockItems: 34,
          averageOrderValue: 32.60,
          orderFulfillmentRate: 98.5,
          customerSatisfaction: 4.6,
          employeesOnDuty: 12,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardMetrics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _metrics == null
              ? Center(
                  child: Text(
                    'Failed to load metrics',
                    style: TextStyle(color: Colors.red[600]),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildKeyMetricsGrid(),
                      const SizedBox(height: 24),
                      _buildHealthIndicators(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildAlertsBanner(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWelcomeCard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
            ? 'Good Afternoon'
            : 'Good Evening';

    return Card(
      elevation: 0,
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting + '! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Let\'s see how your business is doing',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Icon(
              Icons.trending_up,
              size: 40,
              color: Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Metrics',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Revenue',
              '₹${_metrics!.totalRevenue.toStringAsFixed(0)}',
              '${_metrics!.revenueGrowth > 0 ? '+' : ''}${_metrics!.revenueGrowth.toStringAsFixed(1)}%',
              Colors.blue,
              Icons.trending_up,
              () => _drillDownRevenue(),
            ),
            _buildMetricCard(
              'Orders',
              _metrics!.totalOrders.toString(),
              '${_metrics!.ordersGrowth > 0 ? '+' : ''}${_metrics!.ordersGrowth.toStringAsFixed(1)}%',
              Colors.green,
              Icons.shopping_cart,
              () => _drillDownOrders(),
            ),
            _buildMetricCard(
              'Customers',
              _metrics!.activeCustomers.toString(),
              '${_metrics!.customersGrowth > 0 ? '+' : ''}${_metrics!.customersGrowth.toStringAsFixed(1)}%',
              Colors.purple,
              Icons.people,
              () => _drillDownCustomers(),
            ),
            _buildMetricCard(
              'Avg Order',
              '₹${_metrics!.averageOrderValue.toStringAsFixed(2)}',
              'per order',
              Colors.orange,
              Icons.receipt,
              () => _drillDownMetrics(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String subtitle,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.grey600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthIndicators() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business Health',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildHealthIndicator(
                'Fulfillment',
                _metrics!.orderFulfillmentRate,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHealthIndicator(
                'Satisfaction',
                (_metrics!.customerSatisfaction / 5) * 100,
                Colors.blue,
                showRating: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthIndicator(
    String label,
    double percentage,
    Color color, {
    bool showRating = false,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.grey700,
                  ),
                ),
                Text(
                  showRating
                      ? '${_metrics!.customerSatisfaction.toStringAsFixed(1)}/5'
                      : '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Orders',
                Icons.receipt_long,
                Colors.blue,
                () {
                  // Navigate to orders
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Inventory',
                Icons.inventory_2,
                Colors.orange,
                () {
                  // Navigate to inventory
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Employees',
                Icons.badge,
                Colors.purple,
                () {
                  // Navigate to employees
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Payments',
                Icons.payment,
                Colors.green,
                () {
                  // Navigate to payments
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: color.withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsBanner() {
    final hasAlerts = _metrics!.lowStockItems > 0 ||
        _metrics!.paymentsPending > 0 ||
        _metrics!.employeesOnDuty < 8;

    if (!hasAlerts) {
      return SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange[600], size: 20),
              const SizedBox(width: 12),
              const Text(
                'Attention Required',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_metrics!.lowStockItems > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_metrics!.lowStockItems} items running low on stock',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                  ),
                ],
              ),
            ),
          if (_metrics!.paymentsPending > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    '₹${_metrics!.paymentsPending.toStringAsFixed(0)} payments pending',
                    style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                  ),
                ],
              ),
            ),
          if (_metrics!.employeesOnDuty < 8)
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Only ${_metrics!.employeesOnDuty} employees on duty',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _drillDownRevenue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to Revenue Analytics...')),
    );
  }

  void _drillDownOrders() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to Orders...')),
    );
  }

  void _drillDownCustomers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to Customers...')),
    );
  }

  void _drillDownMetrics() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigating to Detailed Metrics...')),
    );
  }
}

class DashboardMetrics {
  final double totalRevenue;
  final double revenueGrowth;
  final int totalOrders;
  final double ordersGrowth;
  final int activeCustomers;
  final double customersGrowth;
  final double supplierPayments;
  final double paymentsPending;
  final int inventoryItems;
  final int lowStockItems;
  final double averageOrderValue;
  final double orderFulfillmentRate;
  final double customerSatisfaction;
  final int employeesOnDuty;

  DashboardMetrics({
    required this.totalRevenue,
    required this.revenueGrowth,
    required this.totalOrders,
    required this.ordersGrowth,
    required this.activeCustomers,
    required this.customersGrowth,
    required this.supplierPayments,
    required this.paymentsPending,
    required this.inventoryItems,
    required this.lowStockItems,
    required this.averageOrderValue,
    required this.orderFulfillmentRate,
    required this.customerSatisfaction,
    required this.employeesOnDuty,
  });
}
