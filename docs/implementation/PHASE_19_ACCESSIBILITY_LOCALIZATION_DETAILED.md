# Phase 19: Accessibility & Localization - Implementation Checklist

## Overview
Implement accessibility features and Hindi localization.

## Current Status
- ⏳ Hindi translations: Needs implementation
- ⏳ Screen reader support: Needs implementation
- ⏳ WCAG compliance: Needs verification
- ⏳ Touch target sizing: Needs verification
- ⏳ RTL layout: Needs implementation

## Task 19.1: Implement Hindi Translations
**Status:** Not Started
**Files:** 
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_hi.arb`

### Implementation Steps:
1. [ ] Create L10n class with all strings
2. [ ] Create English ARB file
3. [ ] Create Hindi ARB file
4. [ ] Implement language selection
5. [ ] Add language persistence
6. [ ] Test all screens in Hindi

### Code Template - L10n Class:
```dart
// lib/l10n/app_localizations.dart
class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
  ];

  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // English strings
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Fufaji Online',
      'home': 'Home',
      'cart': 'Cart',
      'orders': 'Orders',
      'profile': 'Profile',
      'wallet': 'Wallet',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'logout': 'Logout',
      'add_to_cart': 'Add to Cart',
      'buy_now': 'Buy Now',
      'price': 'Price',
      'quantity': 'Quantity',
      'total': 'Total',
      'checkout': 'Checkout',
      'payment': 'Payment',
      'delivery': 'Delivery',
      'order_placed': 'Order Placed',
      'order_confirmed': 'Order Confirmed',
      'order_shipped': 'Order Shipped',
      'order_delivered': 'Order Delivered',
      'wallet_balance': 'Wallet Balance',
      'reward_points': 'Reward Points',
      'membership_tier': 'Membership Tier',
      'cashback': 'Cashback',
      'refund': 'Refund',
      'transaction_history': 'Transaction History',
      'no_transactions': 'No transactions yet',
      'search': 'Search',
      'filter': 'Filter',
      'sort': 'Sort',
      'apply': 'Apply',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'view': 'View',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'info': 'Information',
    },
    'hi': {
      'app_title': 'फुफाजी ऑनलाइन',
      'home': 'होम',
      'cart': 'कार्ट',
      'orders': 'ऑर्डर',
      'profile': 'प्रोफाइल',
      'wallet': 'वॉलेट',
      'notifications': 'सूचनाएं',
      'settings': 'सेटिंग्स',
      'logout': 'लॉगआउट',
      'add_to_cart': 'कार्ट में जोड़ें',
      'buy_now': 'अभी खरीदें',
      'price': 'कीमत',
      'quantity': 'मात्रा',
      'total': 'कुल',
      'checkout': 'चेकआउट',
      'payment': 'भुगतान',
      'delivery': 'डिलीवरी',
      'order_placed': 'ऑर्डर रखा गया',
      'order_confirmed': 'ऑर्डर की पुष्टि की गई',
      'order_shipped': 'ऑर्डर भेज दिया गया',
      'order_delivered': 'ऑर्डर डिलीवर किया गया',
      'wallet_balance': 'वॉलेट बैलेंस',
      'reward_points': 'पुरस्कार अंक',
      'membership_tier': 'सदस्यता स्तर',
      'cashback': 'कैशबैक',
      'refund': 'वापसी',
      'transaction_history': 'लेनदेन इतिहास',
      'no_transactions': 'अभी तक कोई लेनदेन नहीं',
      'search': 'खोज',
      'filter': 'फ़िल्टर',
      'sort': 'सॉर्ट',
      'apply': 'लागू करें',
      'cancel': 'रद्द करें',
      'save': 'सहेजें',
      'delete': 'हटाएं',
      'edit': 'संपादित करें',
      'view': 'देखें',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'success': 'सफल',
      'warning': 'चेतावनी',
      'info': 'जानकारी',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['app_title']!;
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get cart => _localizedValues[locale.languageCode]!['cart']!;
  // ... add all other strings
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
```

### ARB Files:

**lib/l10n/app_en.arb:**
```json
{
  "app_title": "Fufaji Online",
  "home": "Home",
  "cart": "Cart",
  "orders": "Orders",
  "profile": "Profile",
  "wallet": "Wallet",
  "notifications": "Notifications",
  "settings": "Settings",
  "logout": "Logout"
}
```

**lib/l10n/app_hi.arb:**
```json
{
  "app_title": "फुफाजी ऑनलाइन",
  "home": "होम",
  "cart": "कार्ट",
  "orders": "ऑर्डर",
  "profile": "प्रोफाइल",
  "wallet": "वॉलेट",
  "notifications": "सूचनाएं",
  "settings": "सेटिंग्स",
  "logout": "लॉगआउट"
}
```

### Update pubspec.yaml:
```yaml
flutter:
  generate: true

flutter_gen:
  output: lib/gen

# Add to dependencies
intl: ^0.19.0
```

### Update main.dart:
```dart
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    // Save to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('language', locale.languageCode);
    });
  }

  @override
  void initState() {
    super.initState();
    // Load saved language
    SharedPreferences.getInstance().then((prefs) {
      final language = prefs.getString('language') ?? 'en';
      setState(() {
        _locale = Locale(language);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fufaji Online',
      locale: _locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(onLocaleChange: _setLocale),
    );
  }
}
```

## Task 19.2: Implement Screen Reader Support
**Status:** Not Started

### Implementation Steps:
1. [ ] Add semantic labels to all widgets
2. [ ] Implement proper widget hierarchy
3. [ ] Add content descriptions to images
4. [ ] Test with TalkBack (Android)
5. [ ] Test with VoiceOver (iOS)
6. [ ] Fix any accessibility issues

### Code Template:
```dart
// Add Semantics to widgets
Semantics(
  label: 'Add to cart button',
  button: true,
  enabled: true,
  onTap: () => addToCart(),
  child: ElevatedButton(
    onPressed: () => addToCart(),
    child: const Text('Add to Cart'),
  ),
)

// Add to images
Semantics(
  image: true,
  label: 'Product image for ${product.name}',
  child: Image.network(product.imageUrl),
)

// Add to lists
Semantics(
  customSemanticsActions: {
    CustomSemanticsAction(label: 'Delete'): () => deleteItem(),
  },
  child: ListTile(
    title: Text(item.name),
    onLongPress: () => deleteItem(),
  ),
)
```

## Task 19.3: Ensure WCAG Contrast Compliance
**Status:** Not Started

### Implementation Steps:
1. [ ] Audit all text colors for 4.5:1 contrast ratio
2. [ ] Update colors that don't meet standard
3. [ ] Test with contrast checker tools
4. [ ] Document color palette changes

### WCAG Contrast Ratios:
- Normal text: 4.5:1 minimum
- Large text (18pt+): 3:1 minimum
- UI components: 3:1 minimum

### Code Template:
```dart
// Use high contrast colors
class AppColors {
  // Text colors
  static const Color textPrimary = Color(0xFF212121); // Dark gray
  static const Color textSecondary = Color(0xFF757575); // Medium gray
  static const Color textTertiary = Color(0xFFBDBDBD); // Light gray
  
  // Background colors
  static const Color bgPrimary = Color(0xFFFFFFFF); // White
  static const Color bgSecondary = Color(0xFFF5F5F5); // Light gray
  
  // Accent colors
  static const Color accentPrimary = Color(0xFF1976D2); // Blue
  static const Color accentSecondary = Color(0xFFF57C00); // Orange
  
  // Status colors
  static const Color success = Color(0xFF388E3C); // Green
  static const Color error = Color(0xFFD32F2F); // Red
  static const Color warning = Color(0xFFF57F17); // Yellow
  static const Color info = Color(0xFF0288D1); // Light blue
}
```

## Task 19.4: Ensure Touch Target Sizing
**Status:** Not Started

### Implementation Steps:
1. [ ] Audit all touch targets
2. [ ] Update undersized elements
3. [ ] Test on various devices
4. [ ] Verify accessibility

### Code Template:
```dart
// Ensure minimum 44x44 dp touch targets
SizedBox(
  width: 44,
  height: 44,
  child: IconButton(
    onPressed: () {},
    icon: Icon(Icons.add),
  ),
)

// Add padding around interactive elements
Padding(
  padding: const EdgeInsets.all(12),
  child: GestureDetector(
    onTap: () {},
    child: Text('Tap me'),
  ),
)
```

## Task 19.5: Implement RTL Layout Support
**Status:** Not Started

### Implementation Steps:
1. [ ] Implement RTL support
2. [ ] Test all screens in RTL
3. [ ] Fix layout issues
4. [ ] Test images and icons

### Code Template:
```dart
// Use Directionality for RTL
Directionality(
  textDirection: TextDirection.rtl,
  child: MyWidget(),
)

// Use Row/Column with proper alignment
Row(
  textDirection: TextDirection.rtl,
  children: [
    Icon(Icons.arrow_forward),
    SizedBox(width: 8),
    Text('Next'),
  ],
)

// Use Align for RTL-aware positioning
Align(
  alignment: AlignmentDirectional.centerEnd,
  child: Icon(Icons.arrow_forward),
)
```

## Testing Checklist

### Localization Tests
- [ ] All strings translated to Hindi
- [ ] Language selection works
- [ ] Language persists across sessions
- [ ] All screens work in both languages
- [ ] RTL layout works correctly

### Accessibility Tests
- [ ] Screen reader works on all screens
- [ ] All text meets WCAG contrast standards
- [ ] All buttons are 44x44 dp minimum
- [ ] Semantic labels are correct
- [ ] Images have descriptions

### Manual Testing
- [ ] Test on Android device with TalkBack
- [ ] Test on iOS device with VoiceOver
- [ ] Test with contrast checker tools
- [ ] Test touch targets on various devices
- [ ] Test RTL layout on various devices

## Success Criteria

- [ ] All UI strings available in Hindi
- [ ] Screen reader works on all screens
- [ ] All text meets WCAG contrast standards
- [ ] All buttons are 44x44 dp minimum
- [ ] RTL layout works correctly
- [ ] Language selection works
- [ ] Language persists across sessions
- [ ] All screens work in both languages
- [ ] All tests pass
- [ ] No critical bugs

## Estimated Time: 30-40 hours

### Breakdown:
- Hindi translations: 8-10 hours
- Screen reader support: 8-10 hours
- WCAG compliance: 6-8 hours
- Touch target sizing: 4-6 hours
- RTL layout: 6-8 hours
- Testing: 6-8 hours

## Next Phase
After completing Phase 19, move to Phase 20: Analytics & Crash Reporting

