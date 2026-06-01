import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/pricing_service.dart';

class DynamicPricingConsole extends StatefulWidget {
  const DynamicPricingConsole({super.key});

  @override
  State<DynamicPricingConsole> createState() => _DynamicPricingConsoleState();
}

class _DynamicPricingConsoleState extends State<DynamicPricingConsole> {
  final PricingService _pricingService = PricingService();
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final mandiFeeds = _pricingService.getMandiFeeds();
    final allProducts = productProvider.products;

    // Filter products that can be matched to Mandi feeds (Vegetables, Fruits, Dairy)
    final eligibleProducts = allProducts.where((p) {
      final cat = p.category.toLowerCase();
      return cat == 'vegetables' || cat == 'fruits' || cat == 'dairy';
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Real-Time Dynamic Pricing Engine',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjust retail prices based on real-time wholesale Mandi variations & custom markup parameters.',
                    style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Auto-Pilot Pricing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.grey700),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _pricingService.isAutoPilotEnabled,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _pricingService.isAutoPilotEnabled = val;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Auto-pilot pricing activated! Prices will adjust automatically based on wholesale shifts.'
                                : 'Auto-pilot pricing disabled.',
                          ),
                          backgroundColor: val ? AppTheme.success : AppTheme.grey800,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Top Grid: Settings Adjuster & Formula
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildMarkupSettingsPanel(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _buildFormulaSummaryPanel(),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Mandi Live Feed Ticker / Grid
          const Text(
            'Live Wholesale Mandi Market Index',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          _buildMandiFeedGrid(mandiFeeds),
          const SizedBox(height: 32),

          // Eligible Products List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retail Price Recommendations (${eligibleProducts.length} Items)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isUpdating || eligibleProducts.isEmpty
                    ? null
                    : () async {
                        setState(() => _isUpdating = true);
                        try {
                          final count = await _pricingService.autoUpdateEligibleProductPrices(allProducts);
                          await productProvider.refreshProducts(); // Refresh products list
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Dynamic pricing optimization complete! Updated $count retail prices.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error updating prices: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUpdating = false);
                        }
                      },
                icon: _isUpdating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on),
                label: const Text('Apply Dynamic Optimization to All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProductsPricingTable(eligibleProducts, productProvider),
        ],
      ),
    );
  }

  Widget _buildMarkupSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing Markup Parameters',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adjust sliders below to modify markup rates across catalog components.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey500),
          ),
          const SizedBox(height: 16),

          // Markup Slider
          Text(
            'Target Profit Margin: ${_pricingService.marginPercentage.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _pricingService.marginPercentage,
            min: 5.0,
            max: 50.0,
            divisions: 9,
            activeColor: AppTheme.primary,
            thumbColor: AppTheme.primary,
            inactiveColor: AppTheme.grey200,
            onChanged: (val) {
              setState(() {
                _pricingService.marginPercentage = val;
              });
            },
          ),

          // Transport surcharge slider
          Text(
            'Transportation Cost Surcharge: ${_pricingService.transportChargePercentage.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _pricingService.transportChargePercentage,
            min: 0.0,
            max: 20.0,
            divisions: 10,
            activeColor: AppTheme.secondary,
            thumbColor: AppTheme.secondary,
            inactiveColor: AppTheme.grey200,
            onChanged: (val) {
              setState(() {
                _pricingService.transportChargePercentage = val;
              });
            },
          ),

          // Wastage slider
          Text(
            'Wastage & Spoilage Buffer: ${_pricingService.wastageBufferPercentage.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _pricingService.wastageBufferPercentage,
            min: 0.0,
            max: 15.0,
            divisions: 15,
            activeColor: AppTheme.warning,
            thumbColor: AppTheme.warning,
            inactiveColor: AppTheme.grey200,
            onChanged: (val) {
              setState(() {
                _pricingService.wastageBufferPercentage = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaSummaryPanel() {
    final totalMarkup = _pricingService.marginPercentage +
        _pricingService.transportChargePercentage +
        _pricingService.wastageBufferPercentage;
    return Container(
      height: 275,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Pricing Formula Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Suggested Retail Price (SRP) is computed based on actual market rates plus the combined parameter markup.',
            style: TextStyle(fontSize: 11, color: AppTheme.grey600),
          ),
          const Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COMBINED ADD-ON RATE', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
              Text(
                '+${totalMarkup.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SRP = Mandi Rate × (1 + Markup%)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandiFeedGrid(List<MandiMarketFeed> feeds) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: feeds.length,
        itemBuilder: (context, index) {
          final feed = feeds[index];
          final isUp = feed.dailyChangePercentage >= 0;

          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 14, bottom: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: AppTheme.grey100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      feed.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.grey800),
                    ),
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      color: isUp ? AppTheme.success : AppTheme.error,
                      size: 16,
                    ),
                  ],
                ),
                Text(
                  '₹${feed.currentMandiPrice}/kg',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    Text(
                      '${isUp ? '+' : ''}${feed.dailyChangePercentage}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isUp ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('today', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsPricingTable(List<ProductModel> products, ProductProvider provider) {
    if (products.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No active products match Mandi index items.', style: TextStyle(color: AppTheme.grey500)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = products[index];
          final feed = _pricingService.matchProductToFeed(product);
          final mandiPrice = feed?.currentMandiPrice ?? (product.price * 0.75);
          final suggestedPrice = _pricingService.calculateSuggestedRetailPrice(mandiPrice);
          final priceDiff = (product.price - suggestedPrice).abs();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Product Name & Category
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey900),
                      ),
                      Text(
                        'Category: ${product.category.toUpperCase()} | Unit: ${product.unit}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                      ),
                    ],
                  ),
                ),
                // Mandi market rate
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mandi Rate', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                      Text(
                        '₹${mandiPrice.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.grey800),
                      ),
                    ],
                  ),
                ),
                // Current Retail Price
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Retail', style: TextStyle(fontSize: 11, color: AppTheme.grey500)),
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.grey800),
                      ),
                    ],
                  ),
                ),
                // Recommended Price (SRP)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recommended SRP', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
                      Text(
                        '₹${suggestedPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
                // Action: Apply recommendation
                ElevatedButton(
                  onPressed: priceDiff < 0.5
                      ? null
                      : () async {
                          final updatedProduct = ProductModel(
                            id: product.id,
                            name: product.name,
                            description: product.description,
                            price: suggestedPrice,
                            originalPrice: (suggestedPrice * 1.15).roundToDouble(),
                            discountPercentage: 15.0,
                            unit: product.unit,
                            category: product.category,
                            subCategory: product.subCategory,
                            shopId: product.shopId,
                            shopName: product.shopName,
                            imageUrl: product.imageUrl,
                            images: product.images,
                            rating: product.rating,
                            reviewCount: product.reviewCount,
                            stockQuantity: product.stockQuantity,
                            isAvailable: product.isAvailable,
                            isFeatured: product.isFeatured,
                            isOnSale: product.isOnSale,
                            isNewArrival: product.isNewArrival,
                            isTrending: product.isTrending,
                            specifications: product.specifications,
                            tags: product.tags,
                            barcode: product.barcode,
                            brand: product.brand,
                            origin: product.origin,
                            expiryDate: product.expiryDate,
                            weight: product.weight,
                            weightUnit: product.weightUnit,
                            minOrderQuantity: product.minOrderQuantity,
                            maxOrderQuantity: product.maxOrderQuantity,
                            district: product.district,
                            village: product.village,
                            createdAt: product.createdAt,
                            updatedAt: DateTime.now(),
                            unitOptions: product.unitOptions,
                          );

                          try {
                            final productService = ProductService();
                            await productService.addProduct(updatedProduct);
                            await provider.refreshProducts(); // Refresh list
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Updated ${product.name} retail price to ₹${suggestedPrice.toStringAsFixed(0)}!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: AppTheme.white,
                    disabledBackgroundColor: AppTheme.grey100,
                    disabledForegroundColor: AppTheme.grey400,
                  ),
                  child: Text(priceDiff < 0.5 ? 'Optimized' : 'Apply'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
