# Fufaji Accessibility Guide

## Overview

This guide documents accessibility best practices and widgets for Fufaji Online Business. All interactive elements must be keyboard-navigable and screen-reader compatible.

---

## Quick Reference

| Component | File | Use When |
|-----------|------|----------|
| **FjFocusableButton** | `/lib/widgets/accessibility/focusable_button.dart` | Any interactive element needing keyboard + screen reader support |
| **FjAccessibleCard** | `/lib/widgets/accessibility/accessible_card.dart` | Card containers that should be keyboard-navigable |
| **AccessibilityHelper** | `/lib/utils/accessibility_helper.dart` | Utility methods for focus styling, announcements, contrast checking |

---

## Components

### FjFocusableButton

Wraps any widget with full keyboard navigation and screen reader support.

**Features:**
- Tab/Shift+Tab navigation
- Enter/Space key activation
- 2px solid orange (`#FF8C42`) focus ring
- Escape key to unfocus
- Semantic label for screen readers

**Basic Usage:**

```dart
FjFocusableButton(
  label: 'Add to Cart',
  onPressed: () {
    print('Button pressed!');
  },
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.add, size: 18),
      SizedBox(width: 8),
      Text('Add to Cart'),
    ],
  ),
)
```

**With External FocusNode:**

```dart
final FocusNode buttonFocusNode = FocusNode();

FjFocusableButton(
  focusNode: buttonFocusNode,
  onPressed: () => print('Pressed'),
  child: Text('Click Me'),
)
```

**Disable Focus Ring:**

```dart
FjFocusableButton(
  showFocusRing: false,
  onPressed: () {},
  child: Text('No Focus Ring'),
)
```

**Autofocus on Build:**

```dart
FjFocusableButton(
  autofocus: true,
  onPressed: () {},
  child: Text('Focused'),
)
```

**Keyboard Shortcuts:**

| Key | Action |
|-----|--------|
| Tab | Move focus to next element |
| Shift+Tab | Move focus to previous element |
| Enter | Activate button |
| Space | Activate button |
| Escape | Unfocus button |

---

### FjAccessibleCard

Keyboard and screen reader compatible card widget.

**Features:**
- Keyboard navigation (Tab to focus)
- Enter/Space key to activate
- 2px focus ring on focus
- Screen reader announcements
- Customizable background, padding, border radius

**Basic Usage:**

```dart
FjAccessibleCard(
  title: 'Order #1234',
  hint: 'Tap to view order details',
  onTap: () {
    Navigator.push(context, /* ... */);
  },
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Order Total: Rs. 500'),
      Text('Status: Delivered'),
    ],
  ),
)
```

**Customized Styling:**

```dart
FjAccessibleCard(
  title: 'Premium Item',
  padding: EdgeInsets.all(24),
  borderRadius: 16,
  backgroundColor: FufajiColors.primaryLight,
  elevation: 4,
  onTap: () => print('Card tapped'),
  child: Text('Content'),
)
```

**With External FocusNode:**

```dart
final FocusNode cardFocusNode = FocusNode();

FjAccessibleCard(
  focusNode: cardFocusNode,
  title: 'My Card',
  onTap: () {},
  child: SizedBox(height: 100),
)
```

**Keyboard Shortcuts:**

| Key | Action |
|-----|--------|
| Tab | Move focus to next card |
| Shift+Tab | Move focus to previous card |
| Enter | Activate card (call onTap) |
| Space | Activate card (call onTap) |
| Escape | Unfocus card |

---

## Utility: AccessibilityHelper

Centralized utilities for accessibility features.

### Focus Ring Styling

```dart
// Get decoration for a container with focus ring
Container(
  decoration: AccessibilityHelper.getFocusOutlineDecoration(
    hasFocus: _focusNode.hasFocus,
    cornerRadius: 8,
  ),
  child: MyWidget(),
)
```

### Screen Reader Announcements

```dart
// Announce simple message
await AccessibilityHelper.announceToScreenReader('Item added to cart');

// Announce navigation
await AccessibilityHelper.announceNavigation('Order Details Page');

// Announce error
await AccessibilityHelper.announceError('Failed to load orders');

// Announce success
await AccessibilityHelper.announceSuccess('Payment completed');

// Announce form field value
await AccessibilityHelper.announceFormField('Quantity', '5 items');
```

### Reduced Motion Detection

```dart
bool isMotionReduced = AccessibilityHelper.isReducedMotionEnabled(context);

if (isMotionReduced) {
  // Skip animations, jump to final state
} else {
  // Play full animation
}
```

### High Contrast Detection

```dart
bool shouldShow = AccessibilityHelper.shouldShowFocusRing(context);

if (shouldShow) {
  // Show focus ring
}
```

### Contrast Checking (WCAG AA)

```dart
bool isCompliant = AccessibilityHelper.isContrastCompliant(
  FufajiColors.primary,  // foreground
  FufajiColors.white,    // background
);

if (!isCompliant) {
  print('Color contrast is not WCAG AA compliant');
}
```

### Create Accessible Focus Node

```dart
final focusNode = AccessibilityHelper.createAccessibleFocusNode(
  debugLabel: 'cart_button',
);
```

---

## Focus Ring Styling Standards

### Standard Focus Ring

- **Width:** 2px (solid)
- **Color:** `#FF8C42` (Fufaji Primary Orange)
- **Border Radius:** 8px (to match component corners)
- **Animation:** 200ms ease-in-out

### Implementation

All focusable components should show a 2px solid orange border when focused:

```dart
BoxDecoration getFocusDecoration(bool hasFocus) {
  if (!hasFocus) return BoxDecoration();
  
  return BoxDecoration(
    border: Border.all(
      color: FufajiColors.primary,
      width: 2.0,
    ),
    borderRadius: BorderRadius.circular(8),
  );
}
```

---

## Semantic Labels & Hints

### For Buttons

```dart
FjFocusableButton(
  semanticLabel: 'Add to cart with current quantity',
  onPressed: () {},
  child: Text('Add'),
)
```

### For Cards

```dart
FjAccessibleCard(
  title: 'Order Details',
  hint: 'Press Enter to view full order',
  onTap: () {},
  child: OrderSummary(),
)
```

### Screen Reader Format

- **Label:** Primary purpose (what is this element?)
- **Hint:** Additional context (how do I use it?)

Example: 
- Label: "Search products"
- Hint: "Enter product name and press search"

---

## WCAG Compliance Checklist

### Level A (Minimum)

- [ ] All interactive elements are keyboard accessible (Tab navigation)
- [ ] All interactive elements have semantic labels
- [ ] Focus order is logical and visible
- [ ] Color is not the only way to convey information

### Level AA (Recommended)

- [ ] Focus indicator is visible (2px border minimum)
- [ ] Text color contrast is 4.5:1 or better
- [ ] Buttons and links are at least 44x44px (touch targets)
- [ ] Error messages are announced to screen readers
- [ ] Form fields have associated labels

### Level AAA (Enhanced)

- [ ] Text color contrast is 7:1 or better
- [ ] Animations respect `prefers-reduced-motion`
- [ ] Captions provided for audio content
- [ ] Transcripts provided for video content

---

## Best Practices

### 1. Always Provide Semantic Labels

```dart
// Bad: No context
Semantics(
  button: true,
  child: Icon(Icons.add),
)

// Good: Clear semantic label
FjFocusableButton(
  semanticLabel: 'Add product to cart',
  onPressed: () {},
  child: Icon(Icons.add),
)
```

### 2. Use Logical Tab Order

```dart
// Organize focus nodes in reading order
Column(
  children: [
    FjFocusableButton(
      autofocus: true,  // First in tab order
      onPressed: () {},
      child: Text('First'),
    ),
    FjFocusableButton(
      onPressed: () {},
      child: Text('Second'),
    ),
  ],
)
```

### 3. Announce Dynamic Content

```dart
Future<void> addToCart() async {
  await _cart.add(product);
  await AccessibilityHelper.announceSuccess('Added to cart');
}
```

### 4. Test with Screen Readers

**Android (TalkBack):**
- Settings > Accessibility > TalkBack
- Swipe right: next element
- Swipe left: previous element
- Double-tap: activate

**iOS (VoiceOver):**
- Settings > Accessibility > VoiceOver
- Swipe right: next element
- Swipe left: previous element
- Double-tap: activate

### 5. Keyboard Navigation Testing

- Tab through all interactive elements
- Verify focus ring is visible (2px orange border)
- Verify Enter/Space activates buttons
- Verify Escape unfocuses elements

---

## Common Patterns

### Accessible Button List

```dart
class AccessibleButtonList extends StatelessWidget {
  final List<ButtonConfig> buttons;
  final List<FocusNode> focusNodes;

  const AccessibleButtonList({
    required this.buttons,
    required this.focusNodes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(buttons.length, (index) {
        return FjFocusableButton(
          focusNode: focusNodes[index],
          semanticLabel: buttons[index].label,
          onPressed: buttons[index].onPressed,
          child: Text(buttons[index].label),
        );
      }),
    );
  }
}
```

### Accessible Form

```dart
class AccessibleForm extends StatefulWidget {
  @override
  State<AccessibleForm> createState() => _AccessibleFormState();
}

class _AccessibleFormState extends State<AccessibleForm> {
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _submitFocus = FocusNode();

  @override
  void dispose() {
    _nameFocus.dispose();
    _emailFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: 'Name field',
          child: TextField(
            focusNode: _nameFocus,
            decoration: InputDecoration(
              labelText: 'Name',
              border: AccessibilityHelper.getFocusBorder(
                isFocused: _nameFocus.hasFocus,
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Semantics(
          label: 'Email field',
          child: TextField(
            focusNode: _emailFocus,
            decoration: InputDecoration(
              labelText: 'Email',
              border: AccessibilityHelper.getFocusBorder(
                isFocused: _emailFocus.hasFocus,
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        FjFocusableButton(
          focusNode: _submitFocus,
          semanticLabel: 'Submit form',
          onPressed: () => print('Form submitted'),
          child: Text('Submit'),
        ),
      ],
    );
  }
}
```

### Accessible Card List

```dart
class AccessibleCardList extends StatelessWidget {
  final List<CardData> cards;
  final Function(String) onCardTap;

  const AccessibleCardList({
    required this.cards,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return FjAccessibleCard(
          title: card.title,
          hint: 'Double-tap to view details',
          onTap: () => onCardTap(card.id),
          child: card.content,
        );
      },
    );
  }
}
```

---

## Troubleshooting

### Focus Ring Not Showing

- [ ] Verify `showFocusRing: true` is set
- [ ] Check that `focusNode.hasFocus` is actually true
- [ ] Ensure widget is wrapped in Focus widget
- [ ] Check color contrast (might be invisible)

### Screen Reader Not Announcing

- [ ] Verify `semanticLabel` or `label` is provided
- [ ] Use `SemanticsService.announce()` for dynamic text
- [ ] Test with actual screen reader (TalkBack/VoiceOver)
- [ ] Check that Semantics widget is properly configured

### Tab Navigation Skipping Elements

- [ ] Check that all focusable elements have FocusNode
- [ ] Verify elements are not `skip: true` in Semantics
- [ ] Ensure elements are in logical reading order
- [ ] Test with keyboard only (no mouse)

---

## References

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Flutter Accessibility Docs](https://flutter.dev/docs/development/accessibility-and-localization/accessibility)
- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [Android TalkBack Guide](https://support.google.com/accessibility/android/answer/6283677)
- [iOS VoiceOver Guide](https://www.apple.com/accessibility/voiceover/)

---

## Contributing

When adding new interactive components:

1. Wrap with `FjFocusableButton` or `FjAccessibleCard`
2. Add semantic label
3. Test Tab navigation
4. Test with screen reader
5. Verify 2px focus ring appears
6. Update this guide with examples

