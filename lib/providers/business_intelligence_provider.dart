import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/business_intelligence_service.dart';

/// Date-range presets surfaced in the BI dashboards' segmented selector.
enum BiRange { today, week, month, quarter, year, custom }

extension BiRangeLabel on BiRange {
  String get label {
    switch (this) {
      case BiRange.today:
        return 'Today';
      case BiRange.week:
        return '7 Days';
      case BiRange.month:
        return '30 Days';
      case BiRange.quarter:
        return '90 Days';
      case BiRange.year:
        return '1 Year';
      case BiRange.custom:
        return 'Custom';
    }
  }
}

/// Drives all three BI dashboards (Financial / Business / Franchise).
///
/// Owns date-range selection, loading/error state, a small in-memory cache
/// (keyed by shop + range), and the PDF export trigger. A single load populates
/// every report so switching dashboard tabs is instant.
class BusinessIntelligenceProvider with ChangeNotifier {
  final BusinessIntelligenceService _service = BusinessIntelligenceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  BusinessIntelligenceData? _data;
  bool _isLoading = false;
  String? _error;
  BiRange _range = BiRange.month;
  DateTime? _customFrom;
  DateTime? _customTo;

  /// When true (admin), aggregates across all branches instead of one shop.
  bool _allBranches = false;

  final Map<String, BusinessIntelligenceData> _cache = {};

  BusinessIntelligenceData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  BiRange get range => _range;
  bool get allBranches => _allBranches;

  FinancialReport get financial => _data?.financial ?? FinancialReport.empty();
  BusinessReport get business => _data?.business ?? BusinessReport.empty();
  FranchiseReport get franchise => _data?.franchise ?? FranchiseReport.empty();

  DateTime get from => _resolveRange().$1;
  DateTime get to => _resolveRange().$2;

  /// Switch preset range and reload. [load] is a no-op if data is cached.
  Future<void> setRange(BiRange range, {DateTime? customFrom, DateTime? customTo}) async {
    _range = range;
    if (range == BiRange.custom) {
      _customFrom = customFrom;
      _customTo = customTo;
    }
    await load();
  }

  Future<void> setAllBranches(bool value) async {
    if (_allBranches == value) return;
    _allBranches = value;
    await load(force: true);
  }

  /// Loads (or serves cached) reports for the active shop + range.
  Future<void> load({bool force = false}) async {
    final shopId = _allBranches ? '' : (_auth.currentUser?.uid ?? '');
    final (rangeFrom, rangeTo) = _resolveRange();
    final cacheKey =
        '$shopId|${_range.name}|${rangeFrom.millisecondsSinceEpoch}|${rangeTo.millisecondsSinceEpoch}';

    if (!force && _cache.containsKey(cacheKey)) {
      _data = _cache[cacheKey];
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.loadDashboard(shopId: shopId, from: rangeFrom, to: rangeTo);
      _data = result;
      _cache[cacheKey] = result;
    } catch (e) {
      _error = e.toString();
      debugPrint('[BIProvider] load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the cache (e.g. after new orders arrive) and reloads.
  Future<void> refresh() async {
    _cache.clear();
    await load(force: true);
  }

  /// Generates and shares the PDF report for the current dataset.
  Future<void> exportPdf() async {
    final d = _data;
    if (d == null) return;
    await _service.exportAndShare(d);
  }

  (DateTime, DateTime) _resolveRange() {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_range) {
      case BiRange.today:
        return (DateTime(now.year, now.month, now.day), endOfToday);
      case BiRange.week:
        return (now.subtract(const Duration(days: 7)), endOfToday);
      case BiRange.month:
        return (now.subtract(const Duration(days: 30)), endOfToday);
      case BiRange.quarter:
        return (now.subtract(const Duration(days: 90)), endOfToday);
      case BiRange.year:
        return (now.subtract(const Duration(days: 365)), endOfToday);
      case BiRange.custom:
        return (_customFrom ?? now.subtract(const Duration(days: 30)), _customTo ?? endOfToday);
    }
  }
}
