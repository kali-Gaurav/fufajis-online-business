import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Fufaji Online',
      'home': 'Home',
      'cart': 'Cart',
      'profile': 'Profile',
      'orders': 'Orders',
      'wallet': 'Wallet',
      'language': 'Language',
      'selectLanguage': 'Select Language',
      'searchProducts': 'Search products...',
      'category': 'Category',
      'addToCart': 'Add to Cart',
      'checkout': 'Checkout',
      'total': 'Total',
      'payNow': 'Pay Now',
      'placeOrder': 'Place Order',
      'orderStatus': 'Order Status',
      'settings': 'Settings',
      'offlineMode': 'Offline Mode',
      'retry': 'Retry',
      'rewards': 'Rewards',
      'balance': 'Balance',
      'cashback': 'Cashback',
      'points': 'Points',
      'noInternet': 'No internet connection. You are browsing offline.',
    },
    'hi': {
      'appTitle': 'फूफाजी ऑनलाइन',
      'home': 'मुख्य पृष्ठ',
      'cart': 'कार्ट',
      'profile': 'प्रोफ़ाइल',
      'orders': 'ऑर्डर',
      'wallet': 'वॉलेट',
      'language': 'भाषा',
      'selectLanguage': 'भाषा चुनें',
      'searchProducts': 'उत्पाद खोजें...',
      'category': 'श्रेणी',
      'addToCart': 'कार्ट में जोड़ें',
      'checkout': 'चेकアウト',
      'total': 'कुल',
      'payNow': 'अभी भुगतान करें',
      'placeOrder': 'ऑर्डर दें',
      'orderStatus': 'ऑर्डर की स्थिति',
      'settings': 'सेटिंग्स',
      'offlineMode': 'ऑफ़लाइन मोड',
      'retry': 'पुनः प्रयास करें',
      'rewards': 'पुरस्कार',
      'balance': 'शेष राशि',
      'cashback': 'कैशबैक',
      'points': 'अंक',
      'noInternet':
          'कोई इंटरनेट कनेक्शन नहीं है। आप ऑफ़लाइन ब्राउज़ कर रहे हैं।',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters for convenience
  String get appTitle => translate('appTitle');
  String get home => translate('home');
  String get cart => translate('cart');
  String get profile => translate('profile');
  String get orders => translate('orders');
  String get wallet => translate('wallet');
  String get language => translate('language');
  String get selectLanguage => translate('selectLanguage');
  String get searchProducts => translate('searchProducts');
  String get category => translate('category');
  String get addToCart => translate('addToCart');
  String get checkout => translate('checkout');
  String get total => translate('total');
  String get payNow => translate('payNow');
  String get placeOrder => translate('placeOrder');
  String get orderStatus => translate('orderStatus');
  String get settings => translate('settings');
  String get offlineMode => translate('offlineMode');
  String get retry => translate('retry');
  String get rewards => translate('rewards');
  String get balance => translate('balance');
  String get cashback => translate('cashback');
  String get points => translate('points');
  String get noInternet => translate('noInternet');
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
