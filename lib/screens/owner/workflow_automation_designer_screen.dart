import 'package:flutter/material.dart';

class WorkflowAutomationDesignerScreen extends StatefulWidget {
  const WorkflowAutomationDesignerScreen({Key? key}) : super(key: key);

  @override
  State<WorkflowAutomationDesignerScreen> createState() => _WorkflowAutomationDesignerScreenState();
}

class _WorkflowAutomationDesignerScreenState extends State<WorkflowAutomationDesignerScreen>
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
        title: const Text('Workflow Automation Designer'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Workflows'),
            Tab(text: 'Builder'),
            Tab(text: 'Analytics'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Create Workflow',
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active Workflows
          _buildWorkflowsTab(colorScheme),
          // Tab 2: Workflow Builder
          _buildBuilderTab(colorScheme),
          // Tab 3: Analytics & Impact
          _buildAnalyticsTab(colorScheme),
          // Tab 4: Settings & Library
          _buildSettingsTab(colorScheme),
        ],
      ),
    );
  }

  Widget _buildWorkflowsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workflow Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automation Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '7',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active Workflows',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '4,234',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Executions (Today)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '99.8%',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Success Rate',
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

          // Active Workflows List
          Text(
            'Active Workflows',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildWorkflowCard(
            'Auto-Confirm Instant Orders',
            'Confirm orders with payment verified instantly',
            '1,245 executions',
            'Active',
            Colors.green,
          ),
          _buildWorkflowCard(
            'Low Stock Alert',
            'Notify when product stock < 20 units',
            '234 executions',
            'Active',
            Colors.green,
          ),
          _buildWorkflowCard(
            'Customer Win-back Campaign',
            'Send offers to inactive customers (>30 days)',
            '567 executions',
            'Active',
            Colors.green,
          ),
          _buildWorkflowCard(
            'Order Delay Notification',
            'Alert customer if order not shipped in 24h',
            '89 executions',
            'Active',
            Colors.green,
          ),
          _buildWorkflowCard(
            'Automatic Refund Processing',
            'Process refunds for cancelled orders automatically',
            '124 executions',
            'Active',
            Colors.green,
          ),
          _buildWorkflowCard(
            'Incentive for High-Value Orders',
            'Offer loyalty points bonus for orders >₹5,000',
            '345 executions',
            'Paused',
            Colors.orange,
          ),
          _buildWorkflowCard(
            'Bulk Inventory Update',
            'Sync inventory from vendor master weekly',
            '12 executions',
            'Active',
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildBuilderTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Builder Info
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workflow Builder: Visual Logic Designer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create conditional automation workflows without code. Combine triggers, conditions, and actions.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Workflow Components
          Text(
            'Available Components',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          // Triggers
          Text(
            'Triggers (Start conditions)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _buildComponentCard('Order Placed', 'When new order created', Icons.shopping_cart, Colors.blue),
          _buildComponentCard('Payment Received', 'When payment verified', Icons.paid, Colors.green),
          _buildComponentCard('Inventory Alert', 'When stock < threshold', Icons.inventory_2, Colors.orange),
          _buildComponentCard('Schedule', 'Recurring time-based trigger', Icons.schedule, Colors.purple),
          _buildComponentCard('Webhook', 'External system event', Icons.api, Colors.teal),
          const SizedBox(height: 16),

          // Conditions
          Text(
            'Conditions (Decision logic)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _buildComponentCard('Order Amount', 'Compare order total', Icons.compare_arrows, Colors.blue),
          _buildComponentCard('Customer Segment', 'Check customer type', Icons.people, Colors.green),
          _buildComponentCard('Inventory Level', 'Check stock availability', Icons.inventory_2, Colors.orange),
          _buildComponentCard('Time Window', 'Check if within date/time range', Icons.access_time, Colors.purple),
          _buildComponentCard('Custom Logic', 'Write conditional expression', Icons.code, Colors.teal),
          const SizedBox(height: 16),

          // Actions
          Text(
            'Actions (Execution steps)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          _buildComponentCard('Send Notification', 'SMS/WhatsApp/Email', Icons.notifications, Colors.blue),
          _buildComponentCard('Update Inventory', 'Adjust stock levels', Icons.edit, Colors.green),
          _buildComponentCard('Create Task', 'Assign staff task', Icons.assignment, Colors.orange),
          _buildComponentCard('Process Payment', 'Automatic refund/charge', Icons.payment, Colors.red),
          _buildComponentCard('Send Campaign', 'Trigger customer campaign', Icons.campaign, Colors.purple),
          _buildComponentCard('Update Order', 'Change order status', Icons.update, Colors.teal),
          _buildComponentCard('Log Event', 'Record audit trail', Icons.history, Colors.indigo),
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
                    'Automation Impact (This Month)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '68.5h',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manual Work Saved',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '94.2%',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Execution Success',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '₹2.4L',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Value Generated',
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

          // Per-Workflow Analytics
          Text(
            'Per-Workflow Performance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildAnalyticsCard(
            'Auto-Confirm Instant Orders',
            '1,245 executions',
            '99.7% success',
            '38.5 hours saved',
            Colors.green,
          ),
          _buildAnalyticsCard(
            'Low Stock Alert',
            '234 executions',
            '100% success',
            '12.3 hours saved',
            Colors.green,
          ),
          _buildAnalyticsCard(
            'Customer Win-back Campaign',
            '567 executions',
            '98.2% success',
            '8.5 hours saved',
            Colors.green,
          ),
          _buildAnalyticsCard(
            'Order Delay Notification',
            '89 executions',
            '99.9% success',
            '5.2 hours saved',
            Colors.green,
          ),
          const SizedBox(height: 16),

          // Time Savings
          Text(
            'Cumulative Benefits',
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
                      Text('Manual Order Processing'),
                      Text(
                        '280 hours',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Inventory Management'),
                      Text(
                        '120 hours',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Customer Communications'),
                      Text(
                        '160 hours',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Payment Processing'),
                      Text(
                        '85 hours',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Monthly Savings',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '645 hours / ₹32.25L',
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

  Widget _buildSettingsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Global Settings
          Text(
            'Global Settings',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingRow(
                    'Max Concurrent Workflows',
                    'Unlimited',
                    Icons.speed,
                    Colors.blue,
                  ),
                  const Divider(),
                  _buildSettingRow(
                    'Retry Failed Workflows',
                    'Enabled (3 attempts)',
                    Icons.refresh,
                    Colors.green,
                  ),
                  const Divider(),
                  _buildSettingRow(
                    'Workflow Execution Log',
                    'Enabled (30-day retention)',
                    Icons.history,
                    Colors.blue,
                  ),
                  const Divider(),
                  _buildSettingRow(
                    'Workflow Notifications',
                    'On failure only',
                    Icons.notifications,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Trigger Library
          Text(
            'Trigger Templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTemplateRow('Order Management', 5, 'triggers'),
                  const Divider(),
                  _buildTemplateRow('Inventory Management', 4, 'triggers'),
                  const Divider(),
                  _buildTemplateRow('Customer Engagement', 6, 'triggers'),
                  const Divider(),
                  _buildTemplateRow('Financial Operations', 3, 'triggers'),
                  const Divider(),
                  _buildTemplateRow('Custom Events', 2, 'triggers'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Library
          Text(
            'Action Templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTemplateRow('Notifications', 8, 'actions'),
                  const Divider(),
                  _buildTemplateRow('Data Updates', 6, 'actions'),
                  const Divider(),
                  _buildTemplateRow('Integrations', 4, 'actions'),
                  const Divider(),
                  _buildTemplateRow('Reports', 3, 'actions'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Condition Library
          Text(
            'Condition Templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTemplateRow('Amount Comparisons', 5, 'conditions'),
                  const Divider(),
                  _buildTemplateRow('Time-based Conditions', 7, 'conditions'),
                  const Divider(),
                  _buildTemplateRow('Data Validations', 8, 'conditions'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard(
    String title,
    String description,
    String executions,
    String status,
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              executions,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String workflow,
    String executions,
    String success,
    String saved,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workflow,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  executions,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    success,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '✓ $saved',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
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

  Widget _buildTemplateRow(String category, int count, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(category),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count $type',
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
