import 'package:flutter/material.dart';

class L10n {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': "Fufaji's Online",
      'home': 'Home',
      'search': 'Search',
      'cart': 'Cart',
      'profile': 'Profile',
      'categories': 'Categories',
      'featured_products': 'Featured Products',
      'trending_now': 'Trending Now',
      'add_to_cart': 'Add to Cart',
      'out_of_stock': 'Out of Stock',
      'checkout': 'Checkout',
      'total': 'Total',
      'place_order': 'Place Order',
      'my_orders': 'My Orders',
      'wallet': 'Wallet',
      'settings': 'Settings',
      'logout': 'Logout',
      'notifications': 'Notifications',
      'delivery_to': 'Deliver to',
      'change': 'Change',
    },
    'hi': {
      'app_name': "फूफाजी ऑनलाइन",
      'home': 'होम',
      'search': 'खोजें',
      'cart': 'कार्ट',
      'profile': 'प्रोफ़ाइल',
      'categories': 'श्रेणियां',
      'featured_products': 'खास उत्पाद',
      'trending_now': 'अभी ट्रेंडिंग में',
      'add_to_cart': 'कार्ट में जोड़ें',
      'out_of_stock': 'स्टॉक में नहीं',
      'checkout': 'चेकआउट',
      'total': 'कुल',
      'place_order': 'ऑर्डर दें',
      'my_orders': 'मेरे ऑर्डर',
      'wallet': 'वॉलेट',
      'settings': 'सेटिंग्स',
      'logout': 'लॉगआउट',
      'notifications': 'नोटिफिकेशन',
      'delivery_to': 'डिलीवरी यहाँ',
      'change': 'बदलें',
    },
  };

  static String t(BuildContext context, String key) {
    // In a real app, this would use Locale from Provider or App state
    final locale = Localizations.localeOf(context).languageCode;
    return _localizedValues[locale]?[key] ?? _localizedValues['en']![key]!;
  }
}
