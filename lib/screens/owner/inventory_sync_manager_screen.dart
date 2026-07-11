import 'package:flutter/material.dart';

class InventorySyncManagerScreen extends StatefulWidget {
  const InventorySyncManagerScreen({Key? key}) : super(key: key);

  @override
  State<InventorySyncManagerScreen> createState() => _InventorySyncManagerScreenState();
}

class _InventorySyncManagerScreenState extends State<InventorySyncManagerScreen>
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
        title: const Text('Inventory Sync Manager'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Real-time'),
            Tab(text: 'Reservations'),
            Tab(text: 'Conflicts'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Real-time Inventory Tracking
          _buildRealtimeTab(colorScheme),
          // Tab 2: Active Reservations
          _buildReservationsTab(colorScheme),
          // Tab 3: Conflict Detection & Resolution
          _buildConflictsTab(colorScheme),
          // Tab 4: Configuration
          _buildConfigTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildRealtimeTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inventory Health Score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Inventory Sync Health',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Healthy',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: 0.97,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                              backgroundColor: Colors.grey.shade200,
                            ),
                            Text(
                              '97%',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetricRow('Available Stock', '8,432 items', Colors.blue),
                            const SizedBox(height: 12),
                            _buildMetricRow('Reserved Stock', '1,243 items', Colors.orange),
                            const SizedBox(height: 12),
                            _buildMetricRow('Sold Stock', '12,891 items', Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Product-level Sync Status
          Text(
            'Product Sync Status',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildProductSyncCard(
            colorScheme,
            'Product #A001 - Rice (5kg)',
            '245',
            '32',
            '156',
            Colors.green,
            'Synced',
          ),
          _buildProductSyncCard(
            colorScheme,
            'Product #A002 - Flour (1kg)',
            '89',
            '12',
            '45',
            Colors.green,
            'Synced',
          ),
          _buildProductSyncCard(
            colorScheme,
            'Product #A003 - Sugar (500g)',
            '0',
            '8',
            '67',
            Colors.orange,
            'Low Stock',
          ),
          _buildProductSyncCard(
            colorScheme,
            'Product #A004 - Oil (1L)',
            '156',
            '24',
            '89',
            Colors.green,
            'Synced',
          ),
          const SizedBox(height: 16),

          // Sync Latency by Operation
          Text(
            'Sync Latency Metrics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLatencyRow('Reservation Lock (avg)', '342ms', 'Normal'),
                  const Divider(),
                  _buildLatencyRow('Reservation Release (avg)', '287ms', 'Normal'),
                  const Divider(),
                  _buildLatencyRow('Stock Update (avg)', '156ms', 'Optimal'),
                  const Divider(),
                  _buildLatencyRow('Conflict Detection (avg)', '89ms', 'Optimal'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Reservations Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '156',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active Reservations',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '4.3 hrs',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg Lock Duration',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '3',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expiring Soon',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reservation Timeline
          Text(
            'Recent Reservations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildReservationCard(
            'Order #ORD-2026-00156',
            'Product A001 - Rice (5kg)',
            '32 units',
            'Reserved',
            '2:45 PM',
            Colors.green,
          ),
          _buildReservationCard(
            'Order #ORD-2026-00155',
            'Product A002 - Flour (1kg)',
            '12 units',
            'Reserved',
            '2:38 PM',
            Colors.green,
          ),
          _buildReservationCard(
            'Order #ORD-2026-00154',
            'Product A004 - Oil (1L)',
            '24 units',
            'Expiring in 45m',
            '2:15 PM',
            Colors.orange,
          ),
          _buildReservationCard(
            'Order #ORD-2026-00153',
            'Product A001 - Rice (5kg)',
            '16 units',
            'Released (Purchased)',
            '1:52 PM',
            Colors.grey,
          ),
          const SizedBox(height: 16),

          // Reservation Expiry Warning
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reservations Expiring Soon',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '3 reservations will expire within the next hour. Consider releasing or confirming payment.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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

  Widget _buildConflictsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conflict Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conflict Detection Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '0',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Critical Conflicts',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '0',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Warnings',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'OK',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Overall Status',
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

          // Conflict History (empty state when all clear)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Conflicts Detected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All inventory reservations are in sync across PostgreSQL and Firestore.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conflict Resolution Settings
          Text(
            'Auto-Resolution Policy',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PostgreSQL Priority'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Source of Truth',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Firestore Synced From'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Read Cache',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Conflict Threshold'),
                      Text(
                        '5 minute divergence',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Auto-Reconcile'),
                      Icon(
                        Icons.toggle_on,
                        color: Colors.green,
                        size: 28,
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
          // Reservation Settings
          Text(
            'Reservation Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow(
                    'Default Reservation TTL',
                    '15 minutes',
                    '⏱️',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Reservation Renewal Allowed',
                    'Yes (max 3 times)',
                    '🔄',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Payment Timeout for Release',
                    '30 minutes',
                    '💳',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Overselling Prevention',
                    'Strict (0% tolerance)',
                    '🛑',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sync Configuration
          Text(
            'Sync Configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow(
                    'Sync Mode',
                    'Real-time (<1 second)',
                    '⚡',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Batch Size for Bulk Operations',
                    '500 items',
                    '📦',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Conflict Resolution Strategy',
                    'PostgreSQL wins',
                    '🎯',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Retry Attempts on Sync Failure',
                    '3 (exponential backoff)',
                    '🔁',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Alert Thresholds
          Text(
            'Alert Thresholds',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow(
                    'Sync Latency Warning',
                    '>2 seconds',
                    '⚠️',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Sync Latency Critical',
                    '>5 seconds',
                    '🚨',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Divergence Tolerance',
                    '0 (zero divergence)',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Failed Sync Retries',
                    'Alert after 2 failures',
                    '📢',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Entity-Specific Rules
          Text(
            'Entity-Specific Rules',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildEntityRuleCard('Orders', 'High Priority', '99.9% SLA'),
          _buildEntityRuleCard('Inventory', 'High Priority', '99.9% SLA'),
          _buildEntityRuleCard('Reservations', 'High Priority', '99.9% SLA'),
          _buildEntityRuleCard('Customers', 'Medium Priority', '99% SLA'),
          _buildEntityRuleCard('Products', 'Medium Priority', '99% SLA'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductSyncCard(
    ColorScheme colorScheme,
    String productName,
    String available,
    String reserved,
    String sold,
    Color statusColor,
    String status,
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
                  productName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInventoryLevel('Available', available, Colors.blue),
                _buildInventoryLevel('Reserved', reserved, Colors.orange),
                _buildInventoryLevel('Sold', sold, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryLevel(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildLatencyRow(String label, String latency, String status) {
    Color statusColor = status == 'Optimal' ? Colors.green : Colors.orange;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          latency,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(
    String orderId,
    String product,
    String quantity,
    String status,
    String time,
    Color statusColor,
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
                  orderId,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quantity,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
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
          Row(
            children: [
              Text(icon),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityRuleCard(String entity, String priority, String sla) {
    Color priorityColor = priority == 'High Priority' ? Colors.red : Colors.orange;
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
                  entity,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  sla,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: priorityColor.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                priority,
                style: TextStyle(
                  color: priorityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
