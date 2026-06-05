import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/app_theme.dart';
import '../../services/order_service.dart';
import '../../models/order_model.dart';
import '../../providers/product_provider.dart';
import '../../widgets/owner/broadcast_promo_manager.dart';
import 'package:provider/provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];
  final OrderService _orderService = OrderService();

  int _analyticsTab = 0; // 0 = Metrics, 1 = Postcode Heatmaps
  int _mapMode = 0; // 0 = Interactive Vector Grid, 1 = Google Maps Live
  String _searchQuery = '';
  String _selectedDensityFilter = 'All'; // All, High, Medium, Low

  // Active highlighted postcode in the inspector
  Map<String, dynamic>? _selectedPostcode;

  // Postcode zone models with realistic coordinates (Jaipur region base coordinates: 26.9124, 75.7873)
  final List<Map<String, dynamic>> _postcodeZones = [
    {
      'zip': '302020',
      'name': 'Mansarovar Zone',
      'lat': 26.8584,
      'lng': 75.7615,
      'ordersCount': 45,
      'revenue': 18450.0,
      'avgDeliveryMins': 28,
      'satisfaction': 4.8,
      'ridersCount': 4,
      'topCategory': 'Groceries',
      'density': 'High',
    },
    {
      'zip': '302017',
      'name': 'Malviya Nagar Zone',
      'lat': 26.8530,
      'lng': 75.8047,
      'ordersCount': 38,
      'revenue': 14800.0,
      'avgDeliveryMins': 32,
      'satisfaction': 4.7,
      'ridersCount': 3,
      'topCategory': 'Dairy',
      'density': 'High',
    },
    {
      'zip': '302021',
      'name': 'Vaishali Nagar Zone',
      'lat': 26.9074,
      'lng': 75.7380,
      'ordersCount': 29,
      'revenue': 9200.0,
      'avgDeliveryMins': 35,
      'satisfaction': 4.5,
      'ridersCount': 2,
      'topCategory': 'Vegetables',
      'density': 'Medium',
    },
    {
      'zip': '302015',
      'name': 'Tonk Road Zone',
      'lat': 26.8214,
      'lng': 75.7980,
      'ordersCount': 22,
      'revenue': 7800.0,
      'avgDeliveryMins': 40,
      'satisfaction': 4.2,
      'ridersCount': 2,
      'topCategory': 'Groceries',
      'density': 'Medium',
    },
    {
      'zip': '302001',
      'name': 'C-Scheme Town Hub',
      'lat': 26.9160,
      'lng': 75.8010,
      'ordersCount': 14,
      'revenue': 5400.0,
      'avgDeliveryMins': 22,
      'satisfaction': 4.9,
      'ridersCount': 1,
      'topCategory': 'Fruits',
      'density': 'Low',
    },
    {
      'zip': '302025',
      'name': 'Jagatpura Outskirts',
      'lat': 26.8222,
      'lng': 75.8643,
      'ordersCount': 8,
      'revenue': 3100.0,
      'avgDeliveryMins': 52,
      'satisfaction': 3.9,
      'ridersCount': 1,
      'topCategory': 'Household',
      'density': 'Low',
    }
  ];

  @override
  void initState() {
    super.initState();
    // Default select Mansarovar
    _selectedPostcode = _postcodeZones[0];
  }

  // Period filtering helper
  List<OrderModel> _filterOrders(List<OrderModel> orders, String period) {
    final now = DateTime.now();
    return orders.where((order) {
      final orderDate = order.createdAt;
      switch (period) {
        case 'Today':
          return orderDate.year == now.year &&
              orderDate.month == now.month &&
              orderDate.day == now.day;
        case 'This Week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return orderDate.isAfter(weekAgo);
        case 'This Month':
          return orderDate.year == now.year && orderDate.month == now.month;
        case 'All Time':
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getAllOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final allOrders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(allOrders, _periods[_selectedPeriod]);

        // 1. Calculations
        double totalRevenue = 0.0;
        final Set<String> uniqueCustomers = {};
        final Map<String, int> productSalesCount = {};
        final Map<String, double> productRevenue = {};
        final Map<String, double> categorySales = {};

        for (var order in filteredOrders) {
          if (order.status == OrderStatus.delivered) {
            totalRevenue += order.totalAmount;
          }
          uniqueCustomers.add(order.customerId);

          for (var item in order.items) {
            productSalesCount[item.productName] = (productSalesCount[item.productName] ?? 0) + item.quantity;
            productRevenue[item.productName] = (productRevenue[item.productName] ?? 0.0) + item.totalPrice;

            String category = _guessCategory(item.productName);
            categorySales[category] = (categorySales[category] ?? 0.0) + item.totalPrice;
          }
        }

        final int totalOrdersCount = filteredOrders.length;
        final double avgOrderValue = totalOrdersCount > 0 ? (totalRevenue / totalOrdersCount) : 0.0;
        final int totalCustomersCount = uniqueCustomers.length;

        // Top Products list
        final sortedProducts = productSalesCount.keys.toList()
          ..sort((a, b) => productSalesCount[b]!.compareTo(productSalesCount[a]!));
        final topProducts = sortedProducts.take(4).map((name) {
          final revenue = productRevenue[name] ?? 0.0;
          final sales = productSalesCount[name] ?? 0;
          return {
            'name': name,
            'sales': sales,
            'revenue': '₹${revenue.toStringAsFixed(0)}',
            'growth': '+${(sales * 2.5).toStringAsFixed(0)}%'
          };
        }).toList();

        return Scaffold(
          backgroundColor: AppTheme.grey50,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with toggle between Metrics and Map Heatmap
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _analyticsTab == 0 ? 'District Analytics Board' : 'District Sales Heatmaps',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.grey900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _analyticsTab == 0
                              ? 'Monitor overall store performance, revenues, and sales indices.'
                              : 'Hyperlocal postcode density overlays, logistics coverage, and hot-spots.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                        ),
                      ],
                    ),
                    // Navigation toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.grey200),
                      ),
                      child: Row(
                        children: [
                          _buildTabSelector(0, 'Metrics Dashboard', Icons.bar_chart),
                          _buildTabSelector(1, 'Sales Heatmaps', Icons.map_outlined),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Conditional view render
                _analyticsTab == 0
                    ? _buildMetricsDashboard(
                        totalRevenue,
                        totalOrdersCount,
                        avgOrderValue,
                        totalCustomersCount,
                        filteredOrders,
                        categorySales,
                        topProducts,
                      )
                    : _buildHeatmapsDashboard(filteredOrders),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSelector(int index, String label, IconData icon) {
    final isSelected = _analyticsTab == index;
    return GestureDetector(
      onTap: () => setState(() => _analyticsTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.white : AppTheme.grey600, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.white : AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Metrics Dashboard Tab View ---
  Widget _buildMetricsDashboard(
    double totalRevenue,
    int totalOrdersCount,
    double avgOrderValue,
    int totalCustomersCount,
    List<OrderModel> filteredOrders,
    Map<String, double> categorySales,
    List<Map<String, dynamic>> topProducts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Row(
                children: List.generate(_periods.length, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPeriod = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedPeriod == index ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _periods[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedPeriod == index ? FontWeight.bold : FontWeight.normal,
                          color: _selectedPeriod == index ? AppTheme.white : AppTheme.grey700,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Revenue Card
        _buildRevenueCard(totalRevenue),
        const SizedBox(height: 24),

        // Stats Grid
        _buildStatsGrid(totalOrdersCount, avgOrderValue, totalCustomersCount),
        const SizedBox(height: 24),

        // Charts Section
        _buildChartsSection(filteredOrders, categorySales),
        const SizedBox(height: 24),

        // Top Products
        _buildTopProductsSection(topProducts),
        const SizedBox(height: 24),

        // Recent Activities Feed
        _buildRecentActivitySection(filteredOrders),
        const SizedBox(height: 24),
        
        // Feature: Actionable Low Stock (Feature 12)
        _buildRestockActionSection(context),
        const SizedBox(height: 24),
        
        // Feature 45: Promo Manager
        const BroadcastPromoManager(),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildRestockActionSection(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final alerts = productProvider.lowStockAlerts;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'âš¡ Critical Restock Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.error),
              ),
              Text('${alerts.length} items low', style: const TextStyle(fontSize: 12, color: AppTheme.error)),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const Text('All stock levels are optimal!', style: TextStyle(color: AppTheme.success, fontSize: 13))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: min(alerts.length, 3),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(alert.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('Only ${alert.currentStock} left (Min: ${alert.minimumStock})', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Navigate to inventory or open edit
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('RESTOCK', style: TextStyle(fontSize: 11)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Heatmaps Dashboard Tab View ---
  Widget _buildHeatmapsDashboard(List<OrderModel> orders) {
    // Filter zones based on search query and density selector
    final filteredZones = _postcodeZones.where((zone) {
      final matchesSearch = zone['zip'].contains(_searchQuery) ||
          zone['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDensity =
          _selectedDensityFilter == 'All' || zone['density'] == _selectedDensityFilter;
      return matchesSearch && matchesDensity;
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: List of Postcode Zones and Filters
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search postcode or zone (e.g. 302020)...',
                        prefixIcon: const Icon(Icons.search, color: AppTheme.grey400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.grey300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Density:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey700),
                        ),
                        Row(
                          children: [
                            _buildDensityFilterChip('All', AppTheme.primary),
                            const SizedBox(width: 6),
                            _buildDensityFilterChip('High', AppTheme.error),
                            const SizedBox(width: 6),
                            _buildDensityFilterChip('Medium', AppTheme.warning),
                            const SizedBox(width: 6),
                            _buildDensityFilterChip('Low', AppTheme.grey600),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Postcode Cards List
              if (filteredZones.isEmpty)
                _buildEmptyState(
                  icon: Icons.map_sharp,
                  title: 'No zones found',
                  subtitle: 'Try adjusting your search query or density filter.',
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredZones.length,
                  itemBuilder: (context, index) {
                    final zone = filteredZones[index];
                    final isSelected = _selectedPostcode?['zip'] == zone['zip'];

                    Color densityColor = AppTheme.grey600;
                    if (zone['density'] == 'High') {
                      densityColor = AppTheme.error;
                    } else if (zone['density'] == 'Medium') densityColor = AppTheme.warning;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedPostcode = zone),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.grey200,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.black.withValues(alpha: isSelected ? 0.06 : 0.02),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'PIN: ${zone['zip']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey800),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: densityColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${zone['density']} Density',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: densityColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  zone['name'],
                                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${zone['revenue'].toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                                Text(
                                  '${zone['ordersCount']} orders',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Interactive Map Grid (Scatter plot / Google Map) and Postcode Details Inspector
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle between Vector Plot and Google Maps
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    _buildMapModeTab(0, 'Visual Vector Heatmap', Icons.auto_awesome_mosaic),
                    _buildMapModeTab(1, 'Live Google Maps', Icons.location_pin),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Map Window Container
              Container(
                height: 350,
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.grey200),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _mapMode == 0
                      ? _buildVectorScatterMap()
                      : _buildGoogleMapsWidget(orders),
                ),
              ),
              const SizedBox(height: 24),

              // Postcode Inspector Panel
              if (_selectedPostcode != null)
                _buildPostcodeInspector(_selectedPostcode!)
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: const Center(
                    child: Text(
                      'Select a postcode zone from the list to inspect details.',
                      style: TextStyle(color: AppTheme.grey500),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDensityFilterChip(String label, Color color) {
    final isSelected = _selectedDensityFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedDensityFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : AppTheme.grey300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.white : AppTheme.grey600,
          ),
        ),
      ),
    );
  }

  Widget _buildMapModeTab(int index, String label, IconData icon) {
    final isSelected = _mapMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mapMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.secondary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? AppTheme.white : AppTheme.grey600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.white : AppTheme.grey600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVectorScatterMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Background grid lines simulating a radar/map grid
            Positioned.fill(
              child: CustomPaint(
                painter: MapGridPainter(
                  postcodes: _postcodeZones,
                  selectedZip: _selectedPostcode?['zip'],
                ),
              ),
            ),

            // Tappable dots for postcode locations
            for (var zone in _postcodeZones) ...[
              Builder(
                builder: (context) {
                  // Normalize coordinates to fit the bounds of the map view container
                  final double normalX = (zone['lng'] - 75.72) / 0.16; // ranges from 75.72 to 75.88
                  final double normalY = (zone['lat'] - 26.81) / 0.12; // ranges from 26.81 to 26.93

                  // Clamp values between 0.1 and 0.9 to avoid edge clipping
                  final double xPercent = normalX.clamp(0.1, 0.9);
                  final double yPercent = 1.0 - normalY.clamp(0.1, 0.9); // invert Y for screen coords

                  final isSelected = _selectedPostcode?['zip'] == zone['zip'];
                  Color zoneColor = AppTheme.grey600;
                  if (zone['density'] == 'High') {
                    zoneColor = AppTheme.error;
                  } else if (zone['density'] == 'Medium') {
                    zoneColor = AppTheme.warning;
                  }


                  // Pulse size based on orders count
                  final double dotRadius = 12 + (zone['ordersCount'] as int) / 3;

                  return Positioned(
                    left: constraints.maxWidth * xPercent - (dotRadius / 2),
                    top: constraints.maxHeight * yPercent - (dotRadius / 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPostcode = zone),
                      child: Tooltip(
                        message: '${zone['name']} (${zone['zip']})',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: dotRadius * (isSelected ? 1.4 : 1.0),
                          height: dotRadius * (isSelected ? 1.4 : 1.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: zoneColor.withValues(alpha: isSelected ? 0.6 : 0.35),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : zoneColor,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              ),
            ],

            // Legend indicators
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('High Ordering (30+)', AppTheme.error),
                    const SizedBox(height: 4),
                    _buildLegendItem('Medium Ordering (15-30)', AppTheme.warning),
                    const SizedBox(height: 4),
                    _buildLegendItem('Low Ordering (<15)', AppTheme.grey600),
                  ],
                ),
              ),
            ),

            // Help info overlay
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.grey900.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Vector Radar Plot',
                  style: TextStyle(color: AppTheme.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.grey700)),
      ],
    );
  }

  Widget _buildGoogleMapsWidget(List<OrderModel> orders) {
    // Generate markers for both defined postcode zones and actual orders
    final Set<Marker> markers = {};

    // 1. Postcode Zone Markers
    for (var zone in _postcodeZones) {
      final isSelected = _selectedPostcode?['zip'] == zone['zip'];
      markers.add(
        Marker(
          markerId: MarkerId('zone_${zone['zip']}'),
          position: LatLng(zone['lat'] as double, zone['lng'] as double),
          infoWindow: InfoWindow(
            title: zone['name'],
            snippet: '${zone['ordersCount']} orders • ₹${zone['revenue']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueAzure
                : (zone['density'] == 'High' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueYellow),
          ),
          onTap: () {
            setState(() {
              _selectedPostcode = zone;
            });
          },
        ),
      );
    }

    // 2. Add some order markers using deterministic offsets around the base
    for (int i = 0; i < min(orders.length, 10); i++) {
      final order = orders[i];
      final double latOffset = (sin(i.toDouble()) * 0.03);
      final double lngOffset = (cos(i.toDouble()) * 0.03);

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: LatLng(26.9124 + latOffset, 75.7873 + lngOffset),
          infoWindow: InfoWindow(
            title: 'Order #${order.orderNumber}',
            snippet: 'Customer: ${order.customerName} • ₹${order.totalAmount}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          _selectedPostcode != null ? (_selectedPostcode!['lat'] as double) : 26.9124,
          _selectedPostcode != null ? (_selectedPostcode!['lng'] as double) : 75.7873,
        ),
        zoom: 11.5,
      ),
      markers: markers,
      mapType: MapType.normal,
      zoomControlsEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  Widget _buildPostcodeInspector(Map<String, dynamic> zone) {
    Color densityColor = AppTheme.grey600;
    if (zone['density'] == 'High') {
      densityColor = AppTheme.error;
    } else if (zone['density'] == 'Medium') densityColor = AppTheme.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.01),
            blurRadius: 4,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        zone['name'],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: densityColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${zone['density']} Density',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: densityColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Postcode Zone PIN: ${zone['zip']}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.gps_fixed, color: AppTheme.primary, size: 20),
                onPressed: () {
                  setState(() {
                    _mapMode = 1; // force switch to google maps centered on selected postcode
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Focusing Live Google Maps on PIN ${zone['zip']}'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
                tooltip: 'Focus on Google Map',
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 12),

          // Detail Grid
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
            ),
            children: [
              _buildInspectorStatTile('Total Orders', zone['ordersCount'].toString(), Icons.shopping_basket_outlined, AppTheme.primary),
              _buildInspectorStatTile('Total Revenue', '₹${zone['revenue'].toStringAsFixed(0)}', Icons.payments_outlined, AppTheme.secondary),
              _buildInspectorStatTile('Avg Delivery Time', '${zone['avgDeliveryMins']} min', Icons.schedule, AppTheme.warning),
              _buildInspectorStatTile('Customer Satisfaction', '${zone['satisfaction']} / 5', Icons.star_border, Colors.amber),
              _buildInspectorStatTile('Active Riders', zone['ridersCount'].toString(), Icons.sports_motorsports_outlined, AppTheme.success),
              _buildInspectorStatTile('Top Category', zone['topCategory'], Icons.grid_view_sharp, Colors.deepPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.grey900),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: AppTheme.grey500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Metrics dashboard subcomponents ---
  String _guessCategory(String productName) {
    final name = productName.toLowerCase();
    if (name.contains('rice') || name.contains('atta') || name.contains('flour') || name.contains('dal')) {
      return 'Groceries';
    } else if (name.contains('milk') || name.contains('paneer') || name.contains('ghee') || name.contains('butter')) {
      return 'Dairy';
    } else if (name.contains('mango') || name.contains('apple') || name.contains('banana') || name.contains('orange')) {
      return 'Fruits';
    } else if (name.contains('potato') || name.contains('onion') || name.contains('tomato') || name.contains('chilli')) {
      return 'Vegetables';
    } else {
      return 'Household';
    }
  }

  Widget _buildRevenueCard(double revenue) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppTheme.white),
              const SizedBox(width: 8),
              Text(
                'Total Revenue Earned',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${revenue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.arrow_upward, color: AppTheme.success, size: 16),
              const SizedBox(width: 4),
              const Text(
                '+14.8%',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'vs last ${_periods[_selectedPeriod].toLowerCase()} district metrics',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int orders, double avgValue, int customers) {
    final stats = [
      {'title': 'Total Orders', 'value': '$orders', 'change': '+12%', 'icon': Icons.shopping_bag, 'color': AppTheme.primary},
      {'title': 'Avg Order Value', 'value': '₹${avgValue.toStringAsFixed(0)}', 'change': '+4%', 'icon': Icons.receipt_long, 'color': AppTheme.info},
      {'title': 'Customers', 'value': '$customers', 'change': '+18%', 'icon': Icons.people, 'color': AppTheme.success},
      {'title': 'District Cover', 'value': '98.5%', 'change': '+0.5%', 'icon': Icons.percent, 'color': AppTheme.warning},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (stat['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      stat['icon'] as IconData,
                      color: stat['color'] as Color,
                      size: 20,
                    ),
                  ),
                  Text(
                    stat['change'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: (stat['change'] as String).startsWith('+')
                          ? AppTheme.success
                          : AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                stat['value'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['title'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartsSection(List<OrderModel> orders, Map<String, double> categorySales) {
    final Map<int, double> dailyTotals = {};
    for (var order in orders) {
      if (order.status == OrderStatus.delivered) {
        final day = order.createdAt.day;
        dailyTotals[day] = (dailyTotals[day] ?? 0.0) + order.totalAmount;
      }
    }

    final spots = dailyTotals.entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList()..sort((a, b) => a.x.compareTo(b.x));

    if (spots.isEmpty) {
      spots.add(const FlSpot(1, 100));
      spots.add(const FlSpot(2, 450));
      spots.add(const FlSpot(3, 850));
    }

    final List<PieChartSectionData> pieSections = [];
    final List<Color> pieColors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.info,
      AppTheme.warning,
      Colors.indigo,
    ];

    int colorIndex = 0;
    categorySales.forEach((category, value) {
      if (value > 0) {
        pieSections.add(
          PieChartSectionData(
            color: pieColors[colorIndex % pieColors.length],
            value: value,
            title: category,
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    if (pieSections.isEmpty) {
      pieSections.add(
        PieChartSectionData(
          color: AppTheme.primary,
          value: 100,
          title: 'All Products',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales Overview Line',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppTheme.primary,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category Distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: pieSections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsSection(List<Map<String, dynamic>> products) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No sales transactions found in this period.',
                  style: TextStyle(color: AppTheme.grey500),
                ),
              ),
            )
          else
            ...products.map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${product['sales']} quantity ordered',
                            style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          product['revenue'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          product['growth'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(List<OrderModel> orders) {
    final List<Map<String, dynamic>> activities = [];
    for (var order in orders.take(4)) {
      String activityTitle = "";
      IconData icon = Icons.info;
      Color color = AppTheme.primary;

      switch (order.status) {
        case OrderStatus.pending:
          activityTitle = "New Order #${order.orderNumber} received";
          icon = Icons.shopping_bag;
          color = AppTheme.primary;
          break;
        case OrderStatus.confirmed:
          activityTitle = "Confirmed order #${order.orderNumber}";
          icon = Icons.check_circle;
          color = AppTheme.success;
          break;
        case OrderStatus.outForDelivery:
          activityTitle = "Order #${order.orderNumber} is Out for Delivery";
          icon = Icons.local_shipping;
          color = AppTheme.warning;
          break;
        case OrderStatus.delivered:
          activityTitle = "Delivered order #${order.orderNumber} successfully";
          icon = Icons.done_all;
          color = AppTheme.success;
          break;
        default:
          activityTitle = "Order #${order.orderNumber} status changed";
          icon = Icons.info;
          color = AppTheme.info;
      }

      activities.add({
        'title': activityTitle,
        'time': timeAgo(order.updatedAt),
        'icon': icon,
        'color': color,
      });
    }

    if (activities.isEmpty) {
      activities.add({
        'title': 'System ready and listening for new transactions.',
        'time': 'Just now',
        'icon': Icons.security,
        'color': AppTheme.success,
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'District Live Feeds',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          ...activities.map((activity) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['color'] as Color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      activity['title'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    activity['time'] as String,
                    style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.grey400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter to draw grid radar background mapping density hotspots
class MapGridPainter extends CustomPainter {
  final List<Map<String, dynamic>> postcodes;
  final String? selectedZip;

  MapGridPainter({required this.postcodes, this.selectedZip});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.grey200
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    const int gridRows = 8;
    for (int i = 0; i <= gridRows; i++) {
      final double y = (size.height / gridRows) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical grid lines
    const int gridCols = 10;
    for (int i = 0; i <= gridCols; i++) {
      final double x = (size.width / gridCols) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw secondary rings around the selected postcode to simulate scanning/radar
    if (selectedZip != null) {
      final zone = postcodes.firstWhere((element) => element['zip'] == selectedZip);
      
      final double normalX = (zone['lng'] - 75.72) / 0.16;
      final double normalY = (zone['lat'] - 26.81) / 0.12;

      final double x = size.width * normalX.clamp(0.1, 0.9);
      final double y = size.height * (1.0 - normalY.clamp(0.1, 0.9));

      final pulsePaint = Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(Offset(x, y), 35, pulsePaint);
      canvas.drawCircle(Offset(x, y), 70, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) {
    return oldDelegate.selectedZip != selectedZip;
  }
}

