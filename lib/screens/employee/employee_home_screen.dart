import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/scanner_service.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import 'scanner_screen.dart';
import 'inventory_receiving_screen.dart';
import 'order_packing_screen.dart';
import 'delivery_screen.dart';
import 'inventory_audit_screen.dart';
import 'damage_reporting_screen.dart';
import 'attendance_screen.dart';
import 'cash_collection_screen.dart';
import 'returns_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _pendingTasks = 0;
  int _assignedDeliveries = 0;

  @override
  void initState() {
    super.initState();
    _loadTaskCounts();
  }

  Future<void> _loadTaskCounts() async {
    final authProvider = context.read<AuthProvider>();
    final employeeId = authProvider.currentUser?.uid ?? '';
    final shopId = authProvider.currentShop?.id ?? '';
    final branchId = authProvider.currentBranch?.id ?? '';

    if (employeeId.isEmpty || shopId.isEmpty) return;

    final service = EmployeeScannerService(
      shopId: shopId,
      branchId: branchId,
      employeeId: employeeId,
      employeeName: authProvider.currentUser?.name ?? 'Employee',
    );

    // Count assigned deliveries
    service.getAssignedDeliveries().listen((snapshot) {
      if (mounted) {
        setState(() {
          _assignedDeliveries = snapshot.docs.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final employeeName = authProvider.currentUser?.name ?? 'Employee';

    return Scaffold(
      appBar: AppBar(
        title: Text('Fufaji Employee'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: () => _openScanner(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $employeeName',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          authProvider.currentBranch?.name ?? 'Branch',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Assigned Deliveries',
                    _assignedDeliveries.toString(),
                    Icons.delivery_dining,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Pending Tasks',
                    _pendingTasks.toString(),
                    Icons.task_alt,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _buildActionCard(
                  context,
                  'Scan',
                  Icons.qr_code_scanner,
                  'Scan products, orders, QR codes',
                  Colors.deepOrange,
                  () => _openScanner(context),
                ),
                _buildActionCard(
                  context,
                  'Receive Inventory',
                  Icons.add_box,
                  'Add new stock',
                  Colors.green,
                  () => _navigateTo(context, InventoryReceivingScreen()),
                ),
                _buildActionCard(
                  context,
                  'Pack Orders',
                  Icons.inventory_2,
                  'Verify and pack orders',
                  Colors.blue,
                  () => _navigateTo(context, OrderPackingScreen()),
                ),
                _buildActionCard(
                  context,
                  'Deliveries',
                  Icons.delivery_dining,
                  'Out for delivery',
                  Colors.purple,
                  () => _navigateTo(context, DeliveryScreen()),
                ),
                _buildActionCard(
                  context,
                  'Stock Audit',
                  Icons.inventory,
                  'Count and verify stock',
                  Colors.amber,
                  () => _navigateTo(context, InventoryAuditScreen()),
                ),
                _buildActionCard(
                  context,
                  'Damage Report',
                  Icons.report_problem,
                  'Report damaged items',
                  Colors.red,
                  () => _navigateTo(context, DamageReportingScreen()),
                ),
                _buildActionCard(
                  context,
                  'Attendance',
                  Icons.access_time,
                  'Check in/out',
                  Colors.teal,
                  () => _navigateTo(context, AttendanceScreen()),
                ),
                _buildActionCard(
                  context,
                  'Cash Collection',
                  Icons.payments,
                  'Record COD payments',
                  Colors.indigo,
                  () => _navigateTo(context, CashCollectionScreen()),
                ),
                _buildActionCard(
                  context,
                  'Returns',
                  Icons.replay,
                  'Process returns',
                  Colors.brown,
                  () => _navigateTo(context, ReturnsScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScanner(context),
        icon: Icon(Icons.qr_code_scanner),
        label: Text('Scan'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScannerScreen()),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }
}
