import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';

class SubscriptionCheckoutScreen extends StatefulWidget {
  final List<SubscriptionItem>? items;

  const SubscriptionCheckoutScreen({Key? key, this.items}) : super(key: key);

  @override
  State<SubscriptionCheckoutScreen> createState() =>
      _SubscriptionCheckoutScreenState();
}

class _SubscriptionCheckoutScreenState extends State<SubscriptionCheckoutScreen> {
  final _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance;

  late List<SubscriptionItem> _items;
  String _frequency = 'weekly';
  double _discountPercentage = 0.0;
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  int _agreedCount = 0;

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? [];
    _loadCheckoutItems();
  }

  Future<void> _loadCheckoutItems() async {
    setState(() {
      // Items are already set from widget or will be set from route extra
      if (_items.isEmpty) {
        debugPrint('No items provided to checkout screen');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe Now'),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemsReview(),
                  const SizedBox(height: 24),
                  _buildFrequencySelector(),
                  const SizedBox(height: 24),
                  _buildDiscountInput(),
                  const SizedBox(height: 24),
                  _buildPricingSummary(),
                  const SizedBox(height: 24),
                  _buildPaymentMethodSelector(),
                  const SizedBox(height: 24),
                  _buildTermsAndConditions(),
                  const SizedBox(height: 24),
                  _buildSubscribeButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildItemsReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items in Subscription',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No items selected',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          Column(
            children: _items.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Qty: ${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@ ₹${item.unitPrice.toStringAsFixed(2)}/unit',
                              style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Frequency',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'biweekly', label: Text('Bi-Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
          ],
          selected: {_frequency},
          onSelectionChanged: (Set<String> selected) {
            setState(() => _frequency = selected.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          _getFrequencyDescription(_frequency),
          style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
        ),
      ],
    );
  }

  Widget _buildDiscountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Apply Discount',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter discount percentage (0-100)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: '%',
          ),
          onChanged: (val) {
            setState(() {
              _discountPercentage = double.tryParse(val) ?? 0.0;
              if (_discountPercentage > 100) _discountPercentage = 100;
              if (_discountPercentage < 0) _discountPercentage = 0;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPricingSummary() {
    final baseAmount = _calculateBaseAmount();
    final discountAmount = baseAmount * _discountPercentage / 100;
    final totalAmount = baseAmount - discountAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Base Amount', '₹${baseAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Discount (${_discountPercentage.toStringAsFixed(0)}%)',
            '- ₹${discountAmount.toStringAsFixed(2)}',
            isDiscount: true,
          ),
          const Divider(height: 16),
          _buildSummaryRow(
            'Total per ${_getFrequencyLabel(_frequency)}',
            '₹${totalAmount.toStringAsFixed(2)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isDiscount = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
            color: isDiscount ? Colors.red : (isBold ? AppTheme.grey900 : AppTheme.grey600),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 18 : 14,
            color: isDiscount ? Colors.red : (isBold ? AppTheme.primary : AppTheme.grey900),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        RadioListTile<String>(
          title: const Text('UPI / Card'),
          subtitle: const Text('Pay now for automatic renewals'),
          value: 'online',
          groupValue: _selectedPaymentMethod,
          onChanged: (val) => setState(() => _selectedPaymentMethod = val),
        ),
        RadioListTile<String>(
          title: const Text('Wallet'),
          subtitle: const Text('Use wallet balance'),
          value: 'wallet',
          groupValue: _selectedPaymentMethod,
          onChanged: (val) => setState(() => _selectedPaymentMethod = val),
        ),
      ],
    );
  }

  Widget _buildTermsAndConditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text(
            'I agree to automatic recurring charges every ${_getFrequencyLabel("weekly")}',
            style: TextStyle(fontSize: 13),
          ),
          value: _agreedCount > 0,
          onChanged: (val) => setState(() => _agreedCount = (val ?? false) ? 1 : 0),
        ),
        CheckboxListTile(
          title: const Text(
            'I can cancel or pause anytime',
            style: TextStyle(fontSize: 13),
          ),
          value: _agreedCount > 1,
          onChanged: (val) => setState(() => _agreedCount = (val ?? false) ? 2 : (_agreedCount > 0 ? 1 : 0)),
        ),
      ],
    );
  }

  Widget _buildSubscribeButton() {
    final isValid = _items.isNotEmpty && _selectedPaymentMethod != null && _agreedCount > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: isValid && !_isProcessing ? _processSubscription : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppTheme.primary,
          ),
          child: Text(
            _isProcessing ? 'Processing...' : 'Create Subscription',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (!isValid)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Please complete all fields and agree to terms',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[600], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _processSubscription() async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final baseAmount = _calculateBaseAmount();
      final discountAmount = baseAmount * _discountPercentage / 100;
      final totalAmount = baseAmount - discountAmount;

      final subscriptionId = await _subscriptionService.createSubscription(
        customerId: userId,
        shopId: _supabase.client.auth.currentUser?.id ?? '',
        items: _items,
        frequency: _frequency,
        baseAmount: baseAmount,
        discountPercentage: _discountPercentage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription created successfully!')),
        );

        // Navigate back or to confirmation screen
        Navigator.pop(context, subscriptionId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating subscription: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  double _calculateBaseAmount() {
    return _items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  String _getFrequencyDescription(String freq) {
    switch (freq) {
      case 'weekly':
        return 'Delivered every Monday at your preferred time slot';
      case 'biweekly':
        return 'Delivered every 2 weeks';
      case 'monthly':
        return 'Delivered on the 1st of every month';
      default:
        return '';
    }
  }

  String _getFrequencyLabel(String freq) {
    switch (freq) {
      case 'weekly':
        return 'week';
      case 'biweekly':
        return '2 weeks';
      case 'monthly':
        return 'month';
      default:
        return freq;
    }
  }
}
