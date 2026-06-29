/// Input validators for user data (phone, address, name)
/// Used in checkout and user profile forms
class Validators {
  // ────── Phone Number ──────
  /// Validates 10-digit Indian phone number
  static bool isValidPhone(String phone) {
    final trimmed = phone.replaceAll(' ', '').replaceAll('-', '');
    return RegExp(r'^\d{10}$').hasMatch(trimmed);
  }

  static String getPhoneError(String phone) {
    if (phone.isEmpty) return 'फोन नंबर आवश्यक है';
    if (phone.length < 10) return 'कम से कम 10 अंक दर्ज करें';
    if (!isValidPhone(phone)) return 'केवल संख्याएं दर्ज करें (10 अंक)';
    return '';
  }

  // ────── Address ──────
  /// Validates address (min 10 chars, no SQL injection)
  static bool isValidAddress(String address) {
    if (address.length < 10) return false;

    // Block SQL injection patterns
    final blockList = ['<', '>', '"', "'", ';', '/*', '*/'];
    for (final char in blockList) {
      if (address.contains(char)) return false;
    }
    return true;
  }

  static String getAddressError(String address) {
    if (address.isEmpty) return 'पता आवश्यक है';
    if (address.length < 10) return 'पता 10+ वर्ण होना चाहिए';
    if (!isValidAddress(address)) return 'विशेष वर्ण (<, >, ", \', ;) दर्ज न करें';
    return '';
  }

  // ────── Name ──────
  /// Validates name (2-50 chars, letters/spaces/hyphens/Hindi)
  static bool isValidName(String name) {
    if (name.length < 2 || name.length > 50) return false;

    // Allow: a-z, A-Z, 0-9, space, hyphen, Hindi (Devanagari)
    return RegExp(r'^[a-zA-Z0-9\s\-ऀ-ॿ]+$').hasMatch(name);
  }

  static String getNameError(String name) {
    if (name.isEmpty) return 'नाम आवश्यक है';
    if (name.length < 2) return 'कम से कम 2 वर्ण दर्ज करें';
    if (name.length > 50) return 'अधिकतम 50 वर्ण तक';
    if (!isValidName(name)) return 'केवल अक्षर, संख्या, रिक्ति, हाइफन दर्ज करें';
    return '';
  }

  // ────── Sanitize ──────
  /// Remove dangerous characters from input
  static String sanitize(String input) {
    return input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();
  }

  // ────── Batch Validation ──────
  /// Validate user info for checkout
  /// Returns: {valid: bool, errors: {field: errorMessage}}
  static Map<String, dynamic> validateCheckoutInfo({
    required String name,
    required String phone,
    required String address,
  }) {
    final errors = <String, String>{};

    final nameError = getNameError(name);
    if (nameError.isNotEmpty) errors['name'] = nameError;

    final phoneError = getPhoneError(phone);
    if (phoneError.isNotEmpty) errors['phone'] = phoneError;

    final addressError = getAddressError(address);
    if (addressError.isNotEmpty) errors['address'] = addressError;

    return {
      'valid': errors.isEmpty,
      'errors': errors,
    };
  }
}
