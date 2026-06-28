import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboardMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Global System Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.fetchDashboardMetrics(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Statistics'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Metrics Row
            Row(
              children: [
                _buildMetricsCard('System Revenue', '₹${adminProvider.totalRevenue.toStringAsFixed(0)}', AppTheme.success, Icons.monetization_on),
                const SizedBox(width: 16),
                _buildMetricsCard('Active Shops', '${adminProvider.totalShops}', AppTheme.warning, Icons.store),
                const SizedBox(width: 16),
                _buildMetricsCard('Registered Users', '${adminProvider.totalUsers}', AppTheme.info, Icons.people),
              ],
            ),
            const SizedBox(height: 24),
            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildRevenueChart(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildCategoryDistributionCard(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTopShopsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.grey500, fontSize: 14)),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Revenue Trend (Monthly)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.grey100, strokeWidth: 1),
                  getDrawingVerticalLine: (value) => const FlLine(color: AppTheme.grey100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1.5),
                      FlSpot(1, 3.2),
                      FlSpot(2, 2.8),
                      FlSpot(3, 4.5),
                      FlSpot(4, 5.8),
                      FlSpot(5, 7.2),
                    ],
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionCard() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Sales Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(color: AppTheme.success, value: 40, title: '40%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(color: AppTheme.warning, value: 30, title: '30%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(color: AppTheme.info, value: 15, title: '15%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  PieChartSectionData(color: Colors.purple, value: 15, title: '15%', radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendRow(AppTheme.success, 'Vegetables & Fruits'),
          _buildLegendRow(AppTheme.warning, 'Groceries & Spices'),
          _buildLegendRow(AppTheme.info, 'Dairy Products'),
          _buildLegendRow(Colors.purple, 'Others'),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey700)),
        ],
      ),
    );
  }

  Widget _buildTopShopsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Performing Vendors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1),
            },
            children: [
              _buildTableHeader(),
              _buildTableRow('1', "Fufaji's Main Grocery", 'Jaipur Central', '₹1,45,000'),
              _buildTableRow('2', 'Sharma Sweets & Dairy', 'Mansarovar', '₹92,400'),
              _buildTableRow('3', 'Verma Organic Farms', 'Vaishali Nagar', '₹63,200'),
              _buildTableRow('4', 'District Fruit Depot', 'Malviya Nagar', '₹41,900'),
            ],
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeader() {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.grey200, width: 1))),
      children: [
        _buildTableCell('Rank', isHeader: true),
        _buildTableCell('Shop Name', isHeader: true),
        _buildTableCell('Location', isHeader: true),
        _buildTableCell('Sales volume', isHeader: true),
      ],
    );
  }

  TableRow _buildTableRow(String rank, String name, String location, String sales) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.grey100, width: 1))),
      children: [
        _buildTableCell(rank),
        _buildTableCell(name),
        _buildTableCell(location),
        _buildTableCell(sales, textStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false, TextStyle? textStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: textStyle ?? TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? AppTheme.grey900 : AppTheme.grey700,
        ),
      ),
    );
  }
}
