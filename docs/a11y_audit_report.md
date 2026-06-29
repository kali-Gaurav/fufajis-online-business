# Accessibility (a11y) Audit Report - Fufaji Online Business

This document outlines the accessibility audit findings, semantics mappings, focus navigation strategies, and screen-reader accessibility rules for the Fufaji Store mobile & web platforms.

## 1. Core Semantics Mappings

To support assistive technologies (such as Android TalkBack and iOS VoiceOver), standard interactive widgets must map to meaningful semantic representations.

| Component / Widget | Flutter Semantic Mapping | Purpose / Announcement Pattern |
|:---|:---|:---|
| Custom Buttons (`FjButton`) | `Semantics(button: true, label: '...', enabled: true)` | Announces element as a clickable button with its current state. |
| Cart Icon Badge | `Semantics(label: 'Cart, $itemCount items', container: true)` | Groups badge and cart icon to avoid split screen-reader focus. |
| Product Search Input | `Semantics(textField: true, label: 'Search products', hint: 'Type name or barcode')` | Allows screen readers to announce text entry mode. |
| Order Status Stepper | `Semantics(label: 'Order status: $currentStep of $totalSteps - $stepTitle')` | Simplifies complex linear UI into a single status report. |
| Dynamic Pricing Console | `Semantics(liveRegion: true, label: 'Price updated to ₹$price')` | Immediately notifies screen reader users of real-time price updates. |

## 2. Color Contrast & Visual Accessibility

- **Standard Text**: Maintain a contrast ratio of at least `4.5:1` against the background.
- **Large Text**: (18pt / bold 14pt and above) Maintain a contrast ratio of at least `3.0:1`.
- **Contrast Tokens**:
  - `AppTheme.primary` (Deep Indigo) on `AppTheme.white` matches `6.8:1`.
  - `AppTheme.error` (Crimson Red) on `AppTheme.white` matches `4.6:1`.
  - Avoid using low-contrast grey text (`AppTheme.grey400` or lighter) for critical labels.

## 3. Focus State Navigation

1. **Logical Traversal**: Use explicit `FocusNode` ordering for forms (like POS checkout or supplier onboarding) to ensure sequential focus traversal.
2. **Keyboard Navigation Support**:
   - Wrap interactive lists (like search results) in `FocusableActionDetector` or `ListTile` with standard keyboard callbacks (`Enter` or `Space` key to select).
   - Use `Shortcuts` and `Actions` to map keyboard shortcuts for common terminal operations:
     - `Ctrl + F` to search.
     - `Escape` to clear search or close dialogs.
     - `F1` for Voice command trigger.

## 4. Guidelines for Future Component Development

- **Always Provide `label` and `hint`**: Never leave pure icon buttons (like `IconButton`) without a `tooltip` or `semanticsLabel`.
- **Use `MergeSemantics` Strategically**: Group child components (e.g., product image, name, and price) into a single semantic element to decrease the cognitive load of navigating lists.
- **State Changes**: When a screen changes dynamically (e.g. adding items to cart), use `SemanticsService.announce` or a `SnackBar` to announce the result so users who cannot see the screen are kept informed.
