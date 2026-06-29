import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../models/inventory_change_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_ledger_service.dart';
import '../../services/inventory_query_service.dart';
import '../../services/inventory_change_request_service.dart';
import '../../utils/app_theme.dart';

class InventoryBulkQueryScreen extends StatefulWidget {
  const InventoryBulkQueryScreen({super.key});

  @override
  State<InventoryBulkQueryScreen> createState() => _InventoryBulkQueryScreenState();
}

class _ConditionRow {
  String field;
  FilterOperator operator;
  String value;
  String value2;

  _ConditionRow({
    this.field = 'name',
    this.operator = FilterOperator.contains,
    this.value = '',
    this.value2 = '',
  });
}

enum _EditValueType { number, text, boolean }

const Map<String, _EditValueType> _kEditableFields = {
  'price': _EditValueType.number,
  'original_price': _EditValueType.number,
  'cost_price': _EditValueType.number,
  'current_stock': _EditValueType.number,
  'reorder_level': _EditValueType.number,
  'discount_percentage': _EditValueType.number,
  'category': _EditValueType.text,
  'subCategory': _EditValueType.text,
  'brand': _EditValueType.text,
  'active': _EditValueType.boolean,
};

const Map<String, String> _kEditableFieldLabels = {
  'price': 'Price',
  'original_price': 'Original Price (MRP)',
  'cost_price': 'Cost Price',
  'current_stock': 'Stock Quantity',
  'reorder_level': 'Minimum Stock',
  'discount_percentage': 'Discount %',
  'category': 'Category',
  'subCategory': 'Sub Category',
  'brand': 'Brand',
  'active': 'Is Available',
};

class _InventoryBulkQueryScreenState extends State<InventoryBulkQueryScreen> {
  final _queryService = InventoryQueryService();
  final _ledgerService = InventoryLedgerService();

  List<_ConditionRow> _conditions = [_ConditionRow()];
  FilterLogic _logic = FilterLogic.and;

  bool _loading = false;
  bool _submitting = false;
  List<ProductModel> _matched = [];
  bool _hasRun = false;

  String _editField = 'price';
  final TextEditingController _editValueController = TextEditingController();
  bool _editBoolValue = true;

  @override
  void dispose() {
    _editValueController.dispose();
    super.dispose();
  }

  List<FilterCondition> _activeConditions() {
    return _conditions
        .where((c) => c.value.trim().isNotEmpty || c.operator == FilterOperator.isEmpty || c.operator == FilterOperator.isNotEmpty)
        .map((c) => FilterCondition(
              field: c.field,
              operator: c.operator,
              value: c.operator == FilterOperator.between ? num.tryParse(c.value) ?? c.value : c.value,
              value2: c.operator == FilterOperator.between ? (num.tryParse(c.value2) ?? c.value2) : null,
            ))
        .toList();
  }

  Future<void> _runQuery() async {
    setState(() => _loading = true);
    try {
      final conditions = _activeConditions();
      _matched = await _queryService.fetchProductsSQL(conditions, logic: _logic);
      _hasRun = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Query failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitForApproval() async {
    if (_matched.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run a query that matches at least one product first.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    dynamic newValue;
    final editType = _kEditableFields[_editField]!;
    switch (editType) {
      case _EditValueType.number:
        final parsed = num.tryParse(_editValueController.text.trim());
        if (parsed == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid number for the new value.')),
          );
          return;
        }
        newValue = parsed;
        break;
      case _EditValueType.text:
        if (_editValueController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a new value.')),
          );
          return;
        }
        newValue = _editValueController.text.trim();
        break;
      case _EditValueType.boolean:
        newValue = _editBoolValue;
        break;
    }

    setState(() => _submitting = true);
    try {
      final filterJson = {
        'logic': _logic.name,
        'conditions': _activeConditions().map((c) => c.toMap()).toList(),
      };
      final changes = {_editField: newValue};

      // 1. Submit bulk operation to Postgres RDSDatabaseService (via InventoryLedgerService)
      final opId = await _ledgerService.submitBulkOperation(
        filterJson: filterJson,
        proposedChange: changes,
        submittedByUserId: user.id,
      );

      // 2. Submit change request to Firestore so it shows up in Owner Approval Queue
      final firestoreField = _mapPostgresToFirestoreField(_editField);
      final List<InventoryFieldChange> fieldChanges = [];
      for (final p in _matched) {
        dynamic oldValue;
        switch (_editField) {
          case 'price':
            oldValue = p.price;
            break;
          case 'original_price':
            oldValue = p.originalPrice;
            break;
          case 'cost_price':
            oldValue = p.costPrice;
            break;
          case 'current_stock':
            oldValue = p.stockQuantity;
            break;
          case 'reorder_level':
            oldValue = p.minimumStock;
            break;
          case 'discount_percentage':
            oldValue = p.discountPercentage;
            break;
          case 'category':
            oldValue = p.category;
            break;
          case 'subCategory':
            oldValue = p.subCategory;
            break;
          case 'brand':
            oldValue = p.brand;
            break;
          case 'active':
            oldValue = p.isAvailable;
            break;
        }
        fieldChanges.add(InventoryFieldChange(
          productId: p.id,
          productName: p.name,
          field: firestoreField,
          oldValue: oldValue,
          newValue: newValue,
        ));
      }

      final requestModel = InventoryChangeRequestModel(
        id: '',
        type: _mapFieldToChangeType(_editField),
        status: InventoryChangeRequestStatus.pending,
        filterDescription: _queryService.describeConditions(_activeConditions(), _logic),
        note: 'Submitted via Bulk Query Builder. SQL Op ID: $opId',
        changes: fieldChanges,
        requestedBy: user.id,
        requestedByName: user.name ?? 'Staff',
        createdAt: DateTime.now(),
      );

      final changeRequestId = await InventoryChangeRequestService().createChangeRequest(requestModel);

      if (mounted) {
        if (opId != null && changeRequestId.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bulk operation submitted for owner approval. ID: $changeRequestId'),
              backgroundColor: AppTheme.success,
            ),
          );
          setState(() {
            _matched = [];
            _hasRun = false;
            _editValueController.clear();
          });
        } else {
          throw Exception('Backend or Firestore submission failed');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapPostgresToFirestoreField(String pgField) {
    switch (pgField) {
      case 'original_price':
        return 'originalPrice';
      case 'cost_price':
        return 'costPrice';
      case 'current_stock':
        return 'stockQuantity';
      case 'reorder_level':
        return 'minimumStock';
      case 'discount_percentage':
        return 'discountPercentage';
      case 'active':
        return 'isAvailable';
      default:
        return pgField;
    }
  }

  InventoryChangeType _mapFieldToChangeType(String pgField) {
    switch (pgField) {
      case 'price':
      case 'original_price':
      case 'discount_percentage':
        return InventoryChangeType.priceChange;
      case 'current_stock':
      case 'reorder_level':
        return InventoryChangeType.stockAdjustment;
      case 'active':
        return InventoryChangeType.availabilityToggle;
      default:
        return InventoryChangeType.fieldUpdate;
    }
  }

  void _addCondition() {
    setState(() => _conditions.add(_ConditionRow()));
  }

  void _removeCondition(int index) {
    setState(() => _conditions.removeAt(index));
  }

  Future<void> _saveQueryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Query', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Query Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    
    if (name != null && name.trim().isNotEmpty) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        await _queryService.saveQuery(name, _activeConditions(), _logic, user.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Query saved!')));
      }
    }
  }

  Future<void> _loadQueryDialog() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final queries = await _queryService.getSavedQueries(user.id);
    if (!mounted) return;

    if (queries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved queries found.')));
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: queries.length,
        itemBuilder: (ctx, i) {
          final q = queries[i];
          return ListTile(
            title: Text(q['query_name'] as String? ?? 'Unnamed'),
            subtitle: Text('Saved on ${q['created_at']}'),
            onTap: () => Navigator.pop(ctx, q),
          );
        },
      ),
    );

    if (selected != null) {
      final filterJson = (selected['filter_json'] is String)
          ? jsonDecode(selected['filter_json'] as String)
          : selected['filter_json'];
      setState(() {
        final map = filterJson as Map<String, dynamic>;
        _logic = map['logic'] == 'or' ? FilterLogic.or : FilterLogic.and;
        _conditions = (map['conditions'] as List).map((c) {
          final cond = FilterCondition.fromMap(c as Map<String, dynamic>);
          return _ConditionRow(
            field: cond.field,
            operator: cond.operator,
            value: cond.value?.toString() ?? '',
            value2: cond.value2?.toString() ?? '',
          );
        }).toList();
        if (_conditions.isEmpty) _conditions.add(_ConditionRow());
        _matched = [];
        _hasRun = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Bulk Inventory Query & Update', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        actions: [
          IconButton(icon: const Icon(Icons.bookmark_add), onPressed: _saveQueryDialog, tooltip: 'Save Query'),
          IconButton(icon: const Icon(Icons.folder_open), onPressed: _loadQueryDialog, tooltip: 'Load Query'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterCard(),
            const SizedBox(height: 16),
            if (_hasRun) _buildResultsCard(),
            if (_matched.isNotEmpty) const SizedBox(height: 16),
            if (_matched.isNotEmpty) _buildBulkUpdateCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Filter conditions (SQL)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const Text('Combine with:'),
                const SizedBox(width: 8),
                DropdownButton<FilterLogic>(
                  value: _logic,
                  items: const [
                    DropdownMenuItem(value: FilterLogic.and, child: Text('AND')),
                    DropdownMenuItem(value: FilterLogic.or, child: Text('OR')),
                  ],
                  onChanged: (v) => setState(() => _logic = v ?? FilterLogic.and),
                ),
              ],
            ),
            const Text(
              'Dynamic SQL execution on AWS RDS.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
            const SizedBox(height: 8),
            ...List.generate(_conditions.length, (i) => _buildConditionRow(i)),
            TextButton.icon(
              onPressed: _addCondition,
              icon: const Icon(Icons.add),
              label: const Text('Add condition'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _runQuery,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Run SQL Query'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionRow(int index) {
    final c = _conditions[index];
    final needsValue2 = c.operator == FilterOperator.between;
    final needsValue = c.operator != FilterOperator.isEmpty && c.operator != FilterOperator.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: c.field,
              decoration: const InputDecoration(labelText: 'Field', isDense: true),
              items: InventoryQueryService.queryableFields.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => c.field = v ?? c.field),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<FilterOperator>(
              initialValue: c.operator,
              decoration: const InputDecoration(labelText: 'Condition', isDense: true),
              items: FilterOperator.values
                  .map((op) => DropdownMenuItem(value: op, child: Text(op.label, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => c.operator = v ?? c.operator),
            ),
          ),
          if (needsValue)
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: c.value,
                decoration: const InputDecoration(labelText: 'Value', isDense: true),
                onChanged: (v) => c.value = v,
              ),
            ),
          if (needsValue2)
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: c.value2,
                decoration: const InputDecoration(labelText: 'And', isDense: true),
                onChanged: (v) => c.value2 = v,
              ),
            ),
          if (_conditions.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: () => _removeCondition(index),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found ${_matched.length} product(s) (Limited to 500)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (_matched.isEmpty)
              const Text('No products match this filter.', style: TextStyle(color: AppTheme.grey500))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _matched.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _matched[i];
                    return ListTile(
                      dense: true,
                      title: Text(p.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${p.category} • Stock: ${p.stockQuantity} • ₹${p.price}'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkUpdateCard() {
    final editType = _kEditableFields[_editField]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bulk update matched products',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
              'Choose a field and a new value to apply to EVERY matched product atomically.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _editField,
                    decoration: const InputDecoration(labelText: 'Field to update', isDense: true),
                    items: _kEditableFieldLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _editField = v ?? _editField;
                      _editValueController.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: editType == _EditValueType.boolean
                      ? DropdownButtonFormField<bool>(
                          initialValue: _editBoolValue,
                          decoration: const InputDecoration(labelText: 'New value', isDense: true),
                          items: const [
                            DropdownMenuItem(value: true, child: Text('True')),
                            DropdownMenuItem(value: false, child: Text('False')),
                          ],
                          onChanged: (v) => setState(() => _editBoolValue = v ?? true),
                        )
                      : TextFormField(
                          controller: _editValueController,
                          keyboardType:
                              editType == _EditValueType.number ? TextInputType.number : TextInputType.text,
                          decoration: const InputDecoration(labelText: 'New value', isDense: true),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submitForApproval,
                icon: _submitting
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Submit Bulk Operation for Owner Approval'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: AppTheme.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
