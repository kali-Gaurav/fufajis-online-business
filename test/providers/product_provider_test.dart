import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fufajis_online/providers/product_provider.dart';
import 'package:fufajis_online/models/product_model.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {
  final Map<String, dynamic> _values = {};

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _values[key] = value;
    return true;
  }
}

void main() {
  group('ProductProvider Tests', () {
    late ProductProvider productProvider;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      productProvider = ProductProvider(
        mockPrefs,
        enableRemoteData: false,
      );
    });

    final mockProducts = [
      ProductModel(
        id: 'p1',
        name: 'Apple',
        description: 'desc',
        price: 100.0,
        originalPrice: 120.0,
        unit: '1 kg',
        category: 'fruits',
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: 'url',
        stockQuantity: 10,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'p2',
        name: 'Potato',
        description: 'desc',
        price: 50.0,
        originalPrice: 60.0,
        unit: '1 kg',
        category: 'vegetables',
        shopId: 's1',
        shopName: 'Shop',
        imageUrl: 'url',
        stockQuantity: 5,
        district: 'Jaipur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    test('Initial state', () {
      expect(productProvider.products, isEmpty);
      expect(productProvider.isLoading, isFalse);
    });

    test('Search products locally', () {
      productProvider.loadMockProducts();
      final results = productProvider.searchProducts('Potato');
      expect(results.length, 1);
      expect(results.first.name, 'Fresh Organic Potatoes');
    });

    test('Toggle wishlist', () {
      productProvider.toggleWishlist('p1');
      expect(productProvider.isInWishlist('p1'), isTrue);
      
      productProvider.toggleWishlist('p1');
      expect(productProvider.isInWishlist('p1'), isFalse);
    });

    test('Filter by category', () {
      productProvider.loadMockProducts();
      final dairyProducts = productProvider.getProductsByCategory('dairy');
      expect(dairyProducts.length, 1);
      expect(dairyProducts.first.name, contains('Milk'));
    });
  });
}
