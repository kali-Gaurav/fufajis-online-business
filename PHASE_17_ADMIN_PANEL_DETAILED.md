# Phase 17: Admin Panel - Implementation Checklist

## Overview
Build comprehensive admin dashboard for platform management.

## Current Status
- ✅ AdminDashboard: Partially implemented
- ⏳ UserManagementModule: Needs implementation
- ⏳ ShopManagementModule: Needs implementation
- ⏳ ProductModerationModule: Needs implementation
- ⏳ OrderManagementModule: Needs implementation
- ⏳ CouponManagementModule: Needs implementation
- ⏳ AnalyticsModule: Needs implementation

## Task 17.1: Complete AdminDashboard UI
**Status:** Partially Complete
**File:** `lib/screens/admin/admin_dashboard.dart`

### Implementation Steps:
1. [ ] Display key metrics (Users, Shops, Orders, Revenue)
2. [ ] Show charts for revenue trends
3. [ ] Display top shops and products
4. [ ] Show system health status
5. [ ] Add quick action buttons

### Code Template:
```dart
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Row
            Row(
              children: [
                _buildMetricCard(
                  title: 'Total Users',
                  value: '1,234',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  title: 'Active Shops',
                  value: '456',
                  icon: Icons.store,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMetricCard(
                  title: 'Total Orders',
                  value: '7,890',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildMetricCard(
                  title: 'Revenue',
                  value: '₹12.5L',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Revenue Chart
            Text(
              'Revenue Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildRevenueChart(),
            const SizedBox(height: 24),
            
            // Top Shops
            Text(
              'Top Shops',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildTopShopsList(),
            const SizedBox(height: 24),
            
            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, 1),
                    FlSpot(1, 3),
                    FlSpot(2, 2),
                    FlSpot(3, 5),
                    FlSpot(4, 4),
                    FlSpot(5, 6),
                  ],
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopShopsList() {
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text('Shop ${index + 1}'),
            subtitle: Text('₹${(index + 1) * 10000}'),
            trailing: Icon(Icons.arrow_forward),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push('/admin/users'),
          icon: Icon(Icons.people),
          label: const Text('Manage Users'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/admin/shops'),
          icon: Icon(Icons.store),
          label: const Text('Manage Shops'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/admin/products'),
          icon: Icon(Icons.inventory),
          label: const Text('Moderate Products'),
        ),
      ],
    );
  }
}
```

## Task 17.2: Create UserManagementModule
**Status:** Not Started
**File:** `lib/screens/admin/user_management_screen.dart`

### Implementation Steps:
1. [ ] Create user list screen
2. [ ] Implement pagination
3. [ ] Add search functionality
4. [ ] Add filter options
5. [ ] Implement suspension/activation
6. [ ] Add verification toggle
7. [ ] Show activity history

### Code Template:
```dart
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, active, suspended, unverified

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFilter == 'all',
                  onSelected: (_) => setState(() => _selectedFilter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Active'),
                  selected: _selectedFilter == 'active',
                  onSelected: (_) => setState(() => _selectedFilter = 'active'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Suspended'),
                  selected: _selectedFilter == 'suspended',
                  onSelected: (_) => setState(() => _selectedFilter = 'suspended'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Unverified'),
                  selected: _selectedFilter == 'unverified',
                  onSelected: (_) => setState(() => _selectedFilter = 'unverified'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // User list
          Expanded(
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) {
                return _buildUserTile(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('U${index + 1}'),
        ),
        title: Text('User ${index + 1}'),
        subtitle: Text('user${index + 1}@example.com'),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Text('View Details'),
              onTap: () => _showUserDetails(context, index),
            ),
            PopupMenuItem(
              child: const Text('Suspend'),
              onTap: () => _suspendUser(index),
            ),
            PopupMenuItem(
              child: const Text('Verify'),
              onTap: () => _verifyUser(index),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetails(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User ${index + 1} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: user${index + 1}@example.com'),
            Text('Phone: +91 98765 ${43210 + index}'),
            Text('Status: Active'),
            Text('Joined: 2024-01-15'),
            Text('Orders: ${index * 5}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _suspendUser(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User ${index + 1} suspended')),
    );
  }

  void _verifyUser(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User ${index + 1} verified')),
    );
  }
}
```

## Task 17.3: Create ShopManagementModule
**Status:** Not Started
**File:** `lib/screens/admin/shop_management_screen.dart`

### Implementation Steps:
1. [ ] Create shop list screen
2. [ ] Implement pagination
3. [ ] Add search functionality
4. [ ] Add filter options
5. [ ] Implement approval/rejection
6. [ ] Add suspension/activation
7. [ ] Show performance metrics

### Similar structure to UserManagementScreen with shop-specific fields

## Task 17.4: Create ProductModerationModule
**Status:** Not Started
**File:** `lib/screens/admin/product_moderation_screen.dart`

### Implementation Steps:
1. [ ] Create product moderation screen
2. [ ] Display pending products
3. [ ] Add approve/reject buttons
4. [ ] Add rejection reason input
5. [ ] Show moderation history
6. [ ] Implement bulk actions
7. [ ] Test with various products

### Code Template:
```dart
class ProductModerationScreen extends StatefulWidget {
  const ProductModerationScreen({Key? key}) : super(key: key);

  @override
  State<ProductModerationScreen> createState() => _ProductModerationScreenState();
}

class _ProductModerationScreenState extends State<ProductModerationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Moderation'),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return _buildProductCard(context, index);
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            height: 200,
            color: Colors.grey[300],
            child: Center(
              child: Icon(Icons.image, size: 64),
            ),
          ),
          
          // Product details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Shop: Shop ${index + 1}'),
                Text('Price: ₹${(index + 1) * 100}'),
                Text('Category: Category ${index % 5 + 1}'),
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveProduct(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectProduct(context, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _approveProduct(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Product ${index + 1} approved')),
    );
  }

  void _rejectProduct(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Product'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Product ${index + 1} rejected')),
              );
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
```

## Task 17.5: Create OrderManagementModule
**Status:** Not Started
**File:** `lib/screens/admin/order_management_screen.dart`

### Implementation Steps:
1. [ ] Create order list screen
2. [ ] Implement pagination
3. [ ] Add search functionality
4. [ ] Add filter options
5. [ ] Implement cancellation
6. [ ] Add refund processing
7. [ ] Show analytics

## Task 17.6: Create CouponManagementModule
**Status:** Not Started
**File:** `lib/screens/admin/coupon_management_screen.dart`

### Implementation Steps:
1. [ ] Create coupon list screen
2. [ ] Add create/edit forms
3. [ ] Display usage statistics
4. [ ] Add activation/deactivation
5. [ ] Show performance metrics

## Task 17.7: Create AnalyticsModule
**Status:** Not Started
**File:** `lib/screens/admin/analytics_screen.dart`

### Implementation Steps:
1. [ ] Create analytics screen
2. [ ] Add revenue charts
3. [ ] Add user growth charts
4. [ ] Add order trend charts
5. [ ] Show top products
6. [ ] Show shop rankings
7. [ ] Implement export functionality

## Admin Provider
**File:** `lib/providers/admin_provider.dart`

### Code Template:
```dart
class AdminProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _users = [];
  List<ShopModel> _shops = [];
  List<ProductModel> _pendingProducts = [];
  List<OrderModel> _orders = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<UserModel> get users => _users;
  List<ShopModel> get shops => _shops;
  List<ProductModel> get pendingProducts => _pendingProducts;
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch all users
  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();
      _users = snapshot.docs
          .map((doc) => UserModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Suspend user
  Future<bool> suspendUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'suspended',
      });
      await fetchUsers();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to suspend user: $e';
      notifyListeners();
      return false;
    }
  }

  // Activate user
  Future<bool> activateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
      });
      await fetchUsers();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to activate user: $e';
      notifyListeners();
      return false;
    }
  }
}
```

## Testing Checklist

### Unit Tests
- [ ] Admin provider methods
- [ ] Data filtering logic
- [ ] Search functionality

### Widget Tests
- [ ] Dashboard displays correctly
- [ ] User list renders
- [ ] Shop list renders
- [ ] Product moderation renders
- [ ] Order list renders

### Integration Tests
- [ ] User suspension works
- [ ] Product approval works
- [ ] Order management works
- [ ] Analytics data loads

### Manual Testing
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test all screens
- [ ] Test search and filter
- [ ] Test bulk actions

## Success Criteria

- [ ] Admin can view all platform metrics
- [ ] Admin can manage users and shops
- [ ] Admin can moderate products
- [ ] Admin can manage orders and coupons
- [ ] Analytics data is accurate and up-to-date
- [ ] All screens load correctly
- [ ] Search and filter work
- [ ] Bulk actions work
- [ ] All tests pass
- [ ] No critical bugs

## Estimated Time: 50-60 hours

### Breakdown:
- Admin dashboard: 8-10 hours
- User management: 8-10 hours
- Shop management: 8-10 hours
- Product moderation: 8-10 hours
- Order management: 6-8 hours
- Coupon management: 4-6 hours
- Analytics: 6-8 hours
- Testing: 8-10 hours

## Next Phase
After completing Phase 17, move to Phase 18: Offline Support

