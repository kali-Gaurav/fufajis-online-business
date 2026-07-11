import 'package:fufaji/models/inventory_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fufaji/utils/analytics_performance.dart';
import 'dart:developer' as developer;

/// Supplier management service
/// Handles supplier lifecycle, ratings, performance metrics
class SupplierService {
  static final SupplierService _instance = SupplierService._internal();

  factory SupplierService() {
    return _instance;
  }

  SupplierService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPrefix = 'inventory';

  // Get all active suppliers
  Future<List<Supplier>> getAllSuppliers({bool activeOnly = true}) async {
    try {
      developer.log('Fetching suppliers (activeOnly: $activeOnly)');

      final cached = AnalyticsPerformance.getCachedValue<List<Supplier>>('all_suppliers');
      if (cached != null) {
        developer.log('Cache hit for all_suppliers');
        return cached;
      }

      var query = _firestore.collection('$_collectionPrefix/suppliers');

      if (activeOnly) {
        query = query.where('active', isEqualTo: true) as Query<Map<String, dynamic>>;
      }

      final snapshot = await query.orderBy('rating', descending: true).get();

      final suppliers = snapshot.docs
          .map((doc) => Supplier.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      AnalyticsPerformance.setCachedValue('all_suppliers', suppliers, Duration(hours: 4));

      return suppliers;
    } catch (e) {
      developer.log('Error fetching suppliers: $e', error: e);
      rethrow;
    }
  }

  // Get single supplier
  Future<Supplier?> getSupplier(String supplierId) async {
    try {
      developer.log('Fetching supplier: $supplierId');

      final cached = AnalyticsPerformance.getCachedValue<Supplier>('supplier_$supplierId');
      if (cached != null) {
        return cached;
      }

      final doc = await _firestore
          .collection('$_collectionPrefix/suppliers')
          .doc(supplierId)
          .get();

      if (!doc.exists) return null;

      final supplier = Supplier.fromJson({...doc.data()!, 'id': doc.id});
      AnalyticsPerformance.setCachedValue('supplier_$supplierId', supplier, Duration(hours: 4));

      return supplier;
    } catch (e) {
      developer.log('Error fetching supplier: $e', error: e);
      rethrow;
    }
  }

  // Stream all suppliers
  Stream<List<Supplier>> streamAllSuppliers({bool activeOnly = true}) {
    developer.log('Streaming suppliers');

    var query = _firestore.collection('$_collectionPrefix/suppliers');

    if (activeOnly) {
      query = query.where('active', isEqualTo: true) as Query<Map<String, dynamic>>;
    }

    return query
        .orderBy('rating', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Supplier.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        })
        .handleError((e) {
          developer.log('Stream error for suppliers: $e', error: e);
        });
  }

  // Create new supplier
  Future<String> createSupplier({
    required String name,
    required String? contactPerson,
    required String? phone,
    required String? email,
    required String? address,
    required String? city,
    required int leadTimeDays,
    required String? paymentTerms,
  }) async {
    try {
      developer.log('Creating supplier: $name');

      final docRef = await _firestore.collection('$_collectionPrefix/suppliers').add({
        'name': name,
        'contact_person': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'lead_time_days': leadTimeDays,
        'payment_terms': paymentTerms,
        'rating': 0.0,
        'total_orders': 0,
        'on_time_delivery_rate': 0.0,
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      developer.log('Successfully created supplier: ${docRef.id}');
      _clearSupplierCache();

      return docRef.id;
    } catch (e) {
      developer.log('Error creating supplier: $e', error: e);
      rethrow;
    }
  }

  // Update supplier
  Future<void> updateSupplier(
    String supplierId, {
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    int? leadTimeDays,
    String? paymentTerms,
    bool? active,
  }) async {
    try {
      developer.log('Updating supplier: $supplierId');

      final updates = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (contactPerson != null) updates['contact_person'] = contactPerson;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (leadTimeDays != null) updates['lead_time_days'] = leadTimeDays;
      if (paymentTerms != null) updates['payment_terms'] = paymentTerms;
      if (active != null) updates['active'] = active;

      await _firestore
          .collection('$_collectionPrefix/suppliers')
          .doc(supplierId)
          .update(updates);

      developer.log('Successfully updated supplier: $supplierId');
      _clearSupplierCache(supplierId);
    } catch (e) {
      developer.log('Error updating supplier: $e', error: e);
      rethrow;
    }
  }

  // Update supplier rating
  Future<void> updateSupplierRating(String supplierId, double rating) async {
    try {
      developer.log('Updating supplier rating: $supplierId = $rating');

      if (rating < 0 || rating > 5) {
        throw Exception('Rating must be between 0 and 5');
      }

      await _firestore
          .collection('$_collectionPrefix/suppliers')
          .doc(supplierId)
          .update({
            'rating': rating,
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully updated supplier rating');
      _clearSupplierCache(supplierId);
    } catch (e) {
      developer.log('Error updating supplier rating: $e', error: e);
      rethrow;
    }
  }

  // Update on-time delivery rate
  Future<void> updateOnTimeDeliveryRate(String supplierId, double rate) async {
    try {
      developer.log('Updating on-time delivery rate: $supplierId = $rate%');

      if (rate < 0 || rate > 100) {
        throw Exception('Rate must be between 0 and 100');
      }

      await _firestore
          .collection('$_collectionPrefix/suppliers')
          .doc(supplierId)
          .update({
            'on_time_delivery_rate': rate,
            'updated_at': FieldValue.serverTimestamp(),
          });

      developer.log('Successfully updated on-time delivery rate');
      _clearSupplierCache(supplierId);
    } catch (e) {
      developer.log('Error updating on-time delivery rate: $e', error: e);
      rethrow;
    }
  }

  // Increment total orders
  Future<void> incrementOrderCount(String supplierId) async {
    try {
      developer.log('Incrementing order count for supplier: $supplierId');

      await _firestore
          .collection('$_collectionPrefix/suppliers')
          .doc(supplierId)
          .update({
            'total_orders': FieldValue.increment(1),
            'updated_at': FieldValue.serverTimestamp(),
          });

      _clearSupplierCache(supplierId);
    } catch (e) {
      developer.log('Error incrementing order count: $e', error: e);
      rethrow;
    }
  }

  // Get supplier performance metrics
  Future<Map<String, dynamic>> getPerformanceMetrics(String supplierId) async {
    try {
      developer.log('Fetching performance metrics for supplier: $supplierId');

      final supplier = await getSupplier(supplierId);
      if (supplier == null) {
        throw Exception('Supplier not found');
      }

      return {
        'supplier_id': supplierId,
        'supplier_name': supplier.name,
        'rating': supplier.rating,
        'rating_formatted': supplier.ratingFormatted,
        'on_time_delivery_rate': supplier.onTimeDeliveryRate,
        'on_time_formatted': supplier.onTimeFormatted,
        'total_orders': supplier.totalOrders,
        'active': supplier.active,
        'reliability_score': _calculateReliability(supplier),
      };
    } catch (e) {
      developer.log('Error fetching performance metrics: $e', error: e);
      rethrow;
    }
  }

  // Get suppliers sorted by performance
  Future<List<Supplier>> getSuppliersByPerformance() async {
    try {
      developer.log('Fetching suppliers sorted by performance');

      final suppliers = await getAllSuppliers();
      suppliers.sort((a, b) => b.rating.compareTo(a.rating));

      return suppliers;
    } catch (e) {
      developer.log('Error fetching suppliers by performance: $e', error: e);
      rethrow;
    }
  }

  // Search suppliers
  Future<List<Supplier>> searchSuppliers(String query) async {
    try {
      developer.log('Searching suppliers: $query');

      final allSuppliers = await getAllSuppliers();

      return allSuppliers
          .where((s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) ||
              (s.city?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (s.email?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    } catch (e) {
      developer.log('Error searching suppliers: $e', error: e);
      rethrow;
    }
  }

  // Get preferred suppliers for products
  Future<Map<String, String>> getPreferredSuppliersByProduct() async {
    try {
      developer.log('Fetching preferred suppliers by product');

      final cached = AnalyticsPerformance.getCachedValue<Map<String, String>>('preferred_suppliers');
      if (cached != null) {
        return cached;
      }

      final snapshot = await _firestore
          .collection('inventory/reorder_points')
          .where('preferred_supplier_id', isNotEqualTo: null)
          .get();

      final preferredMap = <String, String>{};

      for (final doc in snapshot.docs) {
        final productId = doc['product_id'] as String?;
        final supplierId = doc['preferred_supplier_id'] as String?;

        if (productId != null && supplierId != null) {
          preferredMap[productId] = supplierId;
        }
      }

      AnalyticsPerformance.setCachedValue('preferred_suppliers', preferredMap, Duration(hours: 2));

      return preferredMap;
    } catch (e) {
      developer.log('Error fetching preferred suppliers: $e', error: e);
      rethrow;
    }
  }

  // Calculate reliability score (combination of rating and on-time delivery)
  double _calculateReliability(Supplier supplier) {
    const ratingWeight = 0.4;
    const onTimeWeight = 0.6;

    final ratingScore = (supplier.rating / 5) * 100;
    final onTimeScore = supplier.onTimeDeliveryRate;

    return (ratingScore * ratingWeight) + (onTimeScore * onTimeWeight);
  }

  // Clear supplier cache
  void _clearSupplierCache([String? supplierId]) {
    developer.log('Clearing supplier cache' + (supplierId != null ? ': $supplierId' : ''));
    AnalyticsPerformance.clearCacheKey('all_suppliers');
    AnalyticsPerformance.clearCacheKey('preferred_suppliers');

    if (supplierId != null) {
      AnalyticsPerformance.clearCacheKey('supplier_$supplierId');
    }
  }
}
