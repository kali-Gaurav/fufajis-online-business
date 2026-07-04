/// 🌐 App Localization Strings
/// English and Hindi translations for Fufaji Store
/// Key-based approach for easy management

class AppStrings {
  /// PRODUCT CARD STRINGS
  static const Map<String, Map<String, String>> productCard = {
    'en': {
      'addToCart': 'Add to Cart',
      'addedToCart': 'Added to Cart',
      'viewDetails': 'View Details',
      'share': 'Share',
      'wishlist': 'Wishlist',
      'inStock': '✓ In Stock',
      'outOfStock': '✗ Out of Stock',
      'limitedStock': '⚠ Limited Stock',
      'runningLow': '⚠ Running Low',
      'originalPrice': 'Original Price',
      'discount': 'OFF',
      'save': 'Save',
      'rating': 'Rating',
      'reviews': 'Reviews',
      'weight': 'Weight',
    },
    'hi': {
      'addToCart': 'कार्ट में जोड़ें',
      'addedToCart': 'कार्ट में जोड़ा गया',
      'viewDetails': 'विवरण देखें',
      'share': 'शेयर करें',
      'wishlist': 'विशलिस्ट',
      'inStock': '✓ स्टॉक में है',
      'outOfStock': '✗ स्टॉक से बाहर',
      'limitedStock': '⚠ सीमित स्टॉक',
      'runningLow': '⚠ कम स्टॉक',
      'originalPrice': 'मूल मूल्य',
      'discount': 'छूट',
      'save': 'बचत करें',
      'rating': 'रेटिंग',
      'reviews': 'समीक्षाएं',
      'weight': 'वजन',
    },
  };

  /// PRICING STRINGS
  static const Map<String, Map<String, String>> pricing = {
    'en': {
      'basePrice': 'Base Price',
      'discount': 'Discount',
      'afterDiscount': 'After Discount',
      'gst': 'GST (18%)',
      'totalPrice': 'Total Price',
      'priceBreakup': 'Price Breakup',
      'youSave': 'You Save',
      'finalPrice': 'Final Price',
    },
    'hi': {
      'basePrice': 'आधार मूल्य',
      'discount': 'छूट',
      'afterDiscount': 'छूट के बाद',
      'gst': 'GST (18%)',
      'totalPrice': 'कुल मूल्य',
      'priceBreakup': 'मूल्य विवरण',
      'youSave': 'आप बचाएं',
      'finalPrice': 'अंतिम मूल्य',
    },
  };

  /// CART STRINGS
  static const Map<String, Map<String, String>> cart = {
    'en': {
      'emptyCart': 'Your cart is empty',
      'continueShop': 'Continue Shopping',
      'quantity': 'Quantity',
      'remove': 'Remove',
      'proceedCheckout': 'Proceed to Checkout',
      'subtotal': 'Subtotal',
      'shipping': 'Shipping',
      'tax': 'Tax',
      'total': 'Total',
      'cartUpdated': 'Cart updated',
      'itemRemoved': 'Item removed from cart',
    },
    'hi': {
      'emptyCart': 'आपकी कार्ट खाली है',
      'continueShop': 'खरीदारी जारी रखें',
      'quantity': 'मात्रा',
      'remove': 'हटाएं',
      'proceedCheckout': 'चेकआउट के लिए आगे बढ़ें',
      'subtotal': 'उप कुल',
      'shipping': 'शिपिंग',
      'tax': 'कर',
      'total': 'कुल',
      'cartUpdated': 'कार्ट अपडेट किया गया',
      'itemRemoved': 'कार्ट से आइटम हटाया गया',
    },
  };

  /// CHECKOUT STRINGS
  static const Map<String, Map<String, String>> checkout = {
    'en': {
      'shippingAddress': 'Shipping Address',
      'orderSummary': 'Order Summary',
      'paymentMethod': 'Payment Method',
      'placeOrder': 'Place Order',
      'orderPlaced': 'Order Placed Successfully',
      'orderNumber': 'Order Number',
      'estimatedDelivery': 'Estimated Delivery',
      'trackOrder': 'Track Order',
    },
    'hi': {
      'shippingAddress': 'डिलीवरी पता',
      'orderSummary': 'ऑर्डर सारांश',
      'paymentMethod': 'भुगतान विधि',
      'placeOrder': 'ऑर्डर दें',
      'orderPlaced': 'ऑर्डर सफलतापूर्वक दिया गया',
      'orderNumber': 'ऑर्डर नंबर',
      'estimatedDelivery': 'अनुमानित डिलीवरी',
      'trackOrder': 'ऑर्डर ट्रैक करें',
    },
  };

  /// ERROR STRINGS
  static const Map<String, Map<String, String>> errors = {
    'en': {
      'error': 'Error',
      'tryAgain': 'Try Again',
      'networkError': 'Network Error',
      'somethingWentWrong': 'Something went wrong',
      'noInternet': 'No internet connection',
      'loadingFailed': 'Failed to load. Please try again.',
      'invalidInput': 'Please enter valid information',
      'emptyField': 'This field cannot be empty',
    },
    'hi': {
      'error': 'त्रुटि',
      'tryAgain': 'फिर से कोशिश करें',
      'networkError': 'नेटवर्क त्रुटि',
      'somethingWentWrong': 'कुछ गलत हो गया',
      'noInternet': 'इंटरनेट कनेक्शन नहीं',
      'loadingFailed': 'लोड करने में विफल। कृपया पुनः प्रयास करें।',
      'invalidInput': 'कृपया मान्य जानकारी दर्ज करें',
      'emptyField': 'यह फील्ड खाली नहीं हो सकता',
    },
  };

  /// SUCCESS STRINGS
  static const Map<String, Map<String, String>> success = {
    'en': {
      'success': 'Success',
      'done': 'Done',
      'saved': 'Saved successfully',
      'added': 'Added successfully',
      'updated': 'Updated successfully',
      'deleted': 'Deleted successfully',
      'completed': 'Completed',
    },
    'hi': {
      'success': 'सफलता',
      'done': 'पूरा',
      'saved': 'सफलतापूर्वक सहेजा गया',
      'added': 'सफलतापूर्वक जोड़ा गया',
      'updated': 'सफलतापूर्वक अपडेट किया गया',
      'deleted': 'सफलतापूर्वक हटाया गया',
      'completed': 'पूर्ण',
    },
  };

  /// DAD JOKES
  static const Map<String, Map<String, String>> dadJokes = {
    'en': {
      'onAddToCart': 'Great choice! I dad-dicate myself to fast delivery!',
      'onCheckout': 'I am not saying I am the best dad-seller, but my prices are amazing!',
      'onOrderSuccess': 'That is what I call a dad-dy good purchase!',
      'onReorder': 'You are back for more? I must be doing something dad-right!',
    },
    'hi': {
      'onAddToCart': 'बढ़िया पसंद! मैं तेजी से डिलीवरी के लिए पापा समर्पित हूं!',
      'onCheckout': 'मेरी कीमतें अविश्वास्य हैं!',
      'onOrderSuccess': 'यह एक पापा-अच्छी खरीद है!',
      'onReorder': 'आप फिर वापस आ गए? मैं कुछ पापा-सही कर रहा हूं!',
    },
  };

  /// Get string by key and language
  static String getString(
    String category,
    String key,
    String language, {
    String defaultValue = '',
  }) {
    try {
      final Map<String, Map<String, String>>? categoryMap =
          _getCategoryMap(category);
      return categoryMap?[language]?[key] ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Get category map by name
  static Map<String, Map<String, String>>? _getCategoryMap(String category) {
    switch (category.toLowerCase()) {
      case 'productcard':
        return productCard;
      case 'pricing':
        return pricing;
      case 'cart':
        return cart;
      case 'checkout':
        return checkout;
      case 'errors':
        return errors;
      case 'success':
        return success;
      case 'dadjokes':
        return dadJokes;
      default:
        return null;
    }
  }

  /// Get all keys in a category
  static List<String> getKeys(String category) {
    return _getCategoryMap(category)?['en']?.keys.toList() ?? [];
  }
}

/// Extension for easy string access
extension StringExtension on String {
  /// Example: 'addToCart'.getString('productCard', 'en')
  String getString(String category, String language) {
    return AppStrings.getString(category, this, language);
  }
}
