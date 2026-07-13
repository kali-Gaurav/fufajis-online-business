import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import 'dart:async';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  final List<QueryDocumentSnapshot> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final int _limit = 20;
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _users.clear();
      _lastDoc = null;
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      Query q = _firestore.collection('users').limit(_limit);

      if (_searchQuery.isNotEmpty) {
        // Prefix search on phone number
        q = q
            .where('phoneNumber', isGreaterThanOrEqualTo: _searchQuery)
            .where('phoneNumber', isLessThan: '$_searchQuery\uf8ff')
            .orderBy('phoneNumber');
      } else {
        q = q.orderBy('createdAt', descending: true);
      }

      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      if (snap.docs.length < _limit) {
        _hasMore = false;
      }
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        _users.addAll(snap.docs);
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query.trim()) {
        setState(() {
          _searchQuery = query.trim();
        });
        _fetchUsers(refresh: true);
      }
    });
  }

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
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Filter tapped')));
                  },
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
                  hintText: 'Search by Phone Number prefix (+91...)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Theme(
                  data: Theme.of(context).copyWith(cardColor: Colors.white),
                  child: Stack(
                    children: [
                      PaginatedDataTable(
                        header: const Text('All Registered Users'),
                        columns: const [
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Wallet Balance')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        source: _UserDataTableSource(context, _users, _hasMore, () {
                          // Fetch more callback
                          _fetchUsers();
                        }),
                        rowsPerPage: 10,
                        showCheckboxColumn: false,
                        onPageChanged: (firstRowIndex) {
                          // If we're getting close to the end, fetch more
                          if (firstRowIndex + 10 >= _users.length && _hasMore) {
                            _fetchUsers();
                          }
                        },
                      ),
                      if (_isLoading && _users.isEmpty)
                        const Center(child: CircularProgressIndicator(color: AppTheme.adminAccent))
                      else if (_isLoading)
                        const Positioned(
                          top: 16,
                          right: 16,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                ),
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
  final bool hasMore;
  final VoidCallback fetchMore;

  _UserDataTableSource(this.context, this.users, this.hasMore, this.fetchMore);

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final userDoc = users[index];
    final data = userDoc.data() as Map<String, dynamic>;

    final phone = data['phoneNumber'] as String? ?? 'N/A';
    final role = data['role'] as String? ?? 'customer';
    final balance = (data['walletBalance'] ?? 0).toString();
    final isBlocked = data['isBlocked'] as bool? ?? false;

    return DataRow(
      cells: [
        DataCell(Text(phone)),
        DataCell(
          Chip(
            label: Text(role.toString().toUpperCase(), style: const TextStyle(fontSize: 10)),
            backgroundColor: role == 'admin'
                ? AppTheme.error.withOpacity(0.1)
                : role == 'shop_owner'
                ? AppTheme.warning.withOpacity(0.1)
                : AppTheme.adminAccent.withOpacity(0.1),
          ),
        ),
        DataCell(Text('₹$balance', style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isBlocked
                  ? AppTheme.error.withOpacity(0.1)
                  : AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isBlocked ? 'BLOCKED' : 'ACTIVE',
              style: TextStyle(color: isBlocked ? AppTheme.error : AppTheme.success, fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_red_eye, color: AppTheme.primary, size: 18),
                tooltip: 'View Details',
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Add New User tapped')));
                },
              ),
              IconButton(
                icon: Icon(
                  isBlocked ? Icons.lock_open : Icons.block,
                  color: isBlocked ? AppTheme.success : AppTheme.error,
                  size: 18,
                ),
                tooltip: isBlocked ? 'Unblock User' : 'Block User',
                onPressed: () {
                  // Toggle block status
                  FirebaseFirestore.instance.collection('users').doc(userDoc.id).update({
                    'isBlocked': !isBlocked,
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => hasMore;

  @override
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}
