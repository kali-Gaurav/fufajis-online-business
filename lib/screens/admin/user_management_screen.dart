import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search Bar
            SizedBox(
              width: 400,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Phone Number or Name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // In production, this should be paginated rather than loading all users
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final users = snapshot.data?.docs ?? [];

                  // Filter by search query
                  final filteredUsers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final phone = (data['phoneNumber'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(cardColor: Colors.white),
                      child: PaginatedDataTable(
                        header: const Text('All Registered Users'),
                        columns: const [
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Wallet Balance')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        source: _UserDataTableSource(context, filteredUsers),
                        rowsPerPage: 10,
                        showCheckboxColumn: false,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserDataTableSource extends DataTableSource {
  final BuildContext context;
  final List<QueryDocumentSnapshot> users;

  _UserDataTableSource(this.context, this.users);

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final userDoc = users[index];
    final data = userDoc.data() as Map<String, dynamic>;

    final phone = data['phoneNumber'] ?? 'N/A';
    final role = data['role'] ?? 'customer';
    final balance = (data['walletBalance'] ?? 0).toString();
    final isBlocked = data['isBlocked'] ?? false;

    return DataRow(
      cells: [
        DataCell(Text(phone)),
        DataCell(
          Chip(
            label: Text(
              role.toString().toUpperCase(),
              style: const TextStyle(fontSize: 10),
            ),
            backgroundColor: role == 'admin'
                ? Colors.red.withValues(alpha: 0.1)
                : role == 'shop_owner'
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.blue.withValues(alpha: 0.1),
          ),
        ),
        DataCell(
          Text(
            '₹$balance',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isBlocked
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isBlocked ? 'BLOCKED' : 'ACTIVE',
              style: TextStyle(
                color: isBlocked ? Colors.red : Colors.green,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_red_eye,
                  color: AppTheme.primary,
                  size: 18,
                ),
                tooltip: 'View Details',
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  isBlocked ? Icons.lock_open : Icons.block,
                  color: isBlocked ? Colors.green : Colors.red,
                  size: 18,
                ),
                tooltip: isBlocked ? 'Unblock User' : 'Block User',
                onPressed: () {
                  // Toggle block status
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(userDoc.id)
                      .update({'isBlocked': !isBlocked});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}
