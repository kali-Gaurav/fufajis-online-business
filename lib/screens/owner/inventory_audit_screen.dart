import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../services/audit_service.dart';

class InventoryAuditScreen extends StatefulWidget {
  const InventoryAuditScreen({super.key});

  @override
  State<InventoryAuditScreen> createState() => _InventoryAuditScreenState();
}

class _InventoryAuditScreenState extends State<InventoryAuditScreen> {
  final AuditService _auditService = AuditService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Audit Logs'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _auditService.getLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var logs = snapshot.data ?? [];

                // Filter logs to only show stockAdjustment and matching search query
                logs = logs.where((log) {
                  final isStockAction =
                      log['action'] == 'AuditAction.stockAdjustment';
                  final matchesSearch = log['description']
                      .toString()
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                  return isStockAction && matchesSearch;
                }).toList();

                if (logs.isEmpty) {
                  return const Center(child: Text('No audit logs found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildAuditLogTile(log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search by product name...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppTheme.grey100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(Map<String, dynamic> log) {
    final timestamp = (log['timestamp'] as dynamic)?.toDate() ?? DateTime.now();
    final metadata = log['metadata'] as Map<String, dynamic>? ?? {};
    final oldStock = metadata['oldStock'] ?? 0;
    final newStock = metadata['newStock'] ?? 0;
    final diff = newStock - oldStock;
    final color = diff >= 0 ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              diff >= 0
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['description'] ?? 'Stock Adjustment',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'By ${log['userName']} • ${DateFormat('dd MMM, hh:mm a').format(timestamp)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStockChip('Old: $oldStock', AppTheme.grey500),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: AppTheme.grey400,
                      ),
                      const SizedBox(width: 8),
                      _buildStockChip('New: $newStock', color),
                      const Spacer(),
                      Text(
                        '${diff >= 0 ? "+" : ""}$diff',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
