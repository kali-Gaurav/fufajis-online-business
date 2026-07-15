import 'package:flutter/material.dart';

class InventoryAutoReplenishmentScreen extends StatefulWidget {
  const InventoryAutoReplenishmentScreen({Key? key}) : super(key: key);

  @override
  State<InventoryAutoReplenishmentScreen> createState() => _InventoryAutoReplenishmentScreenState();
}

class _InventoryAutoReplenishmentScreenState extends State<InventoryAutoReplenishmentScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Auto-Replenishment'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Status'),
            Tab(text: 'Forecast'),
            Tab(text: 'PO Queue'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Replenishment Status
          _buildStatusTab(colorScheme),
          // Tab 2: Demand Forecast
          _buildForecastTab(colorScheme),
          // Tab 3: PO Queue
          _buildPOQueueTab(colorScheme),
          // Tab 4: Configuration
          _buildConfigTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replenishment Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-Replenishment Performance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '94.2%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stockout Prevention',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '234',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'POs Generated',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '₹24.5L',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inventory Value',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Replenishment Status by Category
          Text(
            'Replenishment Status by Category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildStatusCard('Dry Goods (Rice, Flour, Sugar)', 89, 'Optimal', Colors.green),
          _buildStatusCard('Dairy & Eggs', 134, 'Good', Colors.blue),
          _buildStatusCard('Fresh Produce', 45, 'Monitor', Colors.orange),
          _buildStatusCard('Beverages', 67, 'Optimal', Colors.green),
          _buildStatusCard('Spices & Condiments', 23, 'Optimal', Colors.green),
          const SizedBox(height: 16),

          // Recent Replenishments
          Text(
            'Recent Automatic Replenishment Orders',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildPOCard(
            'PO-2026-00456',
            'Rice (5kg) - 100 units',
            '₹18,500',
            'Executed',
            Colors.green,
          ),
          _buildPOCard(
            'PO-2026-00455',
            'Flour (1kg) - 200 units',
            '₹8,400',
            'Executed',
            Colors.green,
          ),
          _buildPOCard(
            'PO-2026-00454',
            'Cooking Oil (1L) - 80 units',
            '₹12,480',
            'Pending Approval',
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildForecastTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forecast Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demand Forecast Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '7 days',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Forecast Window',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '94.5%',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Forecast Accuracy',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'ML Model',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Algorithm',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Forecast by Product
          Text(
            'Demand Forecast (Next 7 Days)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildForecastCard(
            'Rice (5kg)',
            '156 units',
            'High demand - reorder at 50 units',
            'PO Queued',
            Colors.green,
          ),
          _buildForecastCard(
            'Flour (1kg)',
            '234 units',
            'Peak demand weekend - recommend +20%',
            'PO Queued',
            Colors.blue,
          ),
          _buildForecastCard(
            'Cooking Oil (1L)',
            '89 units',
            'Slight increase - marginal reorder',
            'Review',
            Colors.orange,
          ),
          _buildForecastCard(
            'Sugar (500g)',
            '45 units',
            'Normal demand - adequate stock',
            'Monitor',
            Colors.green,
          ),
          const SizedBox(height: 16),

          // Forecast Confidence
          Text(
            'Forecast Confidence Levels',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1-Day Ahead'),
                      Text(
                        '98.2%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('3-Day Ahead'),
                      Text(
                        '94.5%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('7-Day Ahead'),
                      Text(
                        '87.3%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOQueueTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PO Queue Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Order Queue',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '12',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pending Review',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '₹2.3L',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total PO Value',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '234',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Items to Order',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pending POs
          Text(
            'Pending Approval POs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildQueueCard(
            'Rice (5kg)',
            '100 units @ ₹185 = ₹18,500',
            'Forecast: High demand next week',
            'Auto-generated',
            Colors.green,
          ),
          _buildQueueCard(
            'Flour (1kg)',
            '200 units @ ₹42 = ₹8,400',
            'Stock dropping below reorder point',
            'Auto-generated',
            Colors.blue,
          ),
          _buildQueueCard(
            'Cooking Oil (1L)',
            '80 units @ ₹156 = ₹12,480',
            'Expiry cycle replenishment',
            'Auto-generated',
            Colors.orange,
          ),
          _buildQueueCard(
            'Butter (200g)',
            '45 units @ ₹95 = ₹4,275',
            'Seasonal demand increase',
            'Auto-generated',
            Colors.purple,
          ),
          const SizedBox(height: 16),

          // Executed POs (This Week)
          Text(
            'Executed POs (This Week)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('23 POs executed'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '₹45.8L total',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Replenishment Rules
          Text(
            'Replenishment Rules',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Reorder Point Formula', 'Average daily sales × Lead time + Safety stock', '📊'),
                  const Divider(),
                  _buildConfigRow('Safety Stock Buffer', 'Days of supply: 3-5 days', '🛡️'),
                  const Divider(),
                  _buildConfigRow('Lead Time Assumption', 'Average: 3-7 days by vendor', '📦'),
                  const Divider(),
                  _buildConfigRow('Economic Order Quantity', 'Optimized for cost vs holding', '💰'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Forecast Configuration
          Text(
            'Forecast Configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Forecast Algorithm', 'ARIMA + Machine Learning ensemble', '🤖'),
                  const Divider(),
                  _buildConfigRow('Training Data Window', 'Last 12 months', '📈'),
                  const Divider(),
                  _buildConfigRow('Seasonal Adjustment', 'Automatic (festivals, weather)', '📅'),
                  const Divider(),
                  _buildConfigRow('Forecast Horizon', '7 days (rolling)', '🔮'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Approval Workflow
          Text(
            'Approval Workflow',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Auto-Approval Threshold', '< ₹10,000', '✓'),
                  const Divider(),
                  _buildConfigRow('Manual Review Threshold', '₹10,000 - ₹50,000', '👤'),
                  const Divider(),
                  _buildConfigRow('Owner Approval Required', '> ₹50,000', '🔐'),
                  const Divider(),
                  _buildConfigRow('Review SLA', '2 hours', '⏰'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vendor Configuration
          Text(
            'Vendor & Integration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Active Vendors', '12 suppliers configured', '🏢'),
                  const Divider(),
                  _buildConfigRow('PO Distribution', 'Auto-optimized by availability', '📍'),
                  const Divider(),
                  _buildConfigRow('EDI Integration', 'Enabled for 8 vendors', '🔄'),
                  const Divider(),
                  _buildConfigRow('Order Confirmation', 'Automatic acknowledgment', '✓'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    String category,
    int count,
    String status,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count SKUs',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOCard(
    String poId,
    String item,
    String value,
    String status,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  poId,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard(
    String product,
    String forecast,
    String insight,
    String action,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(forecast, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(insight, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(
    String product,
    String details,
    String reason,
    String source,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(details, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(reason, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, String icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(icon),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
