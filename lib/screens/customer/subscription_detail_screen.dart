import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';

class SubscriptionDetailScreen extends StatefulWidget {
  final Subscription subscription;

  const SubscriptionDetailScreen({Key? key, required this.subscription})
      : super(key: key);

  @override
  State<SubscriptionDetailScreen> createState() =>
      _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  final _subscriptionService = SubscriptionService();
  late List<SubscriptionItem> _items;
  late String _frequency;
  late double _discountPercentage;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.subscription.items);
    _frequency = widget.subscription.frequency;
    _discountPercentage = widget.subscription.discountPercentage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Subscription'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFrequencySection(),
                const SizedBox(height: 24),
                _buildItemsSection(),
                const SizedBox(height: 24),
                _buildDiscountSection(),
                const SizedBox(height: 24),
                _buildSummarySection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading || !_hasChanges ? null : _saveChanges,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'biweekly', label: Text('Bi-Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
          ],
          selected: {_frequency},
          onSelectionChanged: (Set<String> selected) {
            setState(() {
              _frequency = selected.first;
              _hasChanges = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No items in subscription',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          Column(
            children: _items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildItemTile(index, item);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildItemTile(int index, SubscriptionItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product ID: ${item.productId.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: ${item.quantity} @ ₹${item.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _items.removeAt(index);
                  _hasChanges = true;
                });
              },
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    // Placeholder for adding items - would integrate with product catalog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product selection coming soon')),
    );
  }

  Widget _buildDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Discount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Discount %',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                controller: TextEditingController(
                  text: _discountPercentage.toStringAsFixed(2),
                ),
                onChanged: (val) {
                  setState(() {
                    _discountPercentage = double.tryParse(val) ?? 0.0;
                    _hasChanges = true;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${(_calculateBaseAmount() * _discountPercentage / 100).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    final baseAmount = _calculateBaseAmount();
    final discountAmount = baseAmount * _discountPercentage / 100;
    final totalAmount = baseAmount - discountAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.grey200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Base Amount', style: TextStyle(color: AppTheme.grey600)),
                  Text('₹${baseAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: TextStyle(color: AppTheme.grey600)),
                  Text(
                    '- ₹${discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.red),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateBaseAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await _subscriptionService.updateSubscription(
        widget.subscription.id,
        items: _items,
        frequency: _frequency,
        discountPercentage: _discountPercentage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
