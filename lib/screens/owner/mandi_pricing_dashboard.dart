import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/monetary_value.dart';

class MandiPricingDashboard extends StatefulWidget {
  const MandiPricingDashboard({super.key});

  @override
  State<MandiPricingDashboard> createState() => _MandiPricingDashboardState();
}

class _MandiPricingDashboardState extends State<MandiPricingDashboard> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _updatePrices(List<ProductModel> products) async {
    setState(() => _isSaving = true);
    final provider = Provider.of<ProductProvider>(context, listen: false);

    try {
      int count = 0;
      for (var p in products) {
        final newPriceStr = _controllers[p.id]?.text;
        if (newPriceStr != null && newPriceStr.isNotEmpty) {
          final newPrice = double.tryParse(newPriceStr);
          if (newPrice != null && newPrice != p.price) {
            final updated = p.copyWith(
              price: MonetaryValue(newPrice),
              originalPrice: (p.originalPrice != null && newPrice > p.originalPrice!.toDouble())
                  ? MonetaryValue(newPrice)
                  : p.originalPrice,
              updatedAt: DateTime.now(),
            );
            await provider.updateProduct(updated);
            count++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $count products successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final vegAndFruits = productProvider.products
        .where((p) => p.categoryId == 'vegetables' || p.categoryId == 'fruits')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Mandi Rates', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () => _updatePrices(vegAndFruits),
              child: const Text(
                'SAVE ALL',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.success.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.success),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set today\'s Mandi prices. The app will update customer prices instantly.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: vegAndFruits.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = vegAndFruits[index];
                _controllers.putIfAbsent(
                  p.id,
                  () => TextEditingController(text: p.price.toString()),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.grey100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            p.categoryId == 'vegetables' ? '🥦' : '🍎',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              'Unit: ${p.unit}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _controllers[p.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            prefixText: '₹ ',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
