import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupplierAutoOrderConfigScreen extends StatefulWidget {
  final String supplierId;

  const SupplierAutoOrderConfigScreen({
    Key? key,
    required this.supplierId,
  }) : super(key: key);

  @override
  State<SupplierAutoOrderConfigScreen> createState() =>
      _SupplierAutoOrderConfigScreenState();
}

class _SupplierAutoOrderConfigScreenState
    extends State<SupplierAutoOrderConfigScreen> {
  final _supabase = Supabase.instance;
  List<ReorderRule> _rules = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReorderRules();
  }

  Future<void> _loadReorderRules() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.client
          .from('supplier_reorder_rules')
          .select()
          .eq('supplier_id', widget.supplierId)
          .eq('active', true);

      setState(() {
        _rules = response.map((r) => ReorderRule.fromJson(r)).toList();
      });
    } catch (e) {
      debugPrint('Error loading reorder rules: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Order Configuration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text('No auto-order rules configured'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddRuleDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Rule'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rules.length,
                  itemBuilder: (_, index) => _buildRuleCard(_rules[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRuleDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRuleCard(ReorderRule rule) {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product: ${rule.productId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reorder at: ${rule.reorderPoint} units',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit'),
                      onTap: () => _showEditRuleDialog(rule),
                    ),
                    PopupMenuItem(
                      child: const Text('Delete'),
                      onTap: () => _deleteRule(rule.id),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Quantity', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      rule.orderQuantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unit Price', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '₹${rule.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lead Time', style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '${rule.leadTimeDays}d',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Discount: ${rule.discountPercentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddRuleDialog() async {
    final formKey = GlobalKey<FormState>();
    String productId = '';
    int reorderPoint = 10;
    int orderQty = 50;
    double unitPrice = 0;
    double discount = 0;
    int leadTime = 1;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Reorder Rule'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Product ID'),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onChanged: (v) => productId = v,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Reorder Point (units)'),
                  keyboardType: TextInputType.number,
                  initialValue: '10',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onChanged: (v) => reorderPoint = int.tryParse(v) ?? 10,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Order Quantity (units)'),
                  keyboardType: TextInputType.number,
                  initialValue: '50',
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onChanged: (v) => orderQty = int.tryParse(v) ?? 50,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Unit Price (₹)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  onChanged: (v) => unitPrice = double.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Discount (%)'),
                  keyboardType: TextInputType.number,
                  initialValue: '0',
                  onChanged: (v) => discount = double.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Lead Time (days)'),
                  keyboardType: TextInputType.number,
                  initialValue: '1',
                  onChanged: (v) => leadTime = int.tryParse(v) ?? 1,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _saveRule(
                  productId: productId,
                  reorderPoint: reorderPoint,
                  orderQty: orderQty,
                  unitPrice: unitPrice,
                  discount: discount,
                  leadTime: leadTime,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditRuleDialog(ReorderRule rule) async {
    final formKey = GlobalKey<FormState>();
    int reorderPoint = rule.reorderPoint;
    int orderQty = rule.orderQuantity;
    double unitPrice = rule.unitPrice;
    double discount = rule.discountPercentage;
    int leadTime = rule.leadTimeDays;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Reorder Rule'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Reorder Point (units)'),
                  keyboardType: TextInputType.number,
                  initialValue: rule.reorderPoint.toString(),
                  onChanged: (v) => reorderPoint = int.tryParse(v) ?? rule.reorderPoint,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Order Quantity (units)'),
                  keyboardType: TextInputType.number,
                  initialValue: rule.orderQuantity.toString(),
                  onChanged: (v) => orderQty = int.tryParse(v) ?? rule.orderQuantity,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Unit Price (₹)'),
                  keyboardType: TextInputType.number,
                  initialValue: rule.unitPrice.toStringAsFixed(2),
                  onChanged: (v) => unitPrice = double.tryParse(v) ?? rule.unitPrice,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Discount (%)'),
                  keyboardType: TextInputType.number,
                  initialValue: rule.discountPercentage.toStringAsFixed(1),
                  onChanged: (v) => discount = double.tryParse(v) ?? rule.discountPercentage,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Lead Time (days)'),
                  keyboardType: TextInputType.number,
                  initialValue: rule.leadTimeDays.toString(),
                  onChanged: (v) => leadTime = int.tryParse(v) ?? rule.leadTimeDays,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateRule(
                rule.id,
                reorderPoint: reorderPoint,
                orderQty: orderQty,
                unitPrice: unitPrice,
                discount: discount,
                leadTime: leadTime,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRule({
    required String productId,
    required int reorderPoint,
    required int orderQty,
    required double unitPrice,
    required double discount,
    required int leadTime,
  }) async {
    try {
      await _supabase.client.from('supplier_reorder_rules').insert({
        'supplier_id': widget.supplierId,
        'product_id': productId,
        'shop_id': 'default_shop', // Replace with actual shop_id
        'reorder_point': reorderPoint,
        'order_quantity': orderQty,
        'unit_price': unitPrice,
        'discount_percentage': discount,
        'lead_time_days': leadTime,
        'active': true,
      });

      await _loadReorderRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateRule(
    String ruleId, {
    required int reorderPoint,
    required int orderQty,
    required double unitPrice,
    required double discount,
    required int leadTime,
  }) async {
    try {
      await _supabase.client
          .from('supplier_reorder_rules')
          .update({
            'reorder_point': reorderPoint,
            'order_quantity': orderQty,
            'unit_price': unitPrice,
            'discount_percentage': discount,
            'lead_time_days': leadTime,
          })
          .eq('id', ruleId);

      await _loadReorderRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    try {
      await _supabase.client
          .from('supplier_reorder_rules')
          .update({'active': false})
          .eq('id', ruleId);

      await _loadReorderRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class ReorderRule {
  final String id;
  final String productId;
  final int reorderPoint;
  final int orderQuantity;
  final double unitPrice;
  final double discountPercentage;
  final int leadTimeDays;

  ReorderRule({
    required this.id,
    required this.productId,
    required this.reorderPoint,
    required this.orderQuantity,
    required this.unitPrice,
    required this.discountPercentage,
    required this.leadTimeDays,
  });

  factory ReorderRule.fromJson(Map<String, dynamic> json) {
    return ReorderRule(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      reorderPoint: json['reorder_point'] ?? 0,
      orderQuantity: json['order_quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      discountPercentage: (json['discount_percentage'] ?? 0.0).toDouble(),
      leadTimeDays: json['lead_time_days'] ?? 1,
    );
  }
}
