import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Lightning Deals Service
///
/// Manages time-bound flash sales with:
/// - Real-time Firestore stream subscription
/// - In-memory cache (avoids re-fetching on every rebuild)
/// - Auto-expiry detection (removes deals past endTime client-side)
/// - Sold-out detection (qty_remaining == 0)
/// - Owner tools: create / schedule / cancel deals
class LightningDealsService {
  static final LightningDealsService _instance = LightningDealsService._internal();
  factory LightningDealsService() => _instance;
  LightningDealsService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache
  List<LightningDeal> _cache = [];
  StreamSubscription<QuerySnapshot>? _sub;
  final _controller = StreamController<List<LightningDeal>>.broadcast();

  /// Live stream of active + not-sold-out deals. Safe to listen to multiple times.
  Stream<List<LightningDeal>> get activeDealsStream => _controller.stream;

  /// Returns latest cached deals synchronously (great for initial render).
  List<LightningDeal> get cachedDeals => _cache;

  // ─── Start real-time listener ─────────────────────────────────────────────────
  void startListening() {
    _sub?.cancel();
    _sub = _db
        .collection('lightning_deals')
        .where('isActive', isEqualTo: true)
        .orderBy('endTime')
        .snapshots()
        .listen(
          (snap) {
            final now = DateTime.now();
            _cache = snap.docs
                .map((d) => LightningDeal.fromMap(d.data(), d.id))
                .where((deal) => deal.endTime.isAfter(now) && !deal.isSoldOut)
                .toList();
            _controller.add(_cache);
            debugPrint('[LightningDeals] ${_cache.length} active deals streamed.');
          },
          onError: (e) {
            debugPrint('[LightningDeals] Stream error: $e');
          },
        );
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  // ─── One-shot fetch (for push notification clicks) ────────────────────────────
  Future<List<LightningDeal>> fetchActiveDeals() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final snap = await _db
          .collection('lightning_deals')
          .where('isActive', isEqualTo: true)
          .where('endTime', isGreaterThan: now)
          .orderBy('endTime')
          .get();

      final deals = snap.docs
          .map((d) => LightningDeal.fromMap(d.data(), d.id))
          .where((d) => !d.isSoldOut)
          .toList();

      _cache = deals;
      return deals;
    } catch (e) {
      debugPrint('[LightningDeals] Fetch error: $e');
      return _cache;
    }
  }

  // ─── Owner: Create a new lightning deal ───────────────────────────────────────
  Future<String> createDeal({
    required String productId,
    required String productName,
    required String imageUrl,
    required double originalPrice,
    required double dealPrice,
    required int totalQty,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    assert(dealPrice < originalPrice, 'Deal price must be below original price');
    assert(endTime.isAfter(startTime), 'End time must be after start time');

    final docRef = await _db.collection('lightning_deals').add({
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'dealPrice': dealPrice,
      'discountPct': ((originalPrice - dealPrice) / originalPrice * 100).round(),
      'totalQty': totalQty,
      'qtyRemaining': totalQty,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': startTime.isBefore(DateTime.now()),
      'isScheduled': startTime.isAfter(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // ─── Customer: Reserve a deal slot (atomic transaction) ───────────────────────
  Future<DealClaimResult> claimDealSlot({
    required String dealId,
    required String customerId,
    required int qty,
  }) async {
    try {
      final dealRef = _db.collection('lightning_deals').doc(dealId);
      DealClaimResult? result;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(dealRef);
        if (!snap.exists) {
          result = DealClaimResult.notFound;
          return;
        }
        final remaining = (snap['qtyRemaining'] as int? ?? 0);
        if (remaining < qty) {
          result = DealClaimResult.soldOut;
          return;
        }
        final endTime = (snap['endTime'] as Timestamp).toDate();
        if (endTime.isBefore(DateTime.now())) {
          result = DealClaimResult.expired;
          return;
        }

        tx.update(dealRef, {'qtyRemaining': FieldValue.increment(-qty)});

        // Record claim
        tx.set(_db.collection('lightning_deal_claims').doc('${dealId}_$customerId'), {
          'dealId': dealId,
          'customerId': customerId,
          'qty': qty,
          'claimedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        result = DealClaimResult.success;
      });

      return result ?? DealClaimResult.failed;
    } catch (e) {
      debugPrint('[LightningDeals] Claim error: $e');
      return DealClaimResult.failed;
    }
  }

  // ─── Owner: Cancel a deal ─────────────────────────────────────────────────────
  Future<void> cancelDeal(String dealId) async {
    await _db.collection('lightning_deals').doc(dealId).update({
      'isActive': false,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Get deals for a specific product ────────────────────────────────────────
  Future<LightningDeal?> getActiveDealForProduct(String productId) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('lightning_deals')
        .where('productId', isEqualTo: productId)
        .where('isActive', isEqualTo: true)
        .where('endTime', isGreaterThan: now)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return LightningDeal.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────
class LightningDeal {
  final String id;
  final String productId;
  final String productName;
  final String imageUrl;
  final double originalPrice;
  final double dealPrice;
  final int discountPct;
  final int totalQty;
  final int qtyRemaining;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;

  const LightningDeal({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.originalPrice,
    required this.dealPrice,
    required this.discountPct,
    required this.totalQty,
    required this.qtyRemaining,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  bool get isSoldOut => qtyRemaining <= 0;
  bool get isExpired => endTime.isBefore(DateTime.now());
  double get claimedPct => totalQty > 0 ? (totalQty - qtyRemaining) / totalQty : 1.0;

  factory LightningDeal.fromMap(Map<String, dynamic> m, String id) {
    return LightningDeal(
      id: id,
      productId: m['productId'] as String? ?? '',
      productName: m['productName'] as String? ?? '',
      imageUrl: m['imageUrl'] as String? ?? '',
      originalPrice: ((m['originalPrice'] as num?) ?? 0.0).toDouble(),
      dealPrice: ((m['dealPrice'] as num?) ?? 0.0).toDouble(),
      discountPct: (m['discountPct'] as num? ?? 0).toInt(),
      totalQty: (m['totalQty'] as num? ?? 0).toInt(),
      qtyRemaining: (m['qtyRemaining'] as num? ?? 0).toInt(),
      startTime: m['startTime'] is Timestamp
          ? (m['startTime'] as Timestamp).toDate()
          : DateTime.now(),
      endTime: m['endTime'] is Timestamp ? (m['endTime'] as Timestamp).toDate() : DateTime.now(),
      isActive: m['isActive'] as bool? ?? false,
    );
  }
}

enum DealClaimResult { success, soldOut, expired, notFound, failed }
