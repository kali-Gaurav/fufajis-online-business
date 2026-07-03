import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, pending, approved, suspended

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchShops();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    // Apply filtering and search
    final filteredShops = adminProvider.shops.where((shop) {
      final name = (shop['name'] ?? '').toString().toLowerCase();
      final ownerName = (shop['ownerName'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery) || ownerName.contains(_searchQuery);

      if (_selectedFilter == 'all') return matchesSearch;
      final status = (shop['status'] ?? 'pending').toString().toLowerCase();
      return matchesSearch && status == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shop Moderation & Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.fetchShops(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Search Bar
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Shop Name or Owner',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Filter chips
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedFilter == 'all',
                  onSelected: (_) => setState(() => _selectedFilter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending Approval'),
                  selected: _selectedFilter == 'pending',
                  onSelected: (_) => setState(() => _selectedFilter = 'pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Approved'),
                  selected: _selectedFilter == 'approved',
                  onSelected: (_) => setState(() => _selectedFilter = 'approved'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Suspended'),
                  selected: _selectedFilter == 'suspended',
                  onSelected: (_) => setState(() => _selectedFilter = 'suspended'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: adminProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent))
                  : filteredShops.isEmpty
                  ? const Center(child: Text('No shops found.'))
                  : Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: filteredShops.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final shop = filteredShops[index];
                          return _buildShopTile(context, shop, adminProvider);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopTile(BuildContext context, Map<String, dynamic> shop, AdminProvider provider) {
    final status = (shop['status'] ?? 'pending').toString().toUpperCase();
    final name = shop['name'] as String? ?? 'No Name';
    final ownerName = shop['ownerName'] as String? ?? 'Unknown Owner';
    final district = shop['district'] as String? ?? 'N/A';
    final phone = shop['phone'] as String? ?? 'N/A';
    final shopId = shop['id'] as String? ?? '';

    Color statusColor = AppTheme.warning;
    if (status == 'APPROVED') statusColor = AppTheme.success;
    if (status == 'SUSPENDED') statusColor = AppTheme.error;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.store, color: AppTheme.primary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Owner: $ownerName | District: $district'),
          Text('Phone: $phone'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'approve') {
                provider.updateShopStatus(shopId, 'approved');
              } else if (action == 'suspend') {
                provider.updateShopStatus(shopId, 'suspended');
              } else if (action == 'pending') {
                provider.updateShopStatus(shopId, 'pending');
              }
            },
            itemBuilder: (context) => [
              if (status != 'APPROVED')
                const PopupMenuItem(value: 'approve', child: Text('Approve Shop')),
              if (status != 'SUSPENDED')
                const PopupMenuItem(value: 'suspend', child: Text('Suspend Shop')),
              if (status != 'PENDING')
                const PopupMenuItem(value: 'pending', child: Text('Set to Pending')),
            ],
          ),
        ],
      ),
    );
  }
}
