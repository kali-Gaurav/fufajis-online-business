import 'package:flutter/material.dart';

class OrderStatusMachineScreen extends StatefulWidget {
  const OrderStatusMachineScreen({Key? key}) : super(key: key);

  @override
  State<OrderStatusMachineScreen> createState() => _OrderStatusMachineScreenState();
}

class _OrderStatusMachineScreenState extends State<OrderStatusMachineScreen>
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
        title: const Text('Order Status Machine'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Status'),
            Tab(text: 'Event Log'),
            Tab(text: 'Anomalies'),
            Tab(text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Order Status Overview
          _buildStatusTab(colorScheme),
          // Tab 2: Event Sourcing Log
          _buildEventLogTab(colorScheme),
          // Tab 3: Anomaly Detection
          _buildAnomaliesTab(colorScheme),
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
          // State Machine Health
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
                        'State Machine Health',
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
                          'Consistent',
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
                              value: 1.0,
                              strokeWidth: 8,
                              valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                              backgroundColor: Colors.grey.shade200,
                            ),
                            Text(
                              '100%',
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
                            _buildMetricRow('Valid Transitions', '2,345', Colors.green),
                            const SizedBox(height: 12),
                            _buildMetricRow('Stuck Orders', '0', Colors.green),
                            const SizedBox(height: 12),
                            _buildMetricRow('Manual Overrides', '2', Colors.orange),
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

          // Order Status Distribution
          Text(
            'Current Order Distribution (Today)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildStatusDistribution('Pending Payment', 45, Colors.blue),
          _buildStatusDistribution('Confirmed', 89, Colors.indigo),
          _buildStatusDistribution('Processing', 156, Colors.purple),
          _buildStatusDistribution('Packed', 234, Colors.cyan),
          _buildStatusDistribution('Shipped', 312, Colors.teal),
          _buildStatusDistribution('Delivered', 1024, Colors.green),
          _buildStatusDistribution('Cancelled', 23, Colors.red),
          const SizedBox(height: 16),

          // Recent Orders
          Text(
            'Recent Order Status Transitions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildOrderStatusCard(
            'ORD-2026-00156',
            'Pending Payment',
            'Confirmed',
            '2:45 PM',
            Colors.green,
          ),
          _buildOrderStatusCard(
            'ORD-2026-00155',
            'Confirmed',
            'Processing',
            '2:38 PM',
            Colors.green,
          ),
          _buildOrderStatusCard(
            'ORD-2026-00154',
            'Processing',
            'Packed',
            '2:32 PM',
            Colors.green,
          ),
          _buildOrderStatusCard(
            'ORD-2026-00153',
            'Packed',
            'Shipped',
            '1:52 PM',
            Colors.green,
          ),
          _buildOrderStatusCard(
            'ORD-2026-00152',
            'Shipped',
            'Delivered',
            '1:12 PM',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildEventLogTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Sourcing Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Sourcing Audit Trail',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '8,923',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Events Logged',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '100%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Immutable',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                            'Lost Events',
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

          // Event Timeline
          Text(
            'Recent Events (Last 1 Hour)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildEventLogEntry(
            'ORD-2026-00156',
            'OrderConfirmed',
            'Payment verified, order locked',
            '2:45:32 PM',
            Colors.green,
          ),
          _buildEventLogEntry(
            'ORD-2026-00156',
            'InventoryReserved',
            '32 units reserved for delivery',
            '2:45:33 PM',
            Colors.green,
          ),
          _buildEventLogEntry(
            'ORD-2026-00155',
            'PaymentReceived',
            'Razorpay settlement confirmed',
            '2:38:15 PM',
            Colors.green,
          ),
          _buildEventLogEntry(
            'ORD-2026-00155',
            'OrderStatusChanged',
            'Status: Confirmed → Processing',
            '2:38:16 PM',
            Colors.green,
          ),
          _buildEventLogEntry(
            'ORD-2026-00154',
            'PackingStarted',
            'Items picked from shelf',
            '2:32:45 PM',
            Colors.blue,
          ),
          _buildEventLogEntry(
            'ORD-2026-00154',
            'QualityCheckPassed',
            'All items verified',
            '2:35:12 PM',
            Colors.green,
          ),
          const SizedBox(height: 16),

          // Event Replay Information
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Replay Capability',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All events are immutable and replayed from log. Current state always reconstructed from event history.',
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

  Widget _buildAnomaliesTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anomaly Detection Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anomaly Detection',
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
                            'Stuck Orders',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                            'Invalid Transitions',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
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
                            'State Conflicts',
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

          // Healthy Status
          Card(
            color: Colors.green.shade50,
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
                    'All Orders In Healthy State',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No anomalies detected. All orders following valid state transitions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Anomaly Detection Rules
          Text(
            'Detection Rules',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRuleRow(
                    'Stuck Order Detection',
                    'Order in state > 24 hours without transition',
                    Icons.timer,
                    Colors.red,
                  ),
                  const Divider(),
                  _buildRuleRow(
                    'Invalid Transition',
                    'Attempted transition outside allowed state graph',
                    Icons.block,
                    Colors.red,
                  ),
                  const Divider(),
                  _buildRuleRow(
                    'Payment Timeout',
                    'Order pending payment > 30 minutes',
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                  const Divider(),
                  _buildRuleRow(
                    'Delivery Delay',
                    'Shipped order not delivered > 48 hours',
                    Icons.local_shipping,
                    Colors.orange,
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
          // State Machine Definition
          Text(
            'State Machine Definition',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransitionRow('Initial State', 'pending_payment', Colors.blue),
                  const Divider(),
                  _buildTransitionRow('Allowed Transitions', '8 states defined', Colors.green),
                  const Divider(),
                  _buildTransitionRow('Terminal States', '3 (delivered, failed, refunded)', Colors.red),
                  const Divider(),
                  _buildTransitionRow('Branching Support', 'Multiple paths allowed', Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transition Rules
          Text(
            'Transition Rules',
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
                    'pending_payment → confirmed',
                    'On payment verified',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'pending_payment → cancelled',
                    'On customer cancel or payment timeout',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'confirmed → processing',
                    'On inventory lock + payment received',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'processing → packed',
                    'On QC verification',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'packed → shipped',
                    'On dispatch event',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'shipped → delivered',
                    'On rider POD verification',
                    '✓',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Triggers
          Text(
            'State Change Action Triggers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionRow(
                    'On Confirmed',
                    'Send order confirmation SMS/WhatsApp',
                  ),
                  const Divider(),
                  _buildActionRow(
                    'On Processing',
                    'Start packing, notify warehouse',
                  ),
                  const Divider(),
                  _buildActionRow(
                    'On Shipped',
                    'Send tracking link to customer',
                  ),
                  const Divider(),
                  _buildActionRow(
                    'On Delivered',
                    'Trigger review request, update analytics',
                  ),
                  const Divider(),
                  _buildActionRow(
                    'On Cancelled',
                    'Release inventory, process refund',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Manual Override Policy
          Text(
            'Manual Override Settings',
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
                    'Manual Override Allowed',
                    'Yes (audit logged)',
                    '✓',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Override Permissions',
                    'Owner only',
                    '🔐',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Override Logging',
                    'All overrides recorded with reason',
                    '📋',
                  ),
                  const Divider(),
                  _buildConfigRow(
                    'Override Notification',
                    'Immediate alert to admin',
                    '📢',
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildStatusDistribution(String status, int count, Color color) {
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
                Text(status),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / 1024,
                minHeight: 4,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusCard(
    String orderId,
    String fromState,
    String toState,
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
            Text(
              orderId,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fromState,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    toState,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLogEntry(
    String orderId,
    String event,
    String description,
    String time,
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
              children: [
                Container(
                  width: 12,
                  height: 12,
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
                        orderId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleRow(String label, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
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

  Widget _buildActionRow(String trigger, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trigger,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '→ $action',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
