import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fufajis_online/providers/product_provider.dart';
import 'package:fufajis_online/services/ai_search_service.dart';
import 'mock_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Snap-to-Shop AI Search Tests', () {
    late ProductProvider productProvider;
    late AISearchService aiSearchService;

    setUp(() {
      productProvider = ProductProvider(MockSharedPreferences());
      productProvider.loadMockProducts();
      aiSearchService = AISearchService();
    });

    test('Simulated label match should return correct products', () async {
      final results = await aiSearchService.identifyProductFromImage(
        XFile('dummy_path'),
        productProvider.products,
        simulatedLabel: 'Potato',
      );

      expect(results, isNotEmpty);
      expect(results.first.name, contains('Potatoes'));
    });

    test('Image file name heuristic should match keyword', () async {
      // Simulate file named "my_fresh_tomato_crop.png"
      final results = await aiSearchService.identifyProductFromImage(
        XFile('path/to/my_fresh_tomato_crop.png'),
        productProvider.products,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, contains('Tomatoes'));
    });

    test('Image file name onion heuristic should match onion product', () async {
      // Simulate file named "onions.jpg"
      final results = await aiSearchService.identifyProductFromImage(
        XFile('onions.jpg'),
        productProvider.products,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, contains('Onions'));
    });

    test('Unknown image file should fallback to general catalog matching gracefully', () async {
      final results = await aiSearchService.identifyProductFromImage(
        XFile('mysterious_object.png'),
        productProvider.products,
      );

      // Should return the default fallback matching (1 item from catalog based on image hash)
      expect(results.length, equals(1));
    });
  });
}
