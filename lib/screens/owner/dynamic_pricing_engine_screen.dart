import 'package:flutter/material.dart';

class DynamicPricingEngineScreen extends StatefulWidget {
  const DynamicPricingEngineScreen({Key? key}) : super(key: key);

  @override
  State<DynamicPricingEngineScreen> createState() => _DynamicPricingEngineScreenState();
}

class _DynamicPricingEngineScreenState extends State<DynamicPricingEngineScreen>
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
        title: const Text('Dynamic Pricing Engine'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pricing'),
            Tab(text: 'Strategies'),
            Tab(text: 'Analytics'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Current Pricing
          _buildPricingTab(colorScheme),
          // Tab 2: Pricing Strategies
          _buildStrategiesTab(colorScheme),
          // Tab 3: Pricing Analytics
          _buildAnalyticsTab(colorScheme),
          // Tab 4: Configuration
          _buildConfigTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPricingTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pricing Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pricing Impact (This Month)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '4.2%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Margin Gain',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '₹98.5L',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Additional Revenue',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '3.8%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Volume Change',
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

          // Dynamic Priced Products
          Text(
            'Dynamically Priced Products (Top 10)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildPriceCard('Rice (5kg bag)', '₹185 → ₹192', 'High demand', '+3.8%', Colors.green),
          _buildPriceCard('Flour (1kg)', '₹42 → ₹40', 'Competitive pressure', '-4.7%', Colors.orange),
          _buildPriceCard('Cooking Oil (1L)', '₹156 → ₹165', 'Low stock', '+5.7%', Colors.green),
          _buildPriceCard('Sugar (500g)', '₹28 → ₹26', 'Oversupply', '-7.1%', Colors.orange),
          _buildPriceCard('Milk (1L)', '₹52 → ₹54', 'High demand', '+3.8%', Colors.green),
          _buildPriceCard('Butter (200g)', '₹95 → ₹98', 'Seasonal demand', '+3.1%', Colors.green),
          _buildPriceCard('Eggs (1 dozen)', '₹68 → ₹65', 'Commodity pricing', '-4.4%', Colors.orange),
          _buildPriceCard('Spice Mix (100g)', '₹34 → ₹37', 'Low volume', '+8.8%', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStrategiesTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pricing Strategies
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Pricing Strategies',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI-driven pricing algorithms that consider demand, inventory, competition, and seasonality.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Strategy 1: Demand-Based
          _buildStrategySection(
            'Demand-Based Pricing',
            'Adjust prices based on real-time order volume',
            [
              'High demand (orders/hour): Increase price by 2-5%',
              'Normal demand: Base price',
              'Low demand: Decrease price by 2-3% to stimulate',
            ],
            Colors.green,
          ),
          const SizedBox(height: 16),

          // Strategy 2: Inventory-Based
          _buildStrategySection(
            'Inventory-Driven Pricing',
            'Optimize based on stock levels and expiry',
            [
              'High stock (>3 months): Standard pricing',
              'Medium stock (1-3 months): +5% to increase velocity',
              'Low stock (<1 month): +8-15% premium pricing',
              'Near expiry (<7 days): -20% clearance discount',
            ],
            Colors.purple,
          ),
          const SizedBox(height: 16),

          // Strategy 3: Competitor-Aware
          _buildStrategySection(
            'Competitive Pricing',
            'Respond to competitor pricing in real-time',
            [
              'Price undercut by competitors: Match or beat (-2%)',
              'Price premium available: Increase (+3%)',
              'Local market dominance: Maximize (+5%)',
            ],
            Colors.teal,
          ),
          const SizedBox(height: 16),

          // Strategy 4: Seasonal
          _buildStrategySection(
            'Seasonal & Temporal',
            'Adjust for seasons, day of week, time of day',
            [
              'Peak hours (7-9am, 6-8pm): +3-7%',
              'Off-peak: -2% to stabilize demand',
              'Weekend premium: +2%',
              'Festival seasons: +5-10%',
            ],
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pricing Performance Analytics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '1,245',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Price Changes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '98.3%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Accuracy',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '-0.2%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Price Variance',
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

          // Revenue by Strategy
          Text(
            'Revenue Contribution by Strategy',
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
                      Text('Demand-Based Pricing'),
                      Text(
                        '₹38.5L (39%)',
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
                      Text('Inventory-Driven Pricing'),
                      Text(
                        '₹32.4L (33%)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Competitive Pricing'),
                      Text(
                        '₹18.2L (18%)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Seasonal Adjustments'),
                      Text(
                        '₹9.4L (10%)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Additional Revenue',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '₹98.5L',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
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

  Widget _buildConfigTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Algorithm Settings
          Text(
            'Pricing Algorithm Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Price Update Frequency', 'Every 30 minutes', '⏱️'),
                  const Divider(),
                  _buildConfigRow('Maximum Price Change', '±15% per update', '📊'),
                  const Divider(),
                  _buildConfigRow('Minimum Price Floor', 'Cost + 10%', '📉'),
                  const Divider(),
                  _buildConfigRow('Maximum Price Ceiling', 'Historical max + 20%', '📈'),
                  const Divider(),
                  _buildConfigRow('Algorithm Confidence', '>90% before apply', '✓'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Safety Guardrails
          Text(
            'Safety Guardrails',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Price Anomaly Detection', 'Enabled', '🚨'),
                  const Divider(),
                  _buildConfigRow('Manual Override Allowed', 'Owner only', '🔐'),
                  const Divider(),
                  _buildConfigRow('Price Approval Workflow', 'Auto-execute', '✓'),
                  const Divider(),
                  _buildConfigRow('Competitor Price Check', 'Real-time (15m sync)', '🔄'),
                  const Divider(),
                  _buildConfigRow('Margin Floor Check', 'Enforced always', '✓✓'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Strategy Weights
          Text(
            'Strategy Weights (Contribution to Final Price)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeightRow('Demand Signal', '40%'),
                  const Divider(),
                  _buildWeightRow('Inventory Level', '30%'),
                  const Divider(),
                  _buildWeightRow('Competitive Pricing', '20%'),
                  const Divider(),
                  _buildWeightRow('Seasonal Factor', '10%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(
    String product,
    String priceChange,
    String reason,
    String impact,
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
                    impact,
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
            Text(priceChange, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(reason, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategySection(
    String title,
    String description,
    List<String> rules,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rules.map((rule) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_small, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
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
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightRow(String strategy, String weight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(strategy),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              weight,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
