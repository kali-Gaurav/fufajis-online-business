import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'rds_database_service.dart';

/// Comparison operators supported by the Excel-like filter builder.
enum FilterOperator {
  equals,
  notEquals,
  contains,
  notContains,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  between,
  isEmpty,
  isNotEmpty,
  inList,
}

extension FilterOperatorLabel on FilterOperator {
  String get label {
    switch (this) {
      case FilterOperator.equals:
        return 'is equal to';
      case FilterOperator.notEquals:
        return 'is not equal to';
      case FilterOperator.contains:
        return 'contains';
      case FilterOperator.notContains:
        return 'does not contain';
      case FilterOperator.greaterThan:
        return '> greater than';
      case FilterOperator.greaterOrEqual:
        return '>= greater or equal';
      case FilterOperator.lessThan:
        return '< less than';
      case FilterOperator.lessOrEqual:
        return '<= less or equal';
      case FilterOperator.between:
        return 'between (a,b)';
      case FilterOperator.isEmpty:
        return 'is empty';
      case FilterOperator.isNotEmpty:
        return 'is not empty';
      case FilterOperator.inList:
        return 'is one of (comma list)';
    }
  }
}

enum FilterLogic { and, or }

class FilterCondition {
  final String field;
  final FilterOperator operator;
  final dynamic value;
  final dynamic value2;

  const FilterCondition({
    required this.field,
    required this.operator,
    this.value,
    this.value2,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'operator': operator.name,
      'value': value,
      'value2': value2,
    };
  }

  factory FilterCondition.fromMap(Map<String, dynamic> map) {
    return FilterCondition(
      field: map['field'] as String? ?? '',
      operator: FilterOperator.values.firstWhere(
        (e) => e.name == (map['operator'] as String? ?? ''),
        orElse: () => FilterOperator.equals,
      ),
      value: map['value'],
      value2: map['value2'],
    );
  }

  String describe() {
    switch (operator) {
      case FilterOperator.isEmpty:
        return '$field is empty';
      case FilterOperator.isNotEmpty:
        return '$field is not empty';
      case FilterOperator.between:
        return '$field between $value and $value2';
      case FilterOperator.inList:
        return '$field in [$value]';
      default:
        return '$field ${_symbolFor(operator)} $value';
    }
  }

  String _symbolFor(FilterOperator op) {
    switch (op) {
      case FilterOperator.equals: return '=';
      case FilterOperator.notEquals: return '!=';
      case FilterOperator.contains: return 'contains';
      case FilterOperator.notContains: return 'not contains';
      case FilterOperator.greaterThan: return '>';
      case FilterOperator.greaterOrEqual: return '>=';
      case FilterOperator.lessThan: return '<';
      case FilterOperator.lessOrEqual: return '<=';
      default: return op.name;
    }
  }
}

/// Service to query products dynamically via AWS RDS PostgreSQL.
class InventoryQueryService {
  static final InventoryQueryService _instance = InventoryQueryService._internal();
  factory InventoryQueryService() => _instance;
  InventoryQueryService._internal();

  final RDSDatabaseService _rds = RDSDatabaseService();

  static const Map<String, String> queryableFields = {
    'Name': 'name',
    'Category': 'category',
    'Sub Category': 'subCategory',
    'Brand': 'brand',
    'Price': 'price',
    'Original Price': 'original_price',
    'Cost Price': 'cost_price',
    'Discount %': 'discount_percentage',
    'Stock Quantity': 'current_stock', // Now maps to inventory.current_stock
    'Minimum Stock': 'reorder_level', // maps to inventory.reorder_level
    'Is Available': 'active',
  };

  /// Builds the parameterized WHERE clause for a set of conditions.
  /// Returns a tuple (or Map) containing the SQL string and the list of parameters.
  Map<String, dynamic> buildWhereClause(
    List<FilterCondition> conditions, {
    FilterLogic logic = FilterLogic.and,
    String? shopId,
    int startParamIndex = 1,
  }) {
    String sql = '';
    List<dynamic> params = [];
    int paramIndex = startParamIndex;

    if (shopId != null && shopId.isNotEmpty) {
      sql += ' AND p.shop_id = \$$paramIndex';
      params.add(shopId);
      paramIndex++;
    }

    if (conditions.isNotEmpty) {
      List<String> clauses = [];
      for (var c in conditions) {
        // Resolve column alias mapping
        String col = c.field == 'current_stock' || c.field == 'reorder_level'
            ? 'i.${c.field}'
            : 'p.${c.field}';

        switch (c.operator) {
          case FilterOperator.equals:
            clauses.add('$col = \$$paramIndex');
            params.add(c.value);
            paramIndex++;
            break;
          case FilterOperator.notEquals:
            clauses.add('$col != \$$paramIndex');
            params.add(c.value);
            paramIndex++;
            break;
          case FilterOperator.contains:
            clauses.add('$col ILIKE \$$paramIndex');
            params.add('%${c.value}%');
            paramIndex++;
            break;
          case FilterOperator.notContains:
            clauses.add('$col NOT ILIKE \$$paramIndex');
            params.add('%${c.value}%');
            paramIndex++;
            break;
          case FilterOperator.greaterThan:
            clauses.add('$col > \$$paramIndex');
            params.add(num.tryParse(c.value.toString()) ?? 0);
            paramIndex++;
            break;
          case FilterOperator.greaterOrEqual:
            clauses.add('$col >= \$$paramIndex');
            params.add(num.tryParse(c.value.toString()) ?? 0);
            paramIndex++;
            break;
          case FilterOperator.lessThan:
            clauses.add('$col < \$$paramIndex');
            params.add(num.tryParse(c.value.toString()) ?? 0);
            paramIndex++;
            break;
          case FilterOperator.lessOrEqual:
            clauses.add('$col <= \$$paramIndex');
            params.add(num.tryParse(c.value.toString()) ?? 0);
            paramIndex++;
            break;
          case FilterOperator.isEmpty:
            clauses.add('($col IS NULL OR $col::text = \'\')');
            break;
          case FilterOperator.isNotEmpty:
            clauses.add('($col IS NOT NULL AND $col::text != \'\')');
            break;
          case FilterOperator.between:
            clauses.add('$col BETWEEN \$$paramIndex AND \$${paramIndex + 1}');
            params.add(num.tryParse(c.value.toString()) ?? 0);
            params.add(num.tryParse(c.value2.toString()) ?? 0);
            paramIndex += 2;
            break;
          case FilterOperator.inList:
            final items = (c.value?.toString() ?? '').split(',').map((s) => s.trim()).toList();
            final placeholders = items.map((_) {
              final str = '\$$paramIndex';
              paramIndex++;
              return str;
            }).join(',');
            clauses.add('$col IN ($placeholders)');
            params.addAll(items);
            break;
        }
      }

      final joiner = logic == FilterLogic.and ? ' AND ' : ' OR ';
      sql += ' AND (${clauses.join(joiner)})';
    }

    return {
      'sql': sql,
      'params': params,
      'nextParamIndex': paramIndex,
    };
  }

  /// Builds and executes a dynamic SQL query on AWS RDS.
  /// For Phase 13, it joins `products` and `inventory`.
  Future<List<ProductModel>> fetchProductsSQL(
    List<FilterCondition> conditions, {
    FilterLogic logic = FilterLogic.and,
    String? shopId,
  }) async {
    try {
      String baseSql = '''
        SELECT p.*, i.current_stock as stockQuantity, i.reorder_level as minimumStock
        FROM products p
        LEFT JOIN inventory i ON p.id = i.product_id
        WHERE 1=1
      ''';

      final whereResult = buildWhereClause(conditions, logic: logic, shopId: shopId, startParamIndex: 1);
      baseSql += whereResult['sql'] as String;
      final params = whereResult['params'] as List<dynamic>;

      baseSql += ' ORDER BY p.name ASC LIMIT 500';

      final resultRows = await _rds.rows(baseSql, params: params);

      return resultRows.map((r) {
        final adaptedMap = {
          ...r,
          'id': r['id'],
          'name': r['name'],
          'category': r['category'],
          'price': r['price'],
          'stockQuantity': r['stockquantity'],
          'minimumStock': r['minimumstock'],
        };
        return ProductModel.fromMap(adaptedMap);
      }).toList();

    } catch (e) {
      debugPrint('[InventoryQueryService] SQL fetch failed: $e');
      return [];
    }
  }

  /// Saves a configured query for later use.
  Future<bool> saveQuery(String queryName, List<FilterCondition> conditions, FilterLogic logic, String ownerId) async {
    try {
      final filterJson = {
        'logic': logic.name,
        'conditions': conditions.map((c) => c.toMap()).toList(),
      };

      const sql = '''
        INSERT INTO saved_queries (owner_id, query_name, filter_json)
        VALUES (\$1, \$2, \$3)
      ''';
      await _rds.query(sql, params: [ownerId, queryName, jsonEncode(filterJson)], allowWrite: true);
      return true;
    } catch (e) {
      debugPrint('[InventoryQueryService] Error saving query: $e');
      return false;
    }
  }

  /// Retrieves all saved queries for an owner.
  Future<List<Map<String, dynamic>>> getSavedQueries(String ownerId) async {
    try {
      const sql = 'SELECT * FROM saved_queries WHERE owner_id = \$1 ORDER BY created_at DESC';
      final rows = await _rds.rows(sql, params: [ownerId]);
      return rows;
    } catch (e) {
      debugPrint('[InventoryQueryService] Error fetching saved queries: $e');
      return [];
    }
  }

  String describeConditions(List<FilterCondition> conditions, FilterLogic logic) {
    if (conditions.isEmpty) return 'All products';
    final joiner = logic == FilterLogic.and ? ' AND ' : ' OR ';
    return conditions.map((c) => c.describe()).join(joiner);
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Simple filter model used by BulkInventoryQueryScreen.
// Translates to FilterConditions for fetchProductsSQL.
// ─────────────────────────────────────────────────────────────────────────────
class InventoryQueryFilter {
  final String? category;
  final String stockOperator;   // '<=', '>=', '=='
  final double stockThreshold;
  final double? priceMin;
  final double? priceMax;
  final int? expiryWithinDays;  // products expiring within N days

  const InventoryQueryFilter({
    this.category,
    this.stockOperator = '<=',
    this.stockThreshold = 10,
    this.priceMin,
    this.priceMax,
    this.expiryWithinDays,
  });
}

extension InventoryQueryServiceSimple on InventoryQueryService {
  /// Simple query used by BulkInventoryQueryScreen — builds conditions from
  /// an [InventoryQueryFilter] and returns lightweight maps.
  Future<List<Map<String, dynamic>>> queryProducts(
      InventoryQueryFilter filter) async {
    final conditions = <FilterCondition>[];

    if (filter.category != null) {
      conditions.add(FilterCondition(
        field: 'category',
        operator: FilterOperator.equals,
        value: filter.category,
      ));
    }

    FilterOperator stockOp;
    switch (filter.stockOperator) {
      case '>=':
        stockOp = FilterOperator.greaterOrEqual;
        break;
      case '==':
        stockOp = FilterOperator.equals;
        break;
      default:
        stockOp = FilterOperator.lessOrEqual;
    }
    conditions.add(FilterCondition(
      field: 'current_stock',
      operator: stockOp,
      value: filter.stockThreshold,
    ));

    if (filter.priceMin != null) {
      conditions.add(FilterCondition(
        field: 'price',
        operator: FilterOperator.greaterOrEqual,
        value: filter.priceMin,
      ));
    }
    if (filter.priceMax != null && filter.priceMax! < 10000) {
      conditions.add(FilterCondition(
        field: 'price',
        operator: FilterOperator.lessOrEqual,
        value: filter.priceMax,
      ));
    }

    final products = await fetchProductsSQL(conditions);
    return products
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'category': p.category,
              'price': p.price,
              'stock': p.stockQuantity,
            })
        .toList();
  }
}
