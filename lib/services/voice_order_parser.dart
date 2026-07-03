import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/product_model.dart';
import '../utils/monetary_value.dart';
import '../utils/string_utils.dart';
import 'hinglish_voice_search_parser.dart';
import 'gemini_service.dart';

/// One line item extracted from a spoken order, after matching to the catalog.
class ParsedVoiceItem {
  final String spokenName; // what we think they said (canonicalised)
  int quantity; // editable in the review UI
  final String unit; // kg / packet / piece / l ...
  ProductModel? product; // best catalog match (null = not found)
  final double confidence; // 0..1 overall (parse x match)
  final List<ProductModel> alternatives; // other candidates for manual pick
  bool selected; // ticked in the review list

  ParsedVoiceItem({
    required this.spokenName,
    required this.quantity,
    required this.unit,
    required this.product,
    required this.confidence,
    required this.alternatives,
    this.selected = true,
  });

  bool get isMatched => product != null;
  double get lineTotal => (product?.price ?? MonetaryValue(0.0)).toDouble() * quantity;
}

class _RawItem {
  final String name;
  final int quantity;
  final String unit;
  final double parseConfidence;
  _RawItem(this.name, this.quantity, this.unit, this.parseConfidence);
}

/// Hybrid voice-order parser with improved matching for Indian groceries.
///
/// transcript -> raw items {name, qty, unit}  (offline Hinglish parser, with an
/// opportunistic Gemini boost when it produces a richer result) -> each item
/// fuzzy-matched against the live catalog using keywords, Hindi names, and phonetic
/// matching -> [ParsedVoiceItem]s for review.
///
/// Designed to never throw and to always degrade gracefully offline.
///
/// Matching improves when:
///   • Product has keywords pre-loaded (e.g., "aloo", "potato", "आलू")
///   • Product has Hindi name matching
///   • Phonetic scoring handles Hinglish variations
class VoiceOrderParser {
  final HinglishVoiceSearchParser _hinglish = HinglishVoiceSearchParser();
  final GeminiService _gemini = GeminiService();

  // Lowered threshold (0.35 from 0.42) to handle Hinglish Indian product names better
  static const double _matchThreshold = 0.35;

  Future<List<ParsedVoiceItem>> parse(String transcript, List<ProductModel> catalog) async {
    final clean = transcript.trim();
    if (clean.isEmpty) return [];

    // 1) Offline pass — reliable, works with no internet.
    final offline = await _offlineRawItems(clean);

    // 2) Online boost — only adopted if it yields MORE usable items.
    List<_RawItem> chosen = offline;
    try {
      final online = await _geminiRawItems(clean).timeout(const Duration(seconds: 8));
      if (online.isNotEmpty &&
          _matchableCount(online, catalog) > _matchableCount(offline, catalog)) {
        chosen = online;
        debugPrint('[VoiceOrderParser] using Gemini result (${online.length} items)');
      }
    } catch (e) {
      debugPrint('[VoiceOrderParser] Gemini boost skipped: $e');
    }

    // 3) Match each raw item to the catalog.
    final items = <ParsedVoiceItem>[];
    for (final raw in chosen) {
      if (raw.name.trim().isEmpty) continue;
      final ranked = _rankMatches(raw.name, catalog);
      final best = ranked.isNotEmpty ? ranked.first : null;
      final matchScore = best?.$2 ?? 0.0;
      final product = (best != null && matchScore >= _matchThreshold) ? best.$1 : null;
      final alternatives = ranked.skip(product != null ? 1 : 0).take(4).map((e) => e.$1).toList();
      items.add(
        ParsedVoiceItem(
          spokenName: _titleCase(raw.name),
          quantity: raw.quantity.clamp(1, 99),
          unit: raw.unit.isEmpty ? (product?.unit ?? 'item') : raw.unit,
          product: product,
          confidence: (raw.parseConfidence * 0.4 + matchScore * 0.6).clamp(0.0, 1.0),
          alternatives: alternatives,
          selected: product != null,
        ),
      );
    }
    return items;
  }

  // ─────────────── raw extraction ───────────────

  Future<List<_RawItem>> _offlineRawItems(String text) async {
    try {
      final intents = await _hinglish.parseMultiItem(text);
      return intents
          .where((i) => i.productQuery.trim().isNotEmpty)
          .map((i) => _RawItem(i.productQuery, _toCount(i.quantity), i.unit, i.confidence))
          .toList();
    } catch (e) {
      debugPrint('[VoiceOrderParser] offline parse failed: $e');
      return [];
    }
  }

  Future<List<_RawItem>> _geminiRawItems(String text) async {
    final maps = await _gemini.parseItemListFromText(text);
    return maps.where((m) => (m['name'] ?? '').toString().trim().isNotEmpty).map((m) {
      final qtyRaw = m['quantity'];
      final qty = qtyRaw is num ? qtyRaw.toDouble() : double.tryParse('$qtyRaw') ?? 1.0;
      return _RawItem(m['name'].toString(), _toCount(qty), (m['unit'] ?? '').toString(), 0.85);
    }).toList();
  }

  int _toCount(double q) {
    if (q <= 0) return 1;
    final r = q.round();
    return r < 1 ? 1 : r;
  }

  int _matchableCount(List<_RawItem> items, List<ProductModel> catalog) {
    var n = 0;
    for (final it in items) {
      final ranked = _rankMatches(it.name, catalog);
      if (ranked.isNotEmpty && ranked.first.$2 >= _matchThreshold) n++;
    }
    return n;
  }

  // ─────────────── catalog matching ───────────────

  /// Returns (product, score) ranked best-first.
  /// Scores improved with keyword, Hindi name, and category-aware matching.
  List<(ProductModel, double)> _rankMatches(String query, List<ProductModel> catalog) {
    final q = _normalize(query);
    if (q.isEmpty) return [];
    final qTokens = q.split(' ').where((t) => t.length > 1).toList();

    final scored = <(ProductModel, double)>[];
    for (final p in catalog) {
      if (!p.isAvailable) continue;
      final name = _normalize(p.name);

      // Build haystack with Hindi name and keywords for richer matching
      final haystack = [
        p.name,
        p.hindiName, // NEW: Product's Hindi name
        p.category,
        p.subCategory,
        p.brand ?? '',
        ...p.tags,
        ...p.keywords, // NEW: Pre-computed keywords for this product
      ].join(' ');
      final hay = _normalize(haystack);

      double score = 0;

      // Exact match on name
      if (name == q) {
        score = 1.0;
      }
      // Substring match on name
      else if (name.contains(q) || q.contains(name)) {
        score = 0.9;
      }
      // Keyword-based match (NEW): Check if query matches any keyword directly
      else if (p.keywords.isNotEmpty) {
        for (final keyword in p.keywords) {
          final norm_kw = _normalize(keyword);
          if (norm_kw == q || q.contains(norm_kw) || norm_kw.contains(q)) {
            score = 0.85; // High confidence for keyword match
            break;
          }
        }
      }

      // Hindi name match (NEW): Check normalized Hindi name
      if (score == 0 && p.hindiName.isNotEmpty) {
        final hindiName = _normalize(p.hindiName);
        if (hindiName == q || hindiName.contains(q) || q.contains(hindiName)) {
          score = 0.85;
        }
      }

      // Token-based matching with phonetic fallback
      if (score == 0) {
        final nameTokens = name.split(' ').where((t) => t.length > 1).toList();
        int overlap = 0;
        for (final qt in qTokens) {
          if (nameTokens.contains(qt) || hay.contains(qt)) {
            overlap++;
          } else {
            // Phonetic/fuzzy on tokens
            for (final nt in nameTokens) {
              if (StringUtils.isPhoneticMatch(qt, nt, threshold: qt.length > 5 ? 2 : 1)) {
                overlap++;
                break;
              }
            }
            // NEW: Also check against keywords
            if (overlap == 0) {
              for (final keyword in p.keywords) {
                final norm_kw = _normalize(keyword);
                if (StringUtils.isPhoneticMatch(qt, norm_kw, threshold: qt.length > 5 ? 2 : 1)) {
                  overlap++;
                  break;
                }
              }
            }
          }
        }
        if (qTokens.isNotEmpty) {
          score = (overlap / qTokens.length) * 0.8;
        }
        // Levenshtein closeness on the strongest token pair
        final lev = _bestTokenSimilarity(qTokens, nameTokens);
        if (lev > score) score = lev;
      }

      if (score > 0) scored.add((p, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored;
  }

  double _bestTokenSimilarity(List<String> a, List<String> b) {
    double best = 0;
    for (final x in a) {
      for (final y in b) {
        final maxLen = x.length > y.length ? x.length : y.length;
        if (maxLen == 0) continue;
        final dist = StringUtils.levenshteinDistance(x, y);
        final sim = 1 - (dist / maxLen);
        if (sim > best) best = sim;
      }
    }
    // Only trust strong similarity to avoid false matches.
    return best >= 0.7 ? best * 0.75 : 0;
  }

  String _normalize(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9ऀ-ॿ\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _titleCase(String v) => v
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}
