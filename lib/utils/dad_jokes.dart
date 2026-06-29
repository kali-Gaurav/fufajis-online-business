import 'dart:math';

/// Dad jokes for Fufaji Store micro-interactions
/// Triggered on: add to cart, checkout success, order delivered, etc.
class DadJokes {
  static final Random _random = Random();

  static final List<String> jokes = [
    // Add to Cart jokes
    '🛒 बहुत बढ़िया! अब आपका कार्ट पूरी तरह लोड हो गया!',
    '🛒 कार्ट में डाल दिया! पापा को खरीदारी करना पसंद है!',
    '🛒 बस कर दिया! यह तो "कार्टिस वंडर" है!',

    // Checkout jokes
    '✅ आदेश की पुष्टि! अब आप आधिकारिक रूप से "खरीदार" हैं!',
    '✅ सफल! आपके पास अभी-अभी एक "चेक" साउट किया है!',
    '✅ बहुत अच्छा! आपका ऑर्डर तैयार है, हमारा भी!',

    // Product-related jokes
    '🎁 यह उत्पाद "पॉप"ुलर है!',
    '🏪 हमारे स्टोर में आपका स्वागत है - जहां पापा हमेशा सही होते हैं!',
    '🛍️ बस कहो - "मुझे वह चीज दिखा जो मुझे नहीं पता कि मुझे चाहिए!"',

    // Delivery jokes
    '🚚 डिलीवरी आ गई! आपके पापा का आदेश यहाँ है!',
    '📦 पैकेज आ गया! अब समय है "अनबॉक्स" की खुशी का!',
    '🏠 पहुँच गया! यह पैकेज "एड्रेस" को संभाल लेता है!',

    // Order-related
    '👨 पापा को कम कीमत पर सामान खरीदना पसंद है - आप सही जगह हैं!',
    '💰 बचत करो और पापा को खुश करो!',
    '⭐ अच्छा चुनाव! यह "रेटिंग" लायक है!',

    // Payment jokes
    '💳 भुगतान सफल! पापा की किस्मत आपके साथ है!',
    '💰 रुपये गए, सामान आएंगे!',
    '✓ लेन-देन हो गया! कोई बड़ी बात नहीं!',

    // General positivity
    '🎉 अद्भुत! आप खरीदारी में जीनियस हो!',
    '👍 शानदार चुनाव! पापा को यह पसंद आएगा!',
    '🌟 यह तो "डिल" है जिसे मिस नहीं करना चाहिए!',

    // Hindi-English mix (for variety)
    '📱 Tech-savvy खरीदार! आप बस awesome हो!',
    '🎊 Order placed successfully! पापा को धन्यवाद दो!',
    '🏆 Golden choice! यह तो "खजाना" है!',

    // More dad jokes
    'मैं एक ऑर्डर बना रहा था... लेकिन फिर मैंने "डिसकाउंट" पाया!',
    'क्या तुम जानते हो? हमारे सामान "परफेक्ट" हैं - बिल्कुल पापा जैसे!',
    'आपका कार्ट भरा है! अब समय है "चेकआउट" करने का!',
    'यह सामान इतना अच्छा है कि पापा को "शिकायत" करने के लिए कुछ नहीं!',
    '🎁 यह उपहार देने लायक है! पापा को यह पसंद आएगा!',
  ];

  /// Get a random dad joke
  static String getRandomJoke() {
    if (jokes.isEmpty) return 'खरीदारी मजेदार है!';
    return jokes[_random.nextInt(jokes.length)];
  }

  /// Get joke for specific action
  static String getJokeForAction(String action) {
    final actionLower = action.toLowerCase();

    if (actionLower.contains('cart') || actionLower.contains('add')) {
      return '🛒 बहुत बढ़िया! अब आपका कार्ट पूरी तरह लोड हो गया!';
    } else if (actionLower.contains('checkout') || actionLower.contains('order')) {
      return '✅ आदेश की पुष्टि! अब आप आधिकारिक रूप से "खरीदार" हैं!';
    } else if (actionLower.contains('delivery') || actionLower.contains('deliver')) {
      return '🚚 डिलीवरी आ गई! आपके पापा का आदेश यहाँ है!';
    } else if (actionLower.contains('payment') || actionLower.contains('paid')) {
      return '💳 भुगतान सफल! पापा की किस्मत आपके साथ है!';
    } else {
      return getRandomJoke();
    }
  }

  /// Check if should show joke (random 70% of the time)
  static bool shouldShowJoke() {
    return _random.nextDouble() > 0.3;
  }
}
