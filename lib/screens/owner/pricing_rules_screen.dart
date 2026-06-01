import 'package:flutter/material.dart';
import 'package:fufajis_online/providers/product_provider_extensions.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';

/// Pricing Rules Screen
/// Allows shop owners to configure dynamic pricing strategies
class PricingRulesScreen extends StatefulWidget {
  const PricingRulesScreen({super.key});

  @override
  State<PricingRulesScreen> createState() => _PricingRulesScreenState();
}

class _PricingRulesScreenState extends State<PricingRulesScreen> {
  String _selectedStrategy = 'Match';
  bool _isLoading = false;
  
  // Strategy parameters
  late TextEditingController _marginController;
  late TextEditingController _beatAmountController;
  late TextEditingController _premiumPercentageController;
  late TextEditingController _costPercentageController;

  Map<String, dynamic> _currentRules = {};
  int _pendingChangesCount = 0;

  @override
  void initState() {
    super.initState();
    _marginController = TextEditingController();
    _beatAmountController = TextEditingController();
    _premiumPercentageController = TextEditingController();
    _costPercentageController = TextEditingController();
    _loadPricingRules();
  }

  @override
  void dispose() {
    _marginController.dispose();
    _beatAmountController.dispose();
    _premiumPercentageController.dispose();
    _costPercentageController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingRules() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      final rules = await provider.getPricingRules();
      
      setState(() {
        _currentRules = rules;
        _selectedStrategy = rules['strategy'] ?? 'Match';
        _marginController.text = (rules['margin'] ?? 10).toString();
        _beatAmountController.text = (rules['beatAmount'] ?? 5).toString();
        _premiumPercentageController.text = (rules['premiumPercentage'] ?? 10).toString();
        _costPercentageController.text = (rules['costPercentage'] ?? 20).toString();
      });

      // Get pending changes count
      final pendingChanges = await provider.getPendingPriceChanges();
      setState(() => _pendingChangesCount = pendingChanges.length);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pricing rules: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStrategy() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      
      final newRules = {
        'strategy': _selectedStrategy,
        'margin': double.parse(_marginController.text),
        'beatAmount': double.parse(_beatAmountController.text),
        'premiumPercentage': double.parse(_premiumPercentageController.text),
        'costPercentage': double.parse(_costPercentageController.text),
      };

      await provider.updatePricingStrategy(newRules);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing strategy updated')),
      );

      await _loadPricingRules();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating strategy: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Rules'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Changes Alert
                  if (_pendingChangesCount > 0)
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pending Price Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  Text(
                                    '$_pendingChangesCount price changes awaiting approval',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Navigate to pending changes screen
                                Navigator.pushNamed(
                                  context,
                                  '/pending-price-changes',
                                );
                              },
                              child: const Text('View'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Strategy Selection
                  const Text(
                    'Pricing Strategy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Strategy Cards
                  ..._buildStrategyCards(),
                  const SizedBox(height: 24),

                  // Strategy Parameters
                  const Text(
                    'Strategy Parameters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Common Parameters
                  _buildParameterField(
                    'Profit Margin (%)',
                    _marginController,
                    'Minimum profit margin on all products',
                  ),
                  const SizedBox(height: 12),

                  // Strategy-specific Parameters
                  if (_selectedStrategy == 'Beat')
                    _buildParameterField(
                      'Beat Amount (₹)',
                      _beatAmountController,
                      'Amount to beat competitor price by',
                    )
                  else if (_selectedStrategy == 'Premium')
                    _buildParameterField(
                      'Premium Percentage (%)',
                      _premiumPercentageController,
                      'Premium over competitor price',
                    )
                  else if (_selectedStrategy == 'Cost+')
                    _buildParameterField(
                      'Cost Markup (%)',
                      _costPercentageController,
                      'Markup over cost price',
                    ),
                  const SizedBox(height: 24),

                  // Price Impact Preview
                  Card(
                    color: Colors.amber[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price Impact Preview',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPriceImpactRow(
                            'Example Product',
                            '₹100',
                            '₹${_calculatePreviewPrice(100).toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _buildPriceImpactRow(
                            'Average Product',
                            '₹500',
                            '₹${_calculatePreviewPrice(500).toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _buildPriceImpactRow(
                            'Premium Product',
                            '₹1000',
                            '₹${_calculatePreviewPrice(1000).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateStrategy,
                      child: const Text('Save Pricing Rules'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Strategy Information
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Strategy Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStrategyInfo(
                            'Beat',
                            'Price lower than competitors to win market share',
                          ),
                          const SizedBox(height: 8),
                          _buildStrategyInfo(
                            'Match',
                            'Price same as competitors to maintain parity',
                          ),
                          const SizedBox(height: 8),
                          _buildStrategyInfo(
                            'Premium',
                            'Price higher than competitors for premium positioning',
                          ),
                          const SizedBox(height: 8),
                          _buildStrategyInfo(
                            'Cost+',
                            'Price based on cost plus fixed markup percentage',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildStrategyCards() {
    final strategies = ['Beat', 'Match', 'Premium', 'Cost+'];
    return strategies.map((strategy) {
      final isSelected = _selectedStrategy == strategy;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => setState(() => _selectedStrategy = strategy),
          child: Card(
            color: isSelected ? Colors.blue[50] : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStrategyDescription(strategy),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _getStrategyDescription(String strategy) {
    switch (strategy) {
      case 'Beat':
        return 'Price lower than competitors';
      case 'Match':
        return 'Price same as competitors';
      case 'Premium':
        return 'Price higher than competitors';
      case 'Cost+':
        return 'Price based on cost plus markup';
      default:
        return '';
    }
  }

  Widget _buildParameterField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixText: label.contains('%') ? '%' : '₹',
          ),
        ),
      ],
    );
  }

  Widget _buildPriceImpactRow(String label, String original, String newPrice) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Text(
              original,
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              newPrice,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStrategyInfo(String strategy, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '•',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strategy,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculatePreviewPrice(double basePrice) {
    final margin = double.tryParse(_marginController.text) ?? 10;
    
    switch (_selectedStrategy) {
      case 'Beat':
        final beatAmount = double.tryParse(_beatAmountController.text) ?? 5;
        return basePrice - beatAmount;
      case 'Premium':
        final premium = double.tryParse(_premiumPercentageController.text) ?? 10;
        return basePrice * (1 + premium / 100);
      case 'Cost+':
        final markup = double.tryParse(_costPercentageController.text) ?? 20;
        return basePrice * (1 + markup / 100);
      default: // Match
        return basePrice;
    }
  }
}
