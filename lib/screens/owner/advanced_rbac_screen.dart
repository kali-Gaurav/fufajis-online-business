import 'package:flutter/material.dart';

class AdvancedRBACScreen extends StatefulWidget {
  const AdvancedRBACScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedRBACScreen> createState() => _AdvancedRBACScreenState();
}

class _AdvancedRBACScreenState extends State<AdvancedRBACScreen> with TickerProviderStateMixin {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced RBAC'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Roles'), Tab(text: 'Permissions'), Tab(text: 'Audit'), Tab(text: 'Config')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRolesTab(),
          _buildPermissionsTab(),
          _buildAuditTab(),
          _buildConfigTab(),
        ],
      ),
    );
  }

  Widget _buildRolesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role Summary', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('8', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Total Roles', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('124', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Users', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('98.5%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Coverage', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Active Roles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildRoleCard('Owner', '1 user', '45 permissions', Colors.blue),
          _buildRoleCard('Manager', '3 users', '38 permissions', Colors.blue),
          _buildRoleCard('Staff', '45 users', '28 permissions', Colors.green),
          _buildRoleCard('Delivery Agent', '28 users', '18 permissions', Colors.green),
          _buildRoleCard('Customer Support', '12 users', '15 permissions', Colors.green),
          _buildRoleCard('Accountant', '4 users', '22 permissions', Colors.green),
          _buildRoleCard('Inventory Manager', '8 users', '32 permissions', Colors.green),
          _buildRoleCard('Guest', '23 users', '8 permissions', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Permission Matrix', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('156', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Permissions', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('8', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Resource Types', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('100%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Assigned', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Module Permissions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildPermissionCard('Orders', '18 perms', 'View, Create, Edit, Cancel', Colors.green),
          _buildPermissionCard('Inventory', '16 perms', 'View, Adjust, Transfer, Lock', Colors.green),
          _buildPermissionCard('Payments', '12 perms', 'View, Process, Reconcile, Refund', Colors.orange),
          _buildPermissionCard('Staff', '14 perms', 'View, Manage, Schedule, Review', Colors.green),
          _buildPermissionCard('Reports', '15 perms', 'View, Export, Schedule, Share', Colors.green),
          _buildPermissionCard('Settings', '22 perms', 'Configure, Integrate, Audit', Colors.orange),
          _buildPermissionCard('Accounts', '21 perms', 'Manage Roles, Permissions, Access', Colors.red),
          _buildPermissionCard('Compliance', '8 perms', 'View, Export, Certify', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Access Audit Trail', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('18,234', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Events (Today)', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Violations', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      Column(
                        children: [
                          Text('100%', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Logged', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Recent Access Events', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildAuditCard('Role Assignment', 'Manager assigned to Priya Sharma', 'By Admin', '2:45 PM', Colors.green),
          _buildAuditCard('Permission Change', 'Inventory Manager: +Vendor Management', 'By Admin', '1:32 PM', Colors.blue),
          _buildAuditCard('Access Denied', 'Staff attempted Orders > Refund', 'Blocked', '12:18 PM', Colors.orange),
          _buildAuditCard('Access Grant', 'Delivery Agent: +Shift Scheduling', 'By Manager', '11:05 AM', Colors.green),
          _buildAuditCard('Role Removal', 'Guest role removed from John Doe', 'By Admin', '9:42 AM', Colors.red),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RBAC Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Access Control Model', 'Role-Based + Attribute-Based', '🔐'),
                  const Divider(),
                  _buildConfigRow('Permission Inheritance', 'Enabled', '✓'),
                  const Divider(),
                  _buildConfigRow('Delegation Support', 'Enabled', '✓'),
                  const Divider(),
                  _buildConfigRow('Time-Based Permissions', 'Enabled', '⏱️'),
                  const Divider(),
                  _buildConfigRow('IP-Based Restrictions', 'Enabled', '🌐'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Security Policies', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfigRow('Password Policy', 'Enforced', '✓'),
                  const Divider(),
                  _buildConfigRow('MFA Requirement', 'For Admin Roles', '✓'),
                  const Divider(),
                  _buildConfigRow('Session Timeout', '30 minutes', '⏰'),
                  const Divider(),
                  _buildConfigRow('Audit Retention', '2 years', '📋'),
                  const Divider(),
                  _buildConfigRow('Access Review Frequency', 'Quarterly', '📅'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String users, String permissions, Color color) {
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
                Text(role, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(permissions, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
              child: Text(users, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(String module, String count, String actions, Color color) {
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
                Text(module, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(count, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(actions, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditCard(String event, String description, String by, String time, Color color) {
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
                Text(event, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(6)),
                  child: Text(by, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(description, style: Theme.of(context).textTheme.bodySmall),
                Text(time, style: Theme.of(context).textTheme.labelSmall),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(icon), const SizedBox(width: 12), Text(label)]), Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))]),
    );
  }
}
