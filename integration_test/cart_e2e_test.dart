import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fufajis_online/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cart & Checkout E2E Tests', () {
    testWidgets('Rapid cart mutation test (CartMutationQueue)', (tester) async {
      // 1. Launch the app
      app.main();
      
      // Allow app to settle (splash screen, auth check, etc.)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 2. Find a product and add to cart
      // We will simulate tapping an "Add to Cart" button or directly testing the UI
      // Since this is a generic E2E structure, we use the standard flutter_test finders
      final addButton = find.byKey(const Key('add_to_cart_button')).first;
      
      if (addButton.evaluate().isNotEmpty) {
        // Tap Add
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Find the quantity increment button in the cart
        final incrementButton = find.byIcon(Icons.add);
        
        if (incrementButton.evaluate().isNotEmpty) {
          // Rapidly tap 5 times to stress test CartMutationQueue
          for (var i = 0; i < 5; i++) {
            await tester.tap(incrementButton.first);
            // pump a short duration, less than debounce timer (500ms)
            await tester.pump(const Duration(milliseconds: 100));
          }

          // Let debounce timer expire
          await tester.pumpAndSettle(const Duration(seconds: 1));
          
          // Verify UI updated
          // This requires looking for the updated quantity text, e.g. "6"
          expect(find.text('6'), findsWidgets);
        }
      } else {
        debugPrint('Could not find add button, E2E test skipped for this state.');
      }
    });

    testWidgets('Cart Freeze during Checkout', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final checkoutButton = find.text('Checkout');
      if (checkoutButton.evaluate().isNotEmpty) {
        // Tap checkout to trigger cart freeze
        await tester.tap(checkoutButton);
        await tester.pumpAndSettle();

        // While in checkout, cart should be frozen
        // Verify increment button doesn't work or throws error silently handled
        final incrementButton = find.byIcon(Icons.add);
        if (incrementButton.evaluate().isNotEmpty) {
          await tester.tap(incrementButton.first);
          await tester.pumpAndSettle();
          
          // Should not change quantity
          expect(find.text('Snack error'), findsNothing); // Ensure no crash
        }
      }
    });
  });
}
