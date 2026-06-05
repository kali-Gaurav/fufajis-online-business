import 'dart:math';
import '../models/product_model.dart';

class TrieNode {
  final Map<String, TrieNode> children = {};
  final Set<String> productIds = {};
  bool isEndOfWord = false;
}

class TrieSearchEngine {
  final TrieNode _root = TrieNode();
  final Map<String, ProductModel> _productIndex = {};

  /// Populates the Trie index using a catalog list
  void buildIndex(List<ProductModel> catalog) {
    _productIndex.clear();
    _root.children.clear();
    _root.productIds.clear();
    _root.isEndOfWord = false;

    for (final product in catalog) {
      insertProduct(product);
    }
  }

  /// Inserts a single product into the Trie index under various keys
  void insertProduct(ProductModel product) {
    _productIndex[product.id] = product;

    // Index by product name words
    final nameWords = product.name.toLowerCase().split(RegExp(r'\s+'));
    for (final word in nameWords) {
      if (word.isNotEmpty) _insertWord(word, product.id);
    }

    // Index by category words
    final catWords = product.category.toLowerCase().split(RegExp(r'\s+'));
    for (final word in catWords) {
      if (word.isNotEmpty) _insertWord(word, product.id);
    }

    // Index by tags
    for (final tag in product.tags) {
      final cleanTag = tag.toLowerCase().trim();
      if (cleanTag.isNotEmpty) _insertWord(cleanTag, product.id);
    }
  }

  void _insertWord(String word, String productId) {
    TrieNode current = _root;
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      current = current.children.putIfAbsent(char, () => TrieNode());
      // Every node in the path stores matching productIds to support prefix-based candidate retrieval
      current.productIds.add(productId);
    }
    current.isEndOfWord = true;
  }

  /// O(L) prefix search: Returns all matching product IDs
  List<ProductModel> searchPrefix(String prefix) {
    final cleanPrefix = prefix.toLowerCase().trim();
    if (cleanPrefix.isEmpty) return [];

    TrieNode current = _root;
    for (int i = 0; i < cleanPrefix.length; i++) {
      final char = cleanPrefix[i];
      final nextNode = current.children[char];
      if (nextNode == null) return []; // prefix not found
      current = nextNode;
    }

    return current.productIds
        .map((id) => _productIndex[id])
        .whereType<ProductModel>()
        .toList();
  }

  /// Search with Levenshtein fuzzy distance matching for typo tolerance
  List<MapEntry<ProductModel, double>> searchFuzzy(
    String query, {
    int maxDistance = 2,
  }) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return [];

    final Map<String, int> bestDistances = {};
    _collectFuzzyMatches(_root, '', cleanQuery, maxDistance, bestDistances);

    final List<MapEntry<ProductModel, double>> results = [];
    for (final entry in bestDistances.entries) {
      final productId = entry.key;
      final distance = entry.value;
      final product = _productIndex[productId];
      if (product == null) continue;

      // Score formula: confidence scales inversely with edit distance
      final double confidence =
          1.0 - (distance / (cleanQuery.length + maxDistance));
      results.add(MapEntry(product, confidence.clamp(0.1, 1.0)));
    }

    // Sort by descending confidence score
    results.sort((a, b) => b.value.compareTo(a.value));
    return results;
  }

  void _collectFuzzyMatches(
    TrieNode node,
    String currentWord,
    String query,
    int maxDistance,
    Map<String, int> bestDistances,
  ) {
    if (node.isEndOfWord) {
      final distance = _calculateLevenshtein(currentWord, query);
      if (distance <= maxDistance) {
        for (final pId in node.productIds) {
          final currentBest = bestDistances[pId];
          if (currentBest == null || distance < currentBest) {
            bestDistances[pId] = distance;
          }
        }
      }
    }

    // Early termination optimization: If currentWord is much longer than query, prune subtree
    if (currentWord.length > query.length + maxDistance) return;

    for (final childEntry in node.children.entries) {
      _collectFuzzyMatches(
        childEntry.value,
        currentWord + childEntry.key,
        query,
        maxDistance,
        bestDistances,
      );
    }
  }

  int _calculateLevenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }
}
