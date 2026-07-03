import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/payment_method.dart';

/// Fast Checkout Preferences Service
/// Manages saved checkout preferences for customers to enable one-click checkout
class FastCheckoutPreferencesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'users';
  static const String _preferencesField = 'checkoutPreferences';

  /// Save checkout preferences after successful order
  /// Called after each successful checkout to enable faster next order
  Future<void> saveCheckoutPreferences({
    required String userId,
    required Address deliveryAddress,
    required PaymentMethod paymentMethod,
    bool autoConfirmOnNextOrder = true,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        '$_preferencesField.lastDeliveryAddress': {
          'street': deliveryAddress.street,
          'city': deliveryAddress.city,
          'state': deliveryAddress.state,
          'zipCode': deliveryAddress.zipCode,
          'fullAddress': deliveryAddress.fullAddress,
          'latitude': deliveryAddress.latitude,
          'longitude': deliveryAddress.longitude,
          'isDefault': deliveryAddress.isDefault,
          'label': deliveryAddress.label,
          'savedAt': FieldValue.serverTimestamp(),
        },
        '$_preferencesField.lastPaymentMethod': paymentMethod.toString().split('.').last,
        '$_preferencesField.autoConfirmOnNextOrder': autoConfirmOnNextOrder,
        '$_preferencesField.lastUpdatedAt': FieldValue.serverTimestamp(),
        '$_preferencesField.usageCount': FieldValue.increment(1),
      });

      print('✓ Checkout preferences saved for user $userId');
    } catch (e) {
      print('✗ Error saving checkout preferences: $e');
      rethrow;
    }
  }

  /// Load saved checkout preferences for fast checkout
  Future<Map<String, dynamic>?> loadCheckoutPreferences(String userId) async {
    try {
      final userDoc = await _firestore.collection(_collectionName).doc(userId).get();

      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data();
      if (data == null) return null;

      final prefs = data[_preferencesField] as Map<String, dynamic>?;

      if (prefs == null ||
          prefs['lastDeliveryAddress'] == null ||
          prefs['lastPaymentMethod'] == null) {
        return null;
      }

      // Reconstruct Address object
      final addressData = prefs['lastDeliveryAddress'] as Map<String, dynamic>;
      final savedAddress = Address(
        id: '',
        label: addressData['label'] as String? ?? 'Home',
        fullAddress: addressData['fullAddress'] as String? ?? '',
        street: addressData['street'] as String? ?? '',
        city: addressData['city'] as String? ?? '',
        state: addressData['state'] as String? ?? '',
        zipCode: addressData['zipCode'] as String? ?? '',
        latitude: (addressData['latitude'] as num? ?? 0.0).toDouble(),
        longitude: (addressData['longitude'] as num? ?? 0.0).toDouble(),
        isDefault: addressData['isDefault'] as bool? ?? false,
      );

      // Reconstruct PaymentMethod enum
      final paymentMethodStr = prefs['lastPaymentMethod'] as String?;
      PaymentMethod paymentMethod = PaymentMethod.cod;

      if (paymentMethodStr != null) {
        try {
          paymentMethod = PaymentMethod.values.firstWhere(
            (method) => method.toString().split('.').last == paymentMethodStr,
            orElse: () => PaymentMethod.cod,
          );
        } catch (e) {
          paymentMethod = PaymentMethod.cod;
        }
      }

      return {
        'lastDeliveryAddress': savedAddress,
        'lastPaymentMethod': paymentMethod,
        'autoConfirmOnNextOrder': prefs['autoConfirmOnNextOrder'] ?? true,
        'usageCount': prefs['usageCount'] ?? 1,
        'lastUpdatedAt': (prefs['lastUpdatedAt'] as Timestamp?)?.toDate(),
      };
    } catch (e) {
      print('✗ Error loading checkout preferences: $e');
      return null;
    }
  }

  /// Check if fast checkout is available for user
  Future<bool> isFastCheckoutAvailable(String userId) async {
    try {
      final prefs = await loadCheckoutPreferences(userId);
      if (prefs == null) return false;

      return (prefs['autoConfirmOnNextOrder'] as bool?) ?? false;
    } catch (e) {
      print('✗ Error checking fast checkout availability: $e');
      return false;
    }
  }

  /// Disable fast checkout for user (e.g., after address change preference)
  Future<void> disableFastCheckout(String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        '$_preferencesField.autoConfirmOnNextOrder': false,
      });

      print('✓ Fast checkout disabled for user $userId');
    } catch (e) {
      print('✗ Error disabling fast checkout: $e');
      rethrow;
    }
  }

  /// Update default payment method preference
  Future<void> setDefaultPaymentMethod(String userId, PaymentMethod method) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        '$_preferencesField.lastPaymentMethod': method.toString().split('.').last,
      });

      print('✓ Default payment method updated for user $userId');
    } catch (e) {
      print('✗ Error updating payment method: $e');
      rethrow;
    }
  }

  /// Update default delivery address
  Future<void> setDefaultDeliveryAddress(String userId, Address address) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        '$_preferencesField.lastDeliveryAddress': {
          'street': address.street,
          'city': address.city,
          'state': address.state,
          'zipCode': address.zipCode,
          'fullAddress': address.fullAddress,
          'latitude': address.latitude,
          'longitude': address.longitude,
          'isDefault': address.isDefault,
          'label': address.label,
          'savedAt': FieldValue.serverTimestamp(),
        },
      });

      print('✓ Default delivery address updated for user $userId');
    } catch (e) {
      print('✗ Error updating delivery address: $e');
      rethrow;
    }
  }

  /// Clear all checkout preferences
  Future<void> clearCheckoutPreferences(String userId) async {
    try {
      await _firestore.collection(_collectionName).doc(userId).update({
        _preferencesField: FieldValue.delete(),
      });

      print('✓ Checkout preferences cleared for user $userId');
    } catch (e) {
      print('✗ Error clearing checkout preferences: $e');
      rethrow;
    }
  }

  /// Get preference usage statistics
  Future<Map<String, dynamic>> getPreferenceStats(String userId) async {
    try {
      final prefs = await loadCheckoutPreferences(userId);
      if (prefs == null) {
        return {'hasPreferences': false, 'usageCount': 0, 'lastUsedAt': null};
      }

      return {
        'hasPreferences': true,
        'usageCount': prefs['usageCount'] ?? 0,
        'lastUsedAt': prefs['lastUpdatedAt'],
        'autoConfirm': prefs['autoConfirmOnNextOrder'],
      };
    } catch (e) {
      print('✗ Error getting preference stats: $e');
      return {'hasPreferences': false};
    }
  }
}
