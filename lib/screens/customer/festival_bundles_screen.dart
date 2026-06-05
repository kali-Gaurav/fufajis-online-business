import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';

class FestivalBundlesScreen extends StatelessWidget {
  final String festivalName;
  const FestivalBundlesScreen({super.key, required this.festivalName});

  @override
  Widget build(BuildContext context) {
    // Generate simple mock products for the bundle based on the festival name
    final List<ProductModel> bundleProducts = _getMockBundleProducts(
      festivalName,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${festivalName.replaceAll('_', ' ').toUpperCase()} Bundle Deals',
        ),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppTheme.grey100,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bundleProducts.length,
          itemBuilder: (context, index) {
            final p = bundleProducts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  radius: 30,
                  backgroundImage: p.imageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(p.imageUrl)
                      : null,
                  child: p.imageUrl.isEmpty
                      ? const Icon(Icons.shopping_basket)
                      : null,
                ),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('₹${p.price.round()} / ${p.unit}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${p.name} added to cart!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add to Cart'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<ProductModel> _getMockBundleProducts(String fest) {
    if (fest.toLowerCase() == 'diwali') {
      return [
        ProductModel(
          id: 'diwali_sweets',
          name: 'Diwali Premium Kaju Katli Pack',
          description: 'Special Diwali Sweets Box',
          price: 350.0,
          originalPrice: 400.0,
          unit: '500g',
          category: 'groceries',
          shopId: 's1',
          shopName: 'Fufaji Store',
          imageUrl:
              'https://images.unsplash.com/photo-1589135304675-e22b30e462c1?w=200',
          stockQuantity: 40,
          district: 'Jaipur',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        ProductModel(
          id: 'diwali_diyas',
          name: 'Handcrafted Clay Diyas (Set of 6)',
          description: 'Decorative clay lamps for Diwali',
          price: 50.0,
          originalPrice: 80.0,
          unit: '1 set',
          category: 'household',
          shopId: 's1',
          shopName: 'Fufaji Store',
          imageUrl:
              'https://images.unsplash.com/photo-1605847429037-124044afde3f?w=200',
          stockQuantity: 100,
          district: 'Jaipur',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    }
    return [];
  }
}
