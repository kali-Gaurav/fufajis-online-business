import 'logging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Component 6 — Dynamic Pricing Margins via Firestore
///
/// All margin and strategy settings are stored in:
///   /settings/pricing_config  (global defaults)
///   /shops/{shopId}/pricing_rules/{ruleId}  (shop/category overrides)
///
/// This service provides a live-cached read layer so the rest of the
/// pricing engine never needs hardcoded constants.
///
/// Fufaji policy: Transparent Pricing = no hidden surcharges, margins are
/// visible to the owner but never shown to customers as percentage numbers.
class DynamicPricingConfigService {
  static final DynamicPricingConfigService _instance = DynamicPricingConfigService._internal();
  factory DynamicPricingConfigService() => _instance;
  DynamicPricingConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache
  PricingConfig? _globalCache;
  final Map<String, CategoryMarginRule> _categoryCache = {};
  DateTime? _cacheExpiry;
  static const Duration _cacheTTL = Duration(minutes: 15);

  // ─────────────── GLOBAL CONFIG ───────────────

  /// Returns the global pricing config, from cache if fresh.
  Future<PricingConfig> getGlobalConfig() async {
    if (_globalCache != null && _cacheExpiry != null && DateTime.now().isBefore(_cacheExpiry!)) {
      return _globalCache!;
    }
    return _refreshGlobalConfig();
  }

  Future<PricingConfig> _refreshGlobalConfig() async {
    try {
      final doc = await _firestore.collection('settings').doc('pricing_config').get();
      if (doc.exists) {
        _globalCache = PricingConfig.fromMap(doc.data()!);
      } else {
        // Bootstrap default config in Firestore if missing
        _globalCache = PricingConfig.defaultConfig();
        await _writeDefaultConfig(_globalCache!);
      }
      _cacheExpiry = DateTime.now().add(_cacheTTL);
      debugPrint(
        '[DynamicPricingConfig] Config loaded: minimumMargin=${_globalCache!.minimumMarginPercent}%',
      );
    } catch (e) {
      debugPrint('[DynamicPricingConfig] Config load failed, using defaults: $e');
      _globalCache ??= PricingConfig.defaultConfig();
    }
    return _globalCache!;
  }

  /// Returns effective minimum margin for a product (category overrides global).
  Future<double> getEffectiveMargin({required String shopId, required String category}) async {
    final categoryRule = await getCategoryRule(shopId, category);
    if (categoryRule != null) return categoryRule.marginPercent;
    final global = await getGlobalConfig();
    return global.minimumMarginPercent;
  }

  /// Returns effective pricing strategy.
  Future<String> getEffectiveStrategy({required String shopId, required String category}) async {
    final categoryRule = await getCategoryRule(shopId, category);
    if (categoryRule != null) return categoryRule.strategy;
    final global = await getGlobalConfig();
    return global.defaultStrategy;
  }

  // ─────────────── CATEGORY RULES ───────────────

  Future<CategoryMarginRule?> getCategoryRule(String shopId, String category) async {
    final cacheKey = '${shopId}_$category';
    if (_categoryCache.containsKey(cacheKey) &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _categoryCache[cacheKey];
    }

    try {
      final doc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_rules')
          .doc('rule_$category')
          .get();

      if (doc.exists) {
        final rule = CategoryMarginRule.fromMap(doc.data()!);
        _categoryCache[cacheKey] = rule;
        return rule;
      }
    } catch (e) {
      debugPrint('[DynamicPricingConfig] Category rule fetch error: $e');
    }
    return null;
  }

  /// Sets or updates a per-category margin rule for a shop.
  Future<void> setCategoryMarginRule({
    required String shopId,
    required String category,
    required double marginPercent,
    required String strategy,
    bool isActive = true,
  }) async {
    final ruleId = 'rule_$category';
    await _firestore.collection('shops').doc(shopId).collection('pricing_rules').doc(ruleId).set({
      'category': category,
      'marginPercent': marginPercent,
      'strategy': strategy,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Invalidate category cache
    _categoryCache.remove('${shopId}_$category');
    debugPrint('[DynamicPricingConfig] Category rule set: $category → $marginPercent%');
  }

  /// Lists all active margin rules for a shop (for admin UI).
  Future<List<CategoryMarginRule>> listCategoryRules(String shopId) async {
    try {
      final snap = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('pricing_rules')
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((d) => CategoryMarginRule.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('[DynamicPricingConfig] List rules error: $e');
      return [];
    }
  }

  // ─────────────── GLOBAL CONFIG WRITE ───────────────

  /// Updates global pricing configuration (owner/admin action).
  Future<void> updateGlobalConfig(PricingConfig config) async {
    await _firestore
        .collection('settings')
        .doc('pricing_config')
        .set(config.toMap(), SetOptions(merge: true));
    _globalCache = config;
    _cacheExpiry = DateTime.now().add(_cacheTTL);
    debugPrint('[DynamicPricingConfig] Global config updated.');
  }

  Future<void> _writeDefaultConfig(PricingConfig config) async {
    try {
      await _firestore.collection('settings').doc('pricing_config').set(config.toMap());
    } catch (e, stack) {
      LoggingService().error('Silent error caught', e, stack);
    }
  }

  /// Forces a cache refresh on next read.
  void invalidateCache() {
    _globalCache = null;
    _categoryCache.clear();
    _cacheExpiry = null;
  }

  /// Streams pricing config changes in real-time (for admin dashboard).
  Stream<PricingConfig> watchGlobalConfig() {
    return _firestore
        .collection('settings')
        .doc('pricing_config')
        .snapshots()
        .map(
          (snap) =>
              snap.exists ? PricingConfig.fromMap(snap.data()!) : PricingConfig.defaultConfig(),
        );
  }
}

// ─────────────── VALUE OBJECTS ───────────────

/// Global pricing configuration stored in Firestore /settings/pricing_config
class PricingConfig {
  final double minimumMarginPercent; // Hard floor — price never goes below cost + this
  final double defaultCompetitorMatchThreshold; // 2% = match if within 2%
  final String defaultStrategy; // 'match' | 'beat' | 'cost_plus' | 'premium'
  final bool autoApplyPriceChanges; // If false, owner must manually approve
  final int priceHistoryRetentionDays;
  final bool enableCompetitorTracking;

  const PricingConfig({
    required this.minimumMarginPercent,
    required this.defaultCompetitorMatchThreshold,
    required this.defaultStrategy,
    required this.autoApplyPriceChanges,
    required this.priceHistoryRetentionDays,
    required this.enableCompetitorTracking,
  });

  factory PricingConfig.defaultConfig() => const PricingConfig(
    minimumMarginPercent: 5.0,
    defaultCompetitorMatchThreshold: 2.0,
    defaultStrategy: 'match',
    autoApplyPriceChanges: false,
    priceHistoryRetentionDays: 90,
    enableCompetitorTracking: true,
  );

  factory PricingConfig.fromMap(Map<String, dynamic> map) => PricingConfig(
    minimumMarginPercent: ((map['minimumMarginPercent'] as num?) ?? 5.0).toDouble(),
    defaultCompetitorMatchThreshold: ((map['defaultCompetitorMatchThreshold'] as num?) ?? 2.0)
        .toDouble(),
    defaultStrategy: map['defaultStrategy'] as String? ?? 'match',
    autoApplyPriceChanges: map['autoApplyPriceChanges'] as bool? ?? false,
    priceHistoryRetentionDays: map['priceHistoryRetentionDays'] as int? ?? 90,
    enableCompetitorTracking: map['enableCompetitorTracking'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'minimumMarginPercent': minimumMarginPercent,
    'defaultCompetitorMatchThreshold': defaultCompetitorMatchThreshold,
    'defaultStrategy': defaultStrategy,
    'autoApplyPriceChanges': autoApplyPriceChanges,
    'priceHistoryRetentionDays': priceHistoryRetentionDays,
    'enableCompetitorTracking': enableCompetitorTracking,
  };
}

/// Per-category margin override for a specific shop
class CategoryMarginRule {
  final String category;
  final double marginPercent;
  final String strategy;
  final bool isActive;

  const CategoryMarginRule({
    required this.category,
    required this.marginPercent,
    required this.strategy,
    required this.isActive,
  });

  factory CategoryMarginRule.fromMap(Map<String, dynamic> map) => CategoryMarginRule(
    category: map['category'] as String? ?? '',
    marginPercent: ((map['marginPercent'] as num?) ?? 5.0).toDouble(),
    strategy: map['strategy'] as String? ?? 'match',
    isActive: map['isActive'] as bool? ?? true,
  );
}
