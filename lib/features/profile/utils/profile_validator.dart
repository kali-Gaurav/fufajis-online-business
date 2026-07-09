class ProfileValidator {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    if (value.length < 2) {
      return 'Must be at least 2 characters';
    }
    if (value.length > 50) {
      return 'Must be less than 50 characters';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Remove all non-numeric characters
    final cleanValue = value.replaceAll(RegExp(r'\D'), '');
    if (cleanValue.length < 10) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validatePinCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'PIN Code is required';
    }
    final cleanValue = value.replaceAll(RegExp(r'\D'), '');
    if (cleanValue.length != 6) {
      return 'Enter a valid 6-digit PIN code';
    }
    return null;
  }
}
