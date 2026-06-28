import '../utils/monetary_value.dart';

class GlobalCatalogProduct {
  final String name;
  final String category;
  final String brand;
  final MonetaryValue mrp;
  final String unit;
  final String imageUrl;
  final List<String> tags;

  GlobalCatalogProduct({
    required this.name,
    required this.category,
    required this.brand,
    required this.mrp,
    required this.unit,
    required this.imageUrl,
    required this.tags,
  });
}

class GlobalCatalogService {
  static final List<GlobalCatalogProduct> universalProducts = [
    // Groceries
    GlobalCatalogProduct(
      name: 'Maggi 2-Minute Noodles',
      category: 'groceries',
      brand: 'Nestle',
      mrp: MonetaryValue(14.0),
      unit: '70g',
      imageUrl: 'https://images.unsplash.com/photo-1612966608967-312ba599102e?w=400',
      tags: ['maggi', 'noodles', 'instant', 'snack'],
    ),
    GlobalCatalogProduct(
      name: 'Fortune Soyabean Oil',
      category: 'groceries',
      brand: 'Fortune',
      mrp: MonetaryValue(180.0),
      unit: '1L',
      imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400',
      tags: ['oil', 'cooking', 'soyabean'],
    ),
    GlobalCatalogProduct(
      name: 'Tata Salt',
      category: 'groceries',
      brand: 'Tata',
      mrp: MonetaryValue(28.0),
      unit: '1kg',
      imageUrl: 'https://images.unsplash.com/photo-1589984662646-e7b2e4962f18?w=400',
      tags: ['salt', 'tata', 'namak'],
    ),
    GlobalCatalogProduct(
      name: 'Aashirvaad Shudha Chakki Atta',
      category: 'groceries',
      brand: 'ITC',
      mrp: MonetaryValue(245.0),
      unit: '5kg',
      imageUrl: 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400',
      tags: ['atta', 'flour', 'wheat', 'aata'],
    ),
    GlobalCatalogProduct(
      name: 'Parle-G Gold Biscuits',
      category: 'snacks',
      brand: 'Parle',
      mrp: MonetaryValue(10.0),
      unit: '110g',
      imageUrl: 'https://images.unsplash.com/photo-1558961309-dbdf71799f5a?w=400',
      tags: ['parle', 'biscuits', 'gluco'],
    ),
    GlobalCatalogProduct(
      name: 'Coca-Cola',
      category: 'beverages',
      brand: 'Coca-Cola',
      mrp: MonetaryValue(40.0),
      unit: '600ml',
      imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400',
      tags: ['coke', 'soft drink', 'cold drink'],
    ),
    GlobalCatalogProduct(
      name: 'Amul Butter',
      category: 'dairy',
      brand: 'Amul',
      mrp: MonetaryValue(56.0),
      unit: '100g',
      imageUrl: 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=400',
      tags: ['butter', 'amul', 'makkhan'],
    ),
    GlobalCatalogProduct(
      name: 'Surf Excel Easy Wash',
      category: 'household',
      brand: 'HUL',
      mrp: MonetaryValue(140.0),
      unit: '1kg',
      imageUrl: 'https://images.unsplash.com/photo-1585670149967-b4f4da88cc9f?w=400',
      tags: ['surf', 'detergent', 'wash'],
    ),
    GlobalCatalogProduct(
      name: 'Colgate Strong Teeth',
      category: 'household',
      brand: 'Colgate',
      mrp: MonetaryValue(110.0),
      unit: '200g',
      imageUrl: 'https://images.unsplash.com/photo-1585670149967-b4f4da88cc9f?w=400',
      tags: ['toothpaste', 'colgate', 'teeth'],
    ),
    GlobalCatalogProduct(
      name: 'Dove Cream Beauty Bar',
      category: 'household',
      brand: 'Dove',
      mrp: MonetaryValue(65.0),
      unit: '100g',
      imageUrl: 'https://images.unsplash.com/photo-1585670149967-b4f4da88cc9f?w=400',
      tags: ['soap', 'dove', 'bath'],
    ),
  ];

  static List<GlobalCatalogProduct> search(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return universalProducts.where((p) {
      return p.name.toLowerCase().contains(q) || 
             p.brand.toLowerCase().contains(q) ||
             p.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}
