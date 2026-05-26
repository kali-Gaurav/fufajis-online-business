/// Service for filtering profanity and inappropriate content from reviews
class ProfanityFilterService {
  // Common profanity words and phrases (can be expanded)
  static const List<String> _profanityList = [
    'badword1',
    'badword2',
    'inappropriate',
    // Add more as needed
  ];

  /// Filter profanity from text
  /// Returns the original text if no profanity is found
  /// Returns modified text with asterisks if profanity is found
  String filter(String text) {
    String filtered = text.toLowerCase();
    bool hasProfanity = false;

    for (String word in _profanityList) {
      if (filtered.contains(word)) {
        hasProfanity = true;
        // Replace with asterisks
        final regex = RegExp(word, caseSensitive: false);
        filtered = filtered.replaceAll(regex, '*' * word.length);
      }
    }

    // If profanity was found, return the filtered version
    // Otherwise return original text
    return hasProfanity ? filtered : text;
  }

  /// Check if text contains profanity
  bool hasProfanity(String text) {
    final lowerText = text.toLowerCase();
    return _profanityList.any((word) => lowerText.contains(word));
  }

  /// Get list of profanity words found in text
  List<String> getProfanityWords(String text) {
    final lowerText = text.toLowerCase();
    return _profanityList.where((word) => lowerText.contains(word)).toList();
  }
}
