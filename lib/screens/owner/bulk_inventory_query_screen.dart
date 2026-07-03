import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_change_request_model.dart';
import '../../services/inventory_query_service.dart';
import '../../services/inventory_change_request_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

/// Task #120 — Bulk Inventory Query Builder
///
/// Excel-style query builder: owner/employee selects filters (category, stock
/// level, price range, expiry threshold), previews matching products, then
/// submits a bulk change request (price / stock adjustment) for owner approval.
class BulkInventoryQueryScreen extends StatefulWidget {
  const BulkInventoryQueryScreen({super.key});

  @override
  State<BulkInventoryQueryScreen> createState() => _BulkInventoryQueryScreenState();
}

class _BulkInventoryQueryScreenState extends State<BulkInventoryQueryScreen> {
  final InventoryQueryService _querySvc = InventoryQueryService();
  final InventoryChangeRequestService _reqSvc = InventoryChangeRequestService();

  // ── Filter state ──────────────────────────────────────────────────────────
  String? _selectedCategory;
  String _stockOperator = '<='; // <=, >=, ==
  double _stockThreshold = 10;
  final double _priceMin = 0;
  final double _priceMax = 10000;
  bool _expiryFilter = false;
  int _expiryDays = 7;

  // ── Change params ─────────────────────────────────────────────────────────
  String _changeType = 'stock_adjustment'; // stock_adjustment | price_update
  final _valueCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isQuerying = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'All',
    'Fruits & Vegetables',
    'Dairy',
    'Grocery',
    'Snacks',
    'Beverages',
    'Personal Care',
    'Household',
  ];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _runQuery() async {
    setState(() {
      _isQuerying = true;
      _results = [];
    });

    final filters = InventoryQueryFilter(
      category: (_selectedCategory == null || _selectedCategory == 'All')
          ? null
          : _selectedCategory,
      stockOperator: _stockOperator,
      stockThreshold: _stockThreshold,
      priceMin: _priceMin > 0 ? _priceMin : null,
      priceMax: _priceMax < 10000 ? _priceMax : null,
      expiryWithinDays: _expiryFilter ? _expiryDays : null,
    );

    final results = await _querySvc.queryProducts(filters);
    setState(() {
      _results = results;
      _isQuerying = false;
    });
  }

  Future<void> _submitRequest() async {
    if (_results.isEmpty) return;
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for this change.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      final value = double.tryParse(_valueCtrl.text.trim()) ?? 0;
      final productIds = _results.map((r) => r['id'] as String).toList();

      await _reqSvc.createBulkRequest(
        requestedBy: user.id,
        requestedByName: user.name ?? 'Staff',
        changeType: _changeType == 'stock_adjustment'
            ? InventoryChangeType.stockAdjustment
            : InventoryChangeType.priceUpdate,
        productIds: productIds,
        value: value,
        reason: _reasonCtrl.text.trim(),
        queryDescription: _buildQueryDescription(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request submitted — awaiting owner approval.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _buildQueryDescription() {
    final parts = <String>[];
    if (_selectedCategory != null && _selectedCategory != 'All') {
      parts.add('Category: $_selectedCategory');
    }
    parts.add('Stock $_stockOperator ${_stockThreshold.toInt()}');
    if (_priceMin > 0 || _priceMax < 10000) {
      parts.add('Price Rs.${_priceMin.toInt()}–${_priceMax.toInt()}');
    }
    if (_expiryFilter) parts.add('Expiry ≤ $_expiryDays days');
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.grey900 : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Bulk Inventory Query', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (_results.isNotEmpty)
            TextButton.icon(
              onPressed: _isSubmitting ? null : _submitRequest,
              icon: const Icon(Icons.send_outlined, color: Colors.white),
              label: const Text('Submit Request', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter panel ─────────────────────────────────────────────────
          Container(
            color: isDark ? AppTheme.grey800 : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 12),
                // Category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory ?? 'All',
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
                const SizedBox(height: 10),
                // Stock
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _stockOperator,
                      items: [
                        '<=',
                        '>=',
                        '==',
                      ].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (v) => setState(() => _stockOperator = v!),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _stockThreshold,
                        min: 0,
                        max: 500,
                        divisions: 50,
                        label: 'Stock ${_stockThreshold.toInt()}',
                        activeColor: const Color(0xFF1565C0),
                        onChanged: (v) => setState(() => _stockThreshold = v),
                      ),
                    ),
                    Text('${_stockThreshold.toInt()} units', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                // Expiry toggle
                Row(
                  children: [
                    Switch.adaptive(
                      value: _expiryFilter,
                      onChanged: (v) => setState(() => _expiryFilter = v),
                      activeColor: const Color(0xFF1565C0),
                    ),
                    const Text('Expiry filter'),
                    if (_expiryFilter) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: _expiryDays.toDouble(),
                          min: 1,
                          max: 90,
                          divisions: 89,
                          label: '$_expiryDays days',
                          activeColor: AppTheme.warning,
                          onChanged: (v) => setState(() => _expiryDays = v.toInt()),
                        ),
                      ),
                      Text('<$_expiryDays days', style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isQuerying ? null : _runQuery,
                    icon: _isQuerying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isQuerying ? 'Querying...' : 'Run Query'),
                  ),
                ),
              ],
            ),
          ),
          // ── Results ────────────────────────────────────────────────────────
          if (_results.isNotEmpty) ...[
            Container(
              color: const Color(0xFFE3F2FD),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_results.length} products matched',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                  ),
                  const Spacer(),
                  // Change type selector
                  DropdownButton<String>(
                    value: _changeType,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'stock_adjustment', child: Text('Stock Adj.')),
                      DropdownMenuItem(value: 'price_update', child: Text('Price Update')),
                    ],
                    onChanged: (v) => setState(() => _changeType = v!),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _valueCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for change (required)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
            ),
          ],
          Expanded(
            child: _results.isEmpty && !_isQuerying
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list, size: 48, color: AppTheme.grey300),
                        SizedBox(height: 8),
                        Text(
                          'Set filters and tap Run Query',
                          style: TextStyle(color: AppTheme.grey500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (ctx, i) {
                      final p = _results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE3F2FD),
                          child: Text(
                            (p['name'] as String? ?? 'P')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(p['name'] as String? ?? ''),
                        subtitle: Text('Stock: ${p['stock'] ?? 0} • Price: Rs.${p['price'] ?? 0}'),
                        trailing: Text(
                          p['category'] as String? ?? '',
                          style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
