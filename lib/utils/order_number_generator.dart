import 'dart:math';

/// Utility class for generating unique order numbers
/// Format: HLM-YYYYMMDD-XXXX where XXXX is a random 4-digit number
class OrderNumberGenerator {
  static const String _prefix = 'HLM';
  static final Random _random = Random();

  /// Generates a unique order number with format HLM-YYYYMMDD-XXXX
  ///
  /// Example: HLM-20240519-1234
  ///
  /// [date] - Optional custom date, defaults to current date
  /// Returns a unique order number string
  static String generate({DateTime? date}) {
    final now = date ?? DateTime.now();
    final datePart = _formatDate(now);
    final randomPart = _generateRandom4Digit();
    return '$_prefix-$datePart-$randomPart';
  }

  /// Formats the date part of the order number (YYYYMMDD)
  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Generates a random 4-digit number (1000-9999)
  static int _generateRandom4Digit() {
    return _random.nextInt(9000) + 1000;
  }

  /// Validates an order number format
  /// Returns true if the format is valid (HLM-YYYYMMDD-XXXX)
  static bool validate(String orderNumber) {
    final regex = RegExp(r'^HLM-\d{8}-\d{4}$');
    return regex.hasMatch(orderNumber);
  }

  /// Extracts the date from an order number
  /// Returns null if the format is invalid
  static DateTime? extractDate(String orderNumber) {
    if (!validate(orderNumber)) return null;
    final datePart = orderNumber.split('-')[1];
    final year = int.parse(datePart.substring(0, 4));
    final month = int.parse(datePart.substring(4, 6));
    final day = int.parse(datePart.substring(6, 8));
    return DateTime(year, month, day);
  }

  /// Checks if an order number is from today
  static bool isFromToday(String orderNumber) {
    final extractedDate = extractDate(orderNumber);
    if (extractedDate == null) return false;
    final today = DateTime.now();
    return extractedDate.year == today.year &&
        extractedDate.month == today.month &&
        extractedDate.day == today.day;
  }
}
