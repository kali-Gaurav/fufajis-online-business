# FjInputField - Quick Start Guide

**Version:** 1.0  
**Status:** ✅ Production-Ready  
**Location:** `/lib/widgets/input_field.dart`

---

## Installation

No additional dependencies required. Component uses Flutter Material + Fufaji design tokens.

```dart
import 'package:fufaji_online_business/widgets/input_field.dart';
```

---

## Basic Usage (2 minutes)

### Simple Text Input

```dart
FjInputField(
  label: 'Your Name',
  placeholder: 'Enter full name',
)
```

### Email with Validation

```dart
FjInputField(
  label: 'Email',
  placeholder: 'you@example.com',
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Email required';
    if (!value!.contains('@')) return 'Invalid email';
    return null;
  },
)
```

### Password Input

```dart
FjInputField(
  label: 'Password',
  placeholder: 'Enter password',
  variant: FjInputVariant.password,
  showPasswordToggle: true,
)
```

### Search Input

```dart
FjInputField(
  label: 'Search',
  placeholder: 'Type to search...',
  variant: FjInputVariant.search,
  onChanged: (query) {
    // Search logic here
  },
)
```

### Currency Input

```dart
FjInputField(
  label: 'Amount',
  placeholder: '0.00',
  variant: FjInputVariant.currency,
  currencySymbol: '₹',
  keyboardType: TextInputType.number,
)
```

### OTP Verification (6 digits)

```dart
FjOtpInput(
  length: 6,
  onComplete: (otp) {
    print('OTP: $otp');
    // Verify OTP
  },
)
```

---

## All Props Reference

### Essential Props

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `placeholder` | String | Yes | - | Placeholder text |
| `label` | String? | No | null | Label above input |
| `helperText` | String? | No | null | Gray helper text below |
| `errorText` | String? | No | null | Red error text |

### Interaction Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `onChanged` | Function(String)? | null | Called on text change |
| `validator` | Function(String?)? | null | Validation function |
| `controller` | TextEditingController? | null | Control text externally |
| `focusNode` | FocusNode? | null | Control focus externally |

### State Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `isDisabled` | bool | false | Disable interaction |
| `isLoading` | bool | false | Show spinner |
| `isRequired` | bool | false | Show red asterisk |

### Variant & Customization Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `variant` | FjInputVariant | text | text, otp, currency, search, password |
| `keyboardType` | TextInputType | text | Mobile keyboard type |
| `obscureText` | bool | false | Hide input text |
| `showPasswordToggle` | bool | true | Show/hide toggle (password variant) |
| `prefixIcon` | Widget? | null | Icon at start |
| `suffixIcon` | Widget? | null | Icon at end |
| `maxLines` | int | 1 | Max line count |
| `minLines` | int | 1 | Min line count |
| `maxLength` | int? | null | Character limit |
| `currencySymbol` | String | '₹' | Currency symbol |
| `autofocus` | bool | false | Focus on build |
| `semanticLabel` | String? | null | Screen reader label |

---

## Common Patterns

### Pattern 1: Form with Multiple Inputs

```dart
class LoginForm extends StatefulWidget {
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value?.isEmpty ?? true) return 'Email required';
    if (!value!.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value?.isEmpty ?? true) return 'Password required';
    if (value!.length < 8) return 'Min 8 characters';
    return null;
  }

  void _login() {
    final email = _emailController.text;
    final password = _passwordController.text;
    // Login logic
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FjInputField(
          label: 'Email',
          placeholder: 'you@example.com',
          controller: _emailController,
          validator: _validateEmail,
          keyboardType: TextInputType.emailAddress,
          isRequired: true,
        ),
        const SizedBox(height: 16),
        FjInputField(
          label: 'Password',
          placeholder: 'Enter password',
          variant: FjInputVariant.password,
          controller: _passwordController,
          validator: _validatePassword,
          isRequired: true,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _login,
          child: Text('Login'),
        ),
      ],
    );
  }
}
```

### Pattern 2: Dynamic Search

```dart
class ProductSearch extends StatefulWidget {
  @override
  State<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends State<ProductSearch> {
  List<String> _results = [];

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    // Call API or search local data
    final results = _searchProducts(query);
    setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FjInputField(
          label: 'Search',
          placeholder: 'Search products...',
          variant: FjInputVariant.search,
          onChanged: _search,
        ),
        if (_results.isNotEmpty)
          ListView(
            children: _results
                .map((r) => ListTile(title: Text(r)))
                .toList(),
          ),
      ],
    );
  }
}
```

### Pattern 3: OTP Verification

```dart
class OtpVerification extends StatefulWidget {
  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  bool _isVerifying = false;

  void _verifyOtp(String otp) async {
    setState(() => _isVerifying = true);

    try {
      final result = await _api.verifyOtp(otp);
      if (result.success) {
        // Navigate to next screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP')),
        );
      }
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Enter verification code',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        FjOtpInput(
          length: 6,
          onComplete: _isVerifying ? null : _verifyOtp,
        ),
        if (_isVerifying)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
```

---

## Styling & Theming

All styling uses Fufaji design tokens. To customize globally, modify:

```dart
// Colors
/lib/constants/app_colors.dart
- AppColors.primary (focus border)
- AppColors.grey200 (default border)
- AppColors.grey50 (background)

// Spacing
/lib/constants/app_spacing.dart
- AppSpacing.md (padding)
- AppSpacing.radiusSmall (border radius)

// Typography
/lib/constants/app_typography.dart
- AppTypography.labelLarge (label)
- AppTypography.bodyMedium (input text)
```

---

## Accessibility Features

### Keyboard Navigation

- **Tab** - Next input
- **Shift+Tab** - Previous input
- **Escape** - Unfocus
- **Arrow Keys** - OTP navigation

### Screen Reader Support

All inputs automatically announce:
- Label text
- Required status
- Placeholder/hint
- Current value
- Error messages

### Visual Indicators

- **Focus Ring** - 2px blue outline
- **Error Icon** - Red X in suffix
- **Required Marker** - Red * next to label

---

## Test Screen

View all states and variants:

```dart
// In your router/main.dart:
import 'package:fufaji_online_business/screens/test/fj_input_field_test_screen.dart';

// Navigate to:
FjInputFieldTestScreen()
```

---

## Troubleshooting

### Error: "Invalid email format" appears immediately

**Solution:** Validation runs on every keystroke. Add `_hasInteracted` flag logic (already built-in) to only show errors after user has interacted.

### OTP input not auto-tabbing

**Solution:** Make sure you're using `FjOtpInput` (not FjInputField with variant). OTP variant uses a separate optimized component.

### Focus ring not visible

**Solution:** Check that input has keyboard focus. Test with Tab key navigation. If using screen with multiple inputs, use `autofocus: true` on first input.

### Validation not triggering

**Solution:** Ensure `validator` function is provided. It's called on every `onChanged`. Return `null` for valid, error string for invalid.

### Password toggle not showing

**Solution:** Set `showPasswordToggle: true` (default). Only applicable when using `variant: FjInputVariant.password`.

### Clear button not appearing in search

**Solution:** Clear button only shows when input has text. Type something, then X button appears on right side.

---

## Performance Tips

1. **Reuse FocusNode** - If managing focus externally, reuse same FocusNode
2. **Reuse Controller** - Create controller once, reuse across rebuilds
3. **Lightweight Validators** - Keep validator functions simple/fast
4. **Avoid Rebuild** - Use `setState()` only when necessary

---

## Migration from Old Components

If migrating from old FormInput or similar:

```dart
// OLD (if exists)
FormInput(
  label: 'Email',
  placeholder: 'Enter email',
  controller: controller,
)

// NEW
FjInputField(
  label: 'Email',
  placeholder: 'Enter email',
  controller: controller,
  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
)
```

---

## More Examples

See comprehensive test screen for:
- All state variations
- All 5 variants
- Validation examples
- Multiline inputs
- Error handling
- Loading states
- Disabled states

**Path:** `/lib/screens/test/fj_input_field_test_screen.dart`

---

## Full Documentation

For detailed architecture, props, and implementation:

**Path:** `/lib/widgets/INPUT_FIELD_IMPLEMENTATION.md`

---

## Support

For issues or questions:
1. Check this quick start
2. Review test screen examples
3. Read full implementation guide
4. Refer to DESIGN_HANDOFF_SPEC.md (Section 2.2)

---

**Happy coding! 🎉**
