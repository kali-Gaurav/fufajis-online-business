import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../services/profit_service.dart';

/// Profit Calculation Dashboard for shopkeepers
///
/// Displays comprehensive profit metrics including:
/// - Gross Revenue
/// - COGS (Cost of Goods Sold)
/// - Platform Commission (10%)
/// - Refunds
/// - Net Profit with color coding (green/red)
/// - Profit Margin Percentage
class ProfitDashboardScreen extends StatefulWidget {
  const ProfitDashboardScreen({super.key});

  @override
  State<ProfitDashboardScreen> createState() => _ProfitDashboardScreenState();
}

class _ProfitDashboardScreenState extends State<ProfitDashboardScreen> {
  final ProfitService _profitService = ProfitService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _currentShopId;
  late String _selectedRange;
  ProfitMetrics? _metrics;
  String? _errorMessage;
  bool _isLoading = false;

  final List<String> _dateRanges = ['today', 'week', 'month', 'year', 'all'];
  late Map<String, String> _dateRangeLabels;

  @override
  void initState() {
    super.initState();
    _selectedRange = 'month';
    _dateRangeLabels = {
      'today': 'Today',
      'week': 'This Week',
      'month': 'This Month',
      'year': 'This Year',
      'all': 'All Time',
    };

    _initializeAndLoadData();
  }

  /// Initialize shop ID and load profit metrics
  Future<void> _initializeAndLoadData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'You are not logged in. Please login again.';
          _isLoading = false;
        });
        return;
      }

      // Get the shopId from the user's custom claims or from the owners collection
      String? shopId;

      // Try to get shopId from custom claims first
      final idTokenResult = await user.getIdTokenResult();
      shopId = idTokenResult.claims?['shopId'] as String?;

      // If not in claims, query the owners collection
      if (shopId == null || shopId.isEmpty) {
        final ownerDoc = await _firestore
            .collection('owners')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (ownerDoc.docs.isNotEmpty) {
          shopId = ownerDoc.docs.first.data()['shopId'] as String?;
        }
      }

      // If still no shopId, query the shops collection directly
      if (shopId == null || shopId.isEmpty) {
        final shopDocs = await _firestore
            .collection('shops')
            .where('ownerId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (shopDocs.docs.isNotEmpty) {
          shopId = shopDocs.docs.first.id;
        }
      }

      if (shopId == null || shopId.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to find your shop. Please contact support.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentShopId = shopId!;
      });

      await _loadProfitMetrics();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Load profit metrics for the selected date range
  Future<void> _loadProfitMetrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final metrics = await _profitService.getProfitMetricsForRange(_currentShopId, _selectedRange);

      setState(() {
        _metrics = metrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profit data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Update selected date range and reload metrics
  Future<void> _onRangeChanged(String? newRange) async {
    if (newRange != null) {
      setState(() {
        _selectedRange = newRange;
      });
      await _loadProfitMetrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Profit Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 1,
      ),
      body: _isLoading && _metrics == null
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _metrics != null
          ? _buildContent(context)
          : _buildEmptyState(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadProfitMetrics,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppTheme.grey700),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadProfitMetrics, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Build empty state (no data)
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.grey400),
          SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(fontSize: 18, color: AppTheme.grey700, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'No delivered orders in the selected period',
            style: TextStyle(fontSize: 14, color: AppTheme.grey600),
          ),
        ],
      ),
    );
  }

  /// Build main content
  Widget _buildContent(BuildContext context) {
    final metrics = _metrics!;

    return RefreshIndicator(
      onRefresh: _loadProfitMetrics,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date range selector
          _buildDateRangeSelector(),
          const SizedBox(height: 20),

          // Summary cards
          _buildMetricCard(
            label: 'Gross Revenue',
            value: _formatCurrency(metrics.grossRevenue),
            icon: Icons.trending_up,
            color: AppTheme.info,
            subtitle: '${metrics.ordersProcessed} orders processed',
          ),
          const SizedBox(height: 12),

          // COGS card
          _buildMetricCard(
            label: 'Cost of Goods Sold',
            value: _formatCurrency(metrics.cogs),
            icon: Icons.production_quantity_limits,
            color: AppTheme.warning,
            isNegative: true,
          ),
          const SizedBox(height: 12),

          // Platform commission card
          _buildMetricCard(
            label: 'Platform Commission',
            value: _formatCurrency(metrics.commissions),
            icon: Icons.percent,
            color: AppTheme.grey600,
            subtitle: '10% of gross revenue',
            isNegative: true,
          ),
          const SizedBox(height: 12),

          // Refunds card
          if (metrics.refunds > 0)
            Column(
              children: [
                _buildMetricCard(
                  label: 'Refunds',
                  value: _formatCurrency(metrics.refunds),
                  icon: Icons.undo,
                  color: AppTheme.error,
                  isNegative: true,
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Divider
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 2,
            color: AppTheme.grey300,
          ),

          // Net Profit card - highlighted
          _buildNetProfitCard(metrics),
          const SizedBox(height: 12),

          // Profit Margin card
          _buildMetricCard(
            label: 'Profit Margin',
            value: '${metrics.profitMarginPercentage.toStringAsFixed(2)}%',
            icon: Icons.assessment,
            color: metrics.profitMarginPercentage >= 0 ? AppTheme.success : AppTheme.error,
            subtitle: 'Profit / Gross Revenue',
          ),
          const SizedBox(height: 20),

          // Date range info
          _buildDateRangeInfo(metrics),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build date range selector dropdown
  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey300),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.white,
      ),
      child: DropdownButton<String>(
        value: _selectedRange,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: _dateRanges.map((range) {
          return DropdownMenuItem(value: range, child: Text(_dateRangeLabels[range] ?? range));
        }).toList(),
        onChanged: _onRangeChanged,
      ),
    );
  }

  /// Build a standard metric card
  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    bool isNegative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.grey200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (isNegative ? '- ' : '') + value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isNegative ? AppTheme.error : color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
          ],
        ],
      ),
    );
  }

  /// Build highlighted net profit card
  Widget _buildNetProfitCard(ProfitMetrics metrics) {
    final isPositive = metrics.netProfit >= 0;
    final bgColor = isPositive
        ? AppTheme.success.withValues(alpha: 0.1)
        : AppTheme.error.withValues(alpha: 0.1);
    final textColor = isPositive ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'NET PROFIT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(metrics.netProfit),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            isPositive ? 'Profitable' : 'Loss',
            style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Build date range information footer
  Widget _buildDateRangeInfo(ProfitMetrics metrics) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.grey100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Date Range', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
              Text(
                '${dateFormat.format(metrics.startDate)} - ${dateFormat.format(metrics.endDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey800,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Orders', style: TextStyle(fontSize: 12, color: AppTheme.grey600)),
              Text(
                metrics.ordersProcessed.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format value as currency in Indian Rupees
  String _formatCurrency(double amount) {
    final formatter = NumberFormat('₹#,##,##0.00', 'en_IN');
    return formatter.format(amount.abs());
  }
}
