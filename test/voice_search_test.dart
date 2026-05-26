import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/providers/product_provider.dart';
import 'mock_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dual-Language Search Matching Tests', () {
    late ProductProvider productProvider;

    setUp(() {
      productProvider = ProductProvider(MockSharedPreferences());
      // Ensure the provider is hydrated with the premium mock product catalog
      productProvider.loadMockProducts();
    });

    test('English query searches for potato should return Fresh Potatoes', () {
      final results = productProvider.searchProducts('potato');
      expect(results, isNotEmpty);
      expect(
        results.any((product) => product.name.contains('Potatoes')),
        isTrue,
      );
    });

    test('Hindi query searches for आलू (Aloo) should return Fresh Potatoes', () {
      final results = productProvider.searchProducts('आलू');
      expect(results, isNotEmpty);
      expect(
        results.any((product) => product.name.contains('Potatoes')),
        isTrue,
      );
    });

    test('English query searches for milk should return Fresh Toned Milk', () {
      final results = productProvider.searchProducts('milk');
      expect(results, isNotEmpty);
      expect(
        results.any((product) => product.name.contains('Milk')),
        isTrue,
      );
    });

    test('Hindi query searches for दूध (Doodh) should return Fresh Toned Milk', () {
      final results = productProvider.searchProducts('दूध');
      expect(results, isNotEmpty);
      expect(
        results.any((product) => product.name.contains('Milk')),
        isTrue,
      );
    });

    test('Query with trailing punctuation should strip it and find the product', () {
      // Common voice transcription artifact: adding a period or Hindi full stop (।)
      final englishPunctuationResults = productProvider.searchProducts('milk.');
      final hindiPunctuationResults = productProvider.searchProducts('दूध।');

      expect(englishPunctuationResults, isNotEmpty);
      expect(englishPunctuationResults.any((p) => p.name.contains('Milk')), isTrue);

      expect(hindiPunctuationResults, isNotEmpty);
      expect(hindiPunctuationResults.any((p) => p.name.contains('Milk')), isTrue);
    });

    test('Tokenized search should match products regardless of word order', () {
      // "fresh potatoes" vs "potatoes fresh"
      final order1 = productProvider.searchProducts('fresh potatoes');
      final order2 = productProvider.searchProducts('potatoes fresh');

      expect(order1, isNotEmpty);
      expect(order2, isNotEmpty);
      expect(order1.length, equals(order2.length));
    });

    test('Multi-word Hindi query should match successfully', () {
      final results = productProvider.searchProducts('ताज़ा आलू');
      expect(results, isNotEmpty);
      expect(results.any((p) => p.name.contains('Potatoes')), isTrue);
    });

    test('Transliterated Hindi voice query should match multiple products', () {
      final results = productProvider.searchProducts('aloo aur tamatar');

      expect(results, isNotEmpty);
      expect(results.any((p) => p.name.contains('Potatoes')), isTrue);
      expect(results.any((p) => p.name.contains('Tomatoes')), isTrue);
    });

    test('Hindi script voice query with conjunction should match multiple products', () {
      final results = productProvider.searchProducts('आलू और टमाटर');

      expect(results, isNotEmpty);
      expect(results.any((p) => p.name.contains('Potatoes')), isTrue);
      expect(results.any((p) => p.name.contains('Tomatoes')), isTrue);
    });

    test('Empty search query should return an empty list', () {
      final results = productProvider.searchProducts('');
      expect(results, isEmpty);
    });

    test('Spam or unrelated query should return no results', () {
      final results = productProvider.searchProducts('xyzzy_non_existent');
      expect(results, isEmpty);
    });
  });
}
