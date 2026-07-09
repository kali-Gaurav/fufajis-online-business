import 'package:flutter/material.dart';
import '../../widgets/accessibility/focusable_button.dart';
import '../../widgets/accessibility/accessible_card.dart';
import '../../utils/accessibility_helper.dart';
import '../../utils/fufaji_colors.dart';

/// Test Screen for Accessibility Infrastructure
///
/// Demonstrates:
/// - FjFocusableButton with Tab/Enter/Space/Escape support
/// - FjAccessibleCard with keyboard navigation
/// - Focus ring styling (2px solid orange border)
/// - Screen reader announcements
///
/// Instructions:
/// 1. Run: `flutter run`
/// 2. Navigate to this screen
/// 3. Press Tab key to move between elements (desktop/emulator)
/// 4. Verify 2px orange focus ring appears
/// 5. Press Enter to activate buttons
/// 6. Enable screen reader (TalkBack/VoiceOver) to test announcements

class AccessibilityTestScreen extends StatefulWidget {
  const AccessibilityTestScreen({super.key});

  @override
  State<AccessibilityTestScreen> createState() => _AccessibilityTestScreenState();
}

class _AccessibilityTestScreenState extends State<AccessibilityTestScreen> {
  final List<FocusNode> _buttonFocusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  final List<FocusNode> _cardFocusNodes = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];

  String _statusMessage = 'Tab to navigate, Enter to activate';

  @override
  void dispose() {
    for (var node in _buttonFocusNodes) {
      node.dispose();
    }
    for (var node in _cardFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _handleButtonPress(int index) async {
    setState(() {
      _statusMessage = 'Button $index pressed!';
    });
    await AccessibilityHelper.announceSuccess('Button $index activated');
  }

  Future<void> _handleCardTap(int index) async {
    setState(() {
      _statusMessage = 'Card $index tapped!';
    });
    await AccessibilityHelper.announceSuccess('Opened card $index');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Test Screen'),
        backgroundColor: FufajiColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FufajiColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FufajiColors.primary, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keyboard Navigation Guide',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Tab: Move to next element\n'
                    '• Shift+Tab: Move to previous element\n'
                    '• Enter/Space: Activate button or card\n'
                    '• Escape: Unfocus element\n'
                    '• Look for 2px orange focus ring',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status Message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FufajiColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FufajiColors.success, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: FufajiColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: FufajiColors.grey700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: FjFocusableButton Tests
            Text(
              'FjFocusableButton Tests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FufajiColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Each button shows a 2px orange focus ring when focused via Tab key.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Button 1: Icon + Text
            FjFocusableButton(
              focusNode: _buttonFocusNodes[0],
              semanticLabel: 'Add to cart button',
              onPressed: () => _handleButtonPress(1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: FufajiColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Add to Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button 2: Text only
            FjFocusableButton(
              focusNode: _buttonFocusNodes[1],
              semanticLabel: 'Like button',
              onPressed: () => _handleButtonPress(2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: FufajiColors.info,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Like',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Button 3: Icon only
            FjFocusableButton(
              focusNode: _buttonFocusNodes[2],
              semanticLabel: 'Share button',
              onPressed: () => _handleButtonPress(3),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FufajiColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 24),

            // Section: FjAccessibleCard Tests
            Text(
              'FjAccessibleCard Tests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FufajiColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cards are focusable via Tab key and activate via Enter/Space.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Card 1: Order Card
            FjAccessibleCard(
              focusNode: _cardFocusNodes[0],
              title: 'Order #1001',
              hint: 'Press Enter to view details',
              onTap: () => _handleCardTap(1),
              backgroundColor: FufajiColors.cream,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order #1001',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FufajiColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Delivered',
                          style: TextStyle(
                            color: FufajiColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Total: Rs. 450',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                  const Text(
                    'Items: 3 products',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Product Card
            FjAccessibleCard(
              focusNode: _cardFocusNodes[1],
              title: 'Fresh Tomatoes',
              hint: 'Press Enter to add to cart',
              onTap: () => _handleCardTap(2),
              backgroundColor: FufajiColors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fresh Tomatoes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FufajiColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'In Stock',
                          style: TextStyle(
                            color: FufajiColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rs. 30/kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: FufajiColors.primary,
                    ),
                  ),
                  const Text(
                    'Fresh from farm',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 3: Promo Card
            FjAccessibleCard(
              focusNode: _cardFocusNodes[2],
              title: 'Special Offer',
              hint: 'Press Enter to claim',
              onTap: () => _handleCardTap(3),
              backgroundColor: FufajiColors.primaryLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get 20% Off',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'On your next order',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FufajiColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Code: SAVE20',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Focus Ring Reference
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FufajiColors.sand,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FufajiColors.grey300, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Focus Ring Reference',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Width: 2px solid',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                  const Text(
                    'Color: #FF8C42 (Fufaji Primary Orange)',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                  const Text(
                    'Border Radius: 8px',
                    style: TextStyle(fontSize: 12, color: FufajiColors.grey700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: FufajiColors.primary,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'This is a 2px Orange Focus Ring ↑',
                        style: TextStyle(fontSize: 11, color: FufajiColors.grey700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
