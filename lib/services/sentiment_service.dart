import '../models/chat_conversation_model.dart';

/// Task #68 — Client-side sentiment analysis for chat messages.
///
/// Uses a VADER-style lexicon approach: each keyword carries a weight,
/// intensifiers / negations adjust the score, and the final value maps
/// to a [SentimentLabel].
///
/// No external API — works fully offline.  Optimised for e-commerce
/// support conversations in Indian English.
class SentimentService {
  static final SentimentService _instance = SentimentService._internal();
  factory SentimentService() => _instance;
  SentimentService._internal();

  // ── Lexicon ──────────────────────────────────────────────────────────────
  // Weights: +1.0 = strongly positive, -1.0 = strongly negative.
  // Tuned for food/grocery e-commerce support context.

  static const Map<String, double> _lexicon = {
    // Strong positive
    'love': 0.9, 'amazing': 0.9, 'excellent': 0.9, 'fantastic': 0.9,
    'perfect': 0.9, 'outstanding': 0.9, 'superb': 0.9, 'wonderful': 0.9,

    // Positive
    'good': 0.6, 'great': 0.7, 'nice': 0.55, 'happy': 0.7, 'satisfied': 0.65,
    'pleased': 0.6, 'glad': 0.6, 'thanks': 0.5, 'thank': 0.5,
    'appreciated': 0.6, 'helpful': 0.6, 'fast': 0.4, 'quick': 0.4,
    'smooth': 0.4, 'resolved': 0.55, 'received': 0.3, 'delivered': 0.3,
    'correct': 0.4, 'fresh': 0.45, 'best': 0.7, 'love it': 0.85,
    'on time': 0.5, 'on-time': 0.5, 'prompt': 0.45, 'polite': 0.5,
    'professional': 0.5, 'impressed': 0.65, 'recommend': 0.55,

    // Mild positive
    'ok': 0.1, 'okay': 0.1, 'fine': 0.15, 'alright': 0.1, 'acceptable': 0.15,

    // Mild negative
    'late': -0.4, 'slow': -0.4, 'wait': -0.3, 'waiting': -0.35,
    'delay': -0.5, 'delayed': -0.5, 'missing': -0.5, 'missed': -0.5,
    'issue': -0.4, 'problem': -0.45, 'concern': -0.3, 'unclear': -0.3,

    // Negative
    'bad': -0.6, 'poor': -0.6, 'worst': -0.85, 'terrible': -0.85,
    'horrible': -0.85, 'awful': -0.8, 'useless': -0.75, 'broken': -0.6,
    'damaged': -0.65, 'wrong': -0.55, 'incorrect': -0.55, 'dirty': -0.6,
    'rotten': -0.75, 'spoiled': -0.7, 'expired': -0.75, 'stale': -0.65,
    'cold': -0.4, 'unhappy': -0.65, 'dissatisfied': -0.7,
    'disappointed': -0.7, 'upset': -0.65, 'frustrated': -0.7,
    'annoyed': -0.6, 'hate': -0.8, 'dislike': -0.55, 'complaint': -0.55,
    'complain': -0.55,
    'cheated': -0.85, 'fraud': -0.9, 'scam': -0.9, 'stealing': -0.9,
    'lied': -0.8, 'lie': -0.75, 'fake': -0.75, 'pathetic': -0.8,
    'pathetically': -0.8,
    'not delivered': -0.75, 'not received': -0.7, 'overcharged': -0.7,
    'overcharge': -0.7, 'extra charge': -0.65,

    // Strong negative / anger
    'angry': -0.9, 'furious': -0.95, 'outraged': -0.95, 'enraged': -0.95,
    'disgusting': -0.9, 'ridiculous': -0.75, 'unacceptable': -0.8,
    'escalate': -0.6, 'manager': -0.2, 'refund': -0.3, 'cancel': -0.35,
    'cancellation': -0.35, 'report': -0.4, 'legal': -0.5,
    'consumer forum': -0.8, 'police': -0.7, 'court': -0.7,
  };

  // Intensifiers multiply the base score.
  static const Map<String, double> _intensifiers = {
    'very': 1.3,
    'really': 1.25,
    'extremely': 1.5,
    'so': 1.2,
    'absolutely': 1.4,
    'totally': 1.3,
    'completely': 1.35,
    'highly': 1.25,
    'super': 1.3,
    'too': 1.2,
    'quite': 1.1,
    'rather': 1.05,
  };

  // Negations flip the sign and reduce magnitude.
  static const Set<String> _negations = {
    'not',
    "n't",
    'never',
    'no',
    'nobody',
    'nothing',
    'neither',
    'nor',
    'hardly',
    'barely',
  };

  // ── Public API ────────────────────────────────────────────────────────────

  /// Score a single text string.  Returns a clamped [-1, 1] value.
  double scoreText(String text) {
    if (text.trim().isEmpty) return 0.0;

    final tokens = _tokenize(text);
    double total = 0.0;
    int count = 0;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Check two-word phrases first (e.g. "not delivered")
      final phrase = i < tokens.length - 1 ? '$token ${tokens[i + 1]}' : null;
      double? phraseScore;
      if (phrase != null) phraseScore = _lexicon[phrase];

      if (phraseScore != null) {
        total += phraseScore;
        count++;
        i++; // skip next token — already consumed
        continue;
      }

      final baseScore = _lexicon[token];
      if (baseScore == null) continue;

      // Check for negation in the 3-word window before this token
      bool negated = false;
      for (int j = (i - 3).clamp(0, tokens.length - 1); j < i; j++) {
        if (_negations.contains(tokens[j])) {
          negated = true;
          break;
        }
      }

      // Check for intensifier immediately before this token
      double multiplier = 1.0;
      if (i > 0) {
        final prev = tokens[i - 1];
        multiplier = _intensifiers[prev] ?? 1.0;
      }

      double score = baseScore * multiplier;
      if (negated) score = -score * 0.8; // flip + soften

      total += score;
      count++;
    }

    if (count == 0) return 0.0;

    // Average + clamp
    final raw = total / count;
    return raw.clamp(-1.0, 1.0);
  }

  /// Score text and return both the numeric score and the label.
  ({double score, SentimentLabel label}) analyze(String text) {
    final score = scoreText(text);
    return (score: score, label: SentimentLabel.fromScore(score));
  }

  /// Compute a rolling sentiment score for a conversation by averaging the
  /// last [windowSize] customer-message scores.  Returns a weighted mean
  /// that gives more weight to the most recent messages (recency bias).
  double rollingScore(List<double> customerScores, {int windowSize = 10}) {
    if (customerScores.isEmpty) return 0.0;
    final window = customerScores.length > windowSize
        ? customerScores.sublist(customerScores.length - windowSize)
        : customerScores;

    double weightedSum = 0.0;
    double weightTotal = 0.0;
    for (int i = 0; i < window.length; i++) {
      final weight = (i + 1).toDouble(); // later messages get higher weight
      weightedSum += window[i] * weight;
      weightTotal += weight;
    }
    return (weightedSum / weightTotal).clamp(-1.0, 1.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
