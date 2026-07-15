import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/scanner_service.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScanActivityScreen — Owner's real-time scan audit monitor
//
// Shows all employee scan events in real-time:
//   - Who scanned, which mode, what barcode, when
//   - Filter by mode, employee, date range
//   - Color-coded by scan type
// ─────────────────────────────────────────────────────────────────────────────

class ScanActivityScreen extends StatefulWidget {
  const ScanActivityScreen({super.key});

  @override
  State<ScanActivityScreen> createState() => _ScanActivityScreenState();
}

class _ScanActivityScreenState extends State<ScanActivityScreen> {
  String _filterMode = 'all';
  String _filterRole = 'all';
  final int _limitCount = 50;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shopId = auth.currentShop?.id ?? 'shop_001';
    final branchId = auth.currentBranch?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Activity', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
        ],
      ),
      body: Column(
        children: [
          // Active filters chips
          if (_filterMode != 'all' || _filterRole != 'all')
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Filters: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  if (_filterMode != 'all')
                    _FilterChip(
                      label: ScanMode.find(_filterMode)?.label ?? _filterMode,
                      onRemove: () => setState(() => _filterMode = 'all'),
                    ),
                  if (_filterRole != 'all')
                    _FilterChip(
                      label: _filterRole.toUpperCase(),
                      onRemove: () => setState(() => _filterRole = 'all'),
                    ),
                ],
              ),
            ),

          // Live stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStream(shopId: shopId, branchId: branchId ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.ownerAccent),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // Client-side filter by mode/role (Firestore compound
                // queries need composite indexes; client-filter is safe
                // for small result sets up to the limit).
                final filtered = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  if (_filterMode != 'all' && data['actionType'] != _filterMode) {
                    return false;
                  }
                  if (_filterRole != 'all' && data['employeeRole'] != _filterRole) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No scan activity found', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _ScanLogTile(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildStream({required String shopId, required String branchId}) {
    Query query = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('scan_logs')
        .orderBy('createdAt', descending: true)
        .limit(_limitCount);

    if (branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return query.snapshots();
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Scan Activity',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Scan Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PickChip(
                    label: 'All',
                    selected: _filterMode == 'all',
                    onTap: () {
                      setModalState(() {});
                      setState(() => _filterMode = 'all');
                    },
                  ),
                  ...ScanMode.all.map(
                    (m) => _PickChip(
                      label: m.label,
                      color: m.color,
                      selected: _filterMode == m.id,
                      onTap: () {
                        setModalState(() {});
                        setState(() => _filterMode = m.id);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['all', 'owner', 'employee', 'delivery']
                    .map(
                      (r) => _PickChip(
                        label: r == 'all' ? 'All' : r.toUpperCase(),
                        selected: _filterRole == r,
                        onTap: () {
                          setModalState(() {});
                          setState(() => _filterRole = r);
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single scan log tile
// ─────────────────────────────────────────────────────────────────────────────

class _ScanLogTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ScanLogTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final actionType = data['actionType'] as String? ?? '';
    final modeConfig = ScanMode.find(actionType);
    final color = modeConfig?.color ?? Colors.grey;

    final employeeName = data['employeeName'] as String? ?? 'Unknown';
    final employeeRole = data['employeeRole'] as String? ?? '';
    final actionLabel = data['actionLabel'] as String? ?? actionType;
    final scanCode = data['scanCode'] as String? ?? '';
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final timeStr = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts) : '—';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mode icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(modeConfig?.icon ?? Icons.qr_code, color: color, size: 20),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                    ),
                    const SizedBox(width: 6),
                    if (employeeRole.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _roleColor(employeeRole).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          employeeRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: _roleColor(employeeRole),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(employeeName, style: const TextStyle(fontSize: 12)),
                Text(
                  _truncate(scanCode, 30),
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),

          // Timestamp
          Text(
            timeStr,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return AppTheme.ownerAccent;
      case 'delivery':
        return AppTheme.success;
      default:
        return AppTheme.warning;
    }
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}…';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _PickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _PickChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.grey.shade300, width: selected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? c : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
