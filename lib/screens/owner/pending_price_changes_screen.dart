import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pending Price Changes Screen
/// Displays pending price changes for review and approval
class PendingPriceChangesScreen extends StatefulWidget {
  const PendingPriceChangesScreen({super.key});

  @override
  State<PendingPriceChangesScreen> createState() =>
      _PendingPriceChangesScreenState();
}

class _PendingPriceChangesScreenState extends State<PendingPriceChangesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingChanges = [];
  List<Map<String, dynamic>> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPendingChanges();
  }

  Future<void> _loadPendingChanges() async {
    setState(() => _isLoading = true);
    try {
      // Load pending changes from provider
      final pendingChanges = await _fetchPendingChanges();
      final approvalHistory = await _fetchApprovalHistory();

      setState(() {
        _pendingChanges = pendingChanges;
        _approvalHistory = approvalHistory;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading changes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPendingChanges() async {
    // Mock data - replace with actual provider call
    return [
      {
        'id': '1',
        'productName': 'Organic Apples',
        'productId': 'prod_001',
        'oldPrice': 150.0,
        'newPrice': 135.0,
        'reason': 'Competitor price match',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
        'affectedProducts': 1,
      },
      {
        'id': '2',
        'productName': 'Fresh Milk',
        'productId': 'prod_002',
        'oldPrice': 60.0,
        'newPrice': 65.0,
        'reason': 'Cost increase',
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)),
        'affectedProducts': 1,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _fetchApprovalHistory() async {
    // Mock data - replace with actual provider call
    return [
      {
        'id': 'hist_1',
        'productName': 'Tomatoes',
        'oldPrice': 40.0,
        'newPrice': 38.0,
        'status': 'Approved',
        'approvedAt': DateTime.now().subtract(const Duration(days: 1)),
        'reason': 'Seasonal discount',
      },
      {
        'id': 'hist_2',
        'productName': 'Onions',
        'oldPrice': 30.0,
        'newPrice': 35.0,
        'status': 'Rejected',
        'rejectedAt': DateTime.now().subtract(const Duration(days: 2)),
        'reason': 'Price increase too high',
      },
    ];
  }

  Future<void> _approvePriceChange(Map<String, dynamic> change) async {
    setState(() => _isLoading = true);
    try {
      // Call provider to approve price change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price change approved')),
      );

      await _loadPendingChanges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving change: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectPriceChange(Map<String, dynamic> change) async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    setState(() => _isLoading = true);
    try {
      // Call provider to reject price change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price change rejected')),
      );

      await _loadPendingChanges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting change: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveAll() async {
    setState(() => _isLoading = true);
    try {
      for (final change in _pendingChanges) {
        await _approvePriceChange(change);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All price changes approved')),
      );

      await _loadPendingChanges();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving all changes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Price Change'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Price Changes'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab Bar
                  TabBar(
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Pending'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _pendingChanges.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Tab(child: Text('History')),
                    ],
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Pending Changes Tab
                        _buildPendingChangesTab(),

                        // History Tab
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPendingChangesTab() {
    if (_pendingChanges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending changes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All price changes have been reviewed',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Approve All Button
        if (_pendingChanges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _approveAll,
                child: const Text('Approve All Changes'),
              ),
            ),
          ),

        // Changes List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingChanges.length,
            itemBuilder: (context, index) {
              final change = _pendingChanges[index];
              final priceChange = change['newPrice'] - change['oldPrice'];
              final percentChange = (priceChange / change['oldPrice']) * 100;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  change['productName'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'SKU: ${change['productId']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: priceChange > 0
                                  ? Colors.red[100]
                                  : Colors.green[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${priceChange > 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: priceChange > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Price Comparison
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '₹${change['oldPrice'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.arrow_forward, color: Colors.grey[400]),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'New Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '₹${change['newPrice'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Reason and Timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reason',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  change['reason'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, HH:mm').format(change['createdAt']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rejectPriceChange(change),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _approvePriceChange(change),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_approvalHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'No history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Price change history will appear here',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvalHistory.length,
      itemBuilder: (context, index) {
        final item = _approvalHistory[index];
        final isApproved = item['status'] == 'Approved';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['productName'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(
                          color: isApproved ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price Change
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item['oldPrice'].toStringAsFixed(2)} → ₹${item['newPrice'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(
                        item['approvedAt'] ?? item['rejectedAt'],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason
                Text(
                  'Reason: ${item['reason']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
