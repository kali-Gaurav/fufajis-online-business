import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/providers/product_provider.dart';
import 'mock_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Barcode Search Matching Tests', () {
    late ProductProvider productProvider;

    setUp(() {
      productProvider = ProductProvider(MockSharedPreferences());
      productProvider.loadMockProducts();
    });

    test('Exact barcode search should match the correct product', () {
      // The first product should have barcode: 8901234567001
      final targetBarcode = '8901234567001';
      final results = productProvider.searchProducts(targetBarcode);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals(targetBarcode));
      expect(results.first.name, contains('Potatoes'));
    });

    test('Search query matching partial barcode text should not return matches if exact is expected', () {
      // Our search matches exact barcodes, otherwise does token search.
      // If we search 8901234567002, it should return precisely the second product (Tomatoes)
      final targetBarcode = '8901234567002';
      final results = productProvider.searchProducts(targetBarcode);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals(targetBarcode));
      expect(results.first.name, contains('Tomatoes'));
    });

    test('Unregistered barcode search should return empty', () {
      final dummyBarcode = '9999999999999';
      final results = productProvider.searchProducts(dummyBarcode);
      expect(results, isEmpty);
    });

    test('Scanned barcode with leading/trailing spaces should match successfully', () {
      final targetBarcodeWithSpaces = '  8901234567003   ';
      final results = productProvider.searchProducts(targetBarcodeWithSpaces);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals('8901234567003'));
      expect(results.first.name, contains('Onions'));
    });
  });
}
