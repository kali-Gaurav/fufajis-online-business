/// Ambiguity Resolver — Handle cases where voice input is ambiguous
///
/// Examples:
///   • User says "oil" → which oil? (mustard, sunflower, coconut, olive)
///   • User says "biscuit" → which brand? (marie, digestive, bourbon)
///   • User says "rice" → which type? (basmati, white, brown, jasmine)
///
/// Strategy:
/// 1. User search returns multiple candidates
/// 2. Filter to top N most popular/available products
/// 3. Present clarification UI: "Which oil? Mustard, Sunflower, or Coconut?"
/// 4. Wait for follow-up voice input or tap selection

import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class AmbiguityCase {
  final String query; // What user said
  final List<ProductModel> candidates; // Top N matches
  final String clarificationQuestion; // "Which oil?"
  final bool requiresClarification; // true if ambiguous

  AmbiguityCase({
    required this.query,
    required this.candidates,
    required this.clarificationQuestion,
    required this.requiresClarification,
  });
}

class AmbiguityResolver {
  /// Check if product search is ambiguous
  /// Returns clarification case if ambiguous, null if clear
  static AmbiguityCase? resolve(
    String query,
    List<ProductModel> allMatches,
  ) {
    if (allMatches.isEmpty) return null;

    // If only one clear match, no ambiguity
    if (allMatches.length == 1) {
      return AmbiguityCase(
        query: query,
        candidates: allMatches,
        clarificationQuestion: '',
        requiresClarification: false,
      );
    }

    // If multiple matches AND top 2 have similar confidence, it's ambiguous
    if (allMatches.length >= 2) {
      // Group by category to detect ambiguity
      final byCategory = <String, List<ProductModel>>{};
      for (final product in allMatches.take(5)) {
        byCategory.putIfAbsent(product.category, () => []).add(product);
      }

      // If same category, likely not ambiguous (e.g., all rice types)
      // If different categories, ambiguous (e.g., oil vs ghee)
      if (byCategory.length > 1) {
        // Multi-category ambiguity
        return _createClarificationCase(query, allMatches.take(3).toList());
      }

      // If many products in same category, pick top 3
      if (allMatches.length > 3) {
        return _createClarificationCase(query, allMatches.take(3).toList());
      }
    }

    // No ambiguity
    return AmbiguityCase(
      query: query,
      candidates: allMatches,
      clarificationQuestion: '',
      requiresClarification: false,
    );
  }

  /// Create a clarification case with smart question
  static AmbiguityCase _createClarificationCase(
    String query,
    List<ProductModel> top3,
  ) {
    final names = top3.map((p) => p.name).toList();
    final question = _generateQuestion(query, names);

    debugPrint('[AmbiguityResolver] Ambiguous: "$query" → $names');
    debugPrint('[AmbiguityResolver] Question: $question');

    return AmbiguityCase(
      query: query,
      candidates: top3,
      clarificationQuestion: question,
      requiresClarification: true,
    );
  }

  /// Generate smart clarification question
  /// "oil" + ["Mustard Oil", "Sunflower Oil", "Coconut Oil"]
  /// → "Which oil? Mustard, Sunflower, or Coconut?"
  static String _generateQuestion(String query, List<String> options) {
    if (options.isEmpty) return 'Which one?';

    // Extract the main category/type from options
    final mainWords = <String>[];
    for (final option in options) {
      // "Mustard Oil" → extract "Mustard"
      final words = option.split(' ');
      if (words.length > 1 && words.last.toLowerCase() == query.toLowerCase()) {
        // Last word matches query, use first word
        mainWords.add(words.first);
      } else {
        // Use first word
        mainWords.add(words.first);
      }
    }

    // Format options
    late String optionsStr;
    if (mainWords.length == 1) {
      optionsStr = mainWords[0];
    } else if (mainWords.length == 2) {
      optionsStr = '${mainWords[0]} or ${mainWords[1]}';
    } else {
      final all = mainWords.sublist(0, mainWords.length - 1).join(', ');
      optionsStr = '$all, or ${mainWords.last}';
    }

    return 'Which ${query}? $optionsStr?';
  }

  /// User picked one from the options
  /// Return the selected product
  static ProductModel? selectFromOptions(
    AmbiguityCase case_,
    int selectedIndex,
  ) {
    if (selectedIndex < 0 || selectedIndex >= case_.candidates.length) {
      return null;
    }
    return case_.candidates[selectedIndex];
  }

  /// Check if follow-up voice input clarifies the ambiguity
  /// User says "mustard" to clarify "which oil"
  static ProductModel? clarifyWithVoice(
    AmbiguityCase case_,
    String clarificationVoice,
  ) {
    final clean = clarificationVoice.trim().toLowerCase();

    // Match clarification against candidate names
    for (final candidate in case_.candidates) {
      final name = candidate.name.toLowerCase();
      if (name.contains(clean) || clean.contains(name)) {
        return candidate;
      }

      // Also check Hindi name
      final hindiName = candidate.hindiName.toLowerCase();
      if (hindiName.contains(clean) || clean.contains(hindiName)) {
        return candidate;
      }
    }

    // No clear match
    return null;
  }
}
