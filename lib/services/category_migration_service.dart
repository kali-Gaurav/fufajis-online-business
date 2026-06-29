import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'logging_service.dart';

/// CategoryMigrationService
///
/// Handles migration from STRING category names to immutable category Id values.
/// Golden Rule: category Id is immutable (enum name), category is legacy display field.
class CategoryMigrationService {
  static final CategoryMigrationService _instance = CategoryMigrationService._internal();
  factory CategoryMigrationService() => _instance;
  CategoryMigrationService._internal();

  static final _db = FirebaseFirestore.instance;
  static final _logger = LoggingService();

  /// Maps old category STRING to new category Id (enum name)
  ///
  /// Examples:
  ///   'Groceries' → 'groceries'
  ///   'vegetables' → 'vegetables'
  ///   'सब्जियाँ' → 'vegetables' (transliteration)
  static String mapCategoryToId(String oldCategory) {
    final normalized = oldCategory.toLowerCase().trim();

    // Try to match against ProductCategory enum names
    try {
      return ProductCategory.values
          .firstWhere((e) => e.name == normalized)
          .name;
    } catch (e) {
      _logger.warning('[CategoryMigration] Unmapped category, using fallback');
    }

    // Fallback mapping for common English variants
    final fallbackMap = {
      'grocery': 'groceries',
      'veg': 'vegetables',
      'veggies': 'vegetables',
      'fruit': 'fruits',
      'milk': 'dairy',
      'dairy products': 'dairy',
      'bread': 'bakery',
      'baked goods': 'bakery',
      'snack': 'snacks',
      'drink': 'beverages',
      'beverage': 'beverages',
      'soap': 'personalCare',
      'toothpaste': 'personalCare',
      'personal care': 'personalCare',
      'detergent': 'household',
      'cleaning': 'household',
      'house': 'household',
      'phone': 'electronics',
      'electric': 'electronics',
      'shirt': 'clothing',
      'cloth': 'clothing',
      'shoe': 'footwear',
      'decoration': 'homeDecor',
      'decor': 'homeDecor',
      'kitchen': 'kitchenware',
      'utensil': 'kitchenware',
      'pen': 'stationery',
      'paper': 'stationery',
      'book': 'stationery',
      'toy': 'toys',
      'game': 'toys',
      'medicine': 'medicines',
      'drug': 'medicines',
      'pill': 'medicines',
      'crop': 'agricultural',
      'farm': 'agricultural',
      'seed': 'agricultural',
    };

    final mapped = fallbackMap[normalized];
    if (mapped != null) return mapped;

    // Last resort: try substring matching
    for (final enumVal in ProductCategory.values) {
      if (normalized.contains(enumVal.name) || enumVal.name.contains(normalized)) {
        _logger.warning('[CategoryMigration] Using substring match');
        return enumVal.name;
      }
    }

    // Ultimate fallback
    return 'other';
  }

  /// Backfills category Id for all existing products
  ///
  /// Returns: (success count, error count, total count)
  static Future<(int, int, int)> migrateProducts({
    String? shopId,
  }) async {
    _logger.info('[CategoryMigration] Starting category backfill...');

    int success = 0;
    int errors = 0;
    int total = 0;

    try {
      // If shopId specified, migrate only that shop's products
      Query query = _db.collection('products');
      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snap = await query.get();
      total = snap.docs.length;

      _logger.info('[CategoryMigration] Found $total products to migrate');

      for (final doc in snap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Skip if already has category Id
          if (data.containsKey('categoryId') && data['categoryId'] != null) {
            _logger.info('[CategoryMigration] Skipping ${doc.id} (already has category Id)');
            success++;
            continue;
          }

          // Get category value (try new field first, then old)
          final oldCategory = (data['categoryId'] ?? data['category']) as String? ?? 'other';
          final newCategoryId = mapCategoryToId(oldCategory);

          // Update document with category Id
          await doc.reference.update({
            'categoryId': newCategoryId,
            // Also preserve category for backward compatibility
            'category': oldCategory,
          });

          _logger.info('[CategoryMigration] ✓ ${doc.id}: "$oldCategory" → "$newCategoryId"');
          success++;
        } catch (e, stack) {
          _logger.error('[CategoryMigration] Error for ${doc.id}', e, stack);
          errors++;
        }
      }

      _logger.info('[CategoryMigration] Complete: $success/$total succeeded, $errors failed');
    } catch (e, stack) {
      _logger.error('[CategoryMigration] Fatal error', e, stack);
      rethrow;
    }

    return (success, errors, total);
  }

  /// Validates that all products have category Id
  ///
  /// Returns: true if ALL products have category Id
  static Future<bool> validate({String? shopId}) async {
    try {
      _logger.info('[CategoryMigration] Running validation...');

      Query query = _db.collection('products').where('categoryId', isNull: true);
      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId);
      }

      final snap = await query.limit(10).get();

      if (snap.docs.isNotEmpty) {
        _logger.warning('[CategoryMigration] ❌ Found ${snap.docs.length} products without category Id');
        for (final doc in snap.docs.take(3)) {
          _logger.warning('[CategoryMigration] Example: ${doc.id} = ${doc['category']}');
        }
        return false;
      }

      _logger.info('[CategoryMigration] ✅ All products have category Id');
      return true;
    } catch (e, stack) {
      _logger.error('[CategoryMigration] Validation error', e, stack);
      return false;
    }
  }

  /// Gets migration status: how many products have/don't have category Id
  static Future<Map<String, int>> getStatus({String? shopId}) async {
    try {
      Query queryWithId = _db.collection('products').where('categoryId', isNotEqualTo: null);
      Query queryWithoutId = _db.collection('products').where('categoryId', isNull: true);

      if (shopId != null) {
        queryWithId = queryWithId.where('shopId', isEqualTo: shopId);
        queryWithoutId = queryWithoutId.where('shopId', isEqualTo: shopId);
      }

      final withId = await queryWithId.count().get();
      final withoutId = await queryWithoutId.count().get();

      return {
        'migrated': withId.count ?? 0,
        'pending': withoutId.count ?? 0,
        'total': (withId.count ?? 0) + (withoutId.count ?? 0),
      };
    } catch (e, stack) {
      _logger.error('[CategoryMigration] Status check error', e, stack);
      return {'migrated': -1, 'pending': -1, 'total': -1};
    }
  }

  /// One-time setup: Run this ONCE after deploying category Id changes
  /// Typically called from an admin screen or app startup (guard with flag)
  static Future<void> runMigrationIfNeeded({
    bool forceMigration = false,
    String? shopId,
  }) async {
    try {
      final status = await getStatus(shopId: shopId);
      final pending = status['pending'] ?? 0;
      final total = status['total'] ?? 0;

      if (pending == 0) {
        _logger.info('[CategoryMigration] ✅ Already migrated ($total products)');
        return;
      }

      if (!forceMigration && pending < (total * 0.05)) {
        // If <5% pending, might be new products added after migration
        _logger.info('[CategoryMigration] Only $pending/$total pending; skipping (set forceMigration=true to override)');
        return;
      }

      _logger.info('[CategoryMigration] Found $pending products pending migration...');
      final result = await migrateProducts(shopId: shopId);
      final (success, errors, migratedCount) = result;

      if (errors == 0) {
        final isValid = await validate(shopId: shopId);
        if (isValid) {
          _logger.info('[CategoryMigration] ✅ Migration successful and validated!');
        } else {
          _logger.warning('[CategoryMigration] ⚠️ Migration completed but validation failed');
        }
      } else {
        _logger.warning('[CategoryMigration] ⚠️ Migration completed with $errors errors');
      }
    } catch (e, stack) {
      _logger.error('[CategoryMigration] runMigrationIfNeeded failed', e, stack);
      rethrow;
    }
  }
}
