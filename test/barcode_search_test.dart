import 'package:flutter_test/flutter_test.dart';
import 'package:fufajis_online/providers/product_provider.dart';
import 'mock_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Barcode Search Matching Tests', () {
    late ProductProvider productProvider;

    setUp(() {
      productProvider = ProductProvider(
        MockSharedPreferences(),
        enableRemoteData: false,
      );
      productProvider.loadMockProducts();
    });

    test('Exact barcode search should match the correct product', () {
      // The first product should have barcode: 8901234567001
      const targetBarcode = '8901234567001';
      final results = productProvider.searchProducts(targetBarcode);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals(targetBarcode));
      expect(results.first.name, contains('Potatoes'));
    });

    test('Search query matching partial barcode text should not return matches if exact is expected', () {
      // Our search matches exact barcodes, otherwise does token search.
      // If we search 8901234567002, it should return precisely the second product (Tomatoes)
      const targetBarcode = '8901234567002';
      final results = productProvider.searchProducts(targetBarcode);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals(targetBarcode));
      expect(results.first.name, contains('Tomatoes'));
    });

    test('Unregistered barcode search should return empty', () {
      const dummyBarcode = '9999999999999';
      final results = productProvider.searchProducts(dummyBarcode);
      expect(results, isEmpty);
    });

    test('Scanned barcode with leading/trailing spaces should match successfully', () {
      const targetBarcodeWithSpaces = '  8901234567003   ';
      final results = productProvider.searchProducts(targetBarcodeWithSpaces);

      expect(results, isNotEmpty);
      expect(results.first.barcode, equals('8901234567003'));
      expect(results.first.name, contains('Onions'));
    });
  });
}
