import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/models/address_model.dart';
import 'package:fufajis_online/models/preferences_model.dart';
import 'package:fufajis_online/services/local_storage_service.dart';

/// User Data Management Service
///
/// Handles all user profile operations:
/// - User profile CRUD
/// - Address management
/// - Preferences management
/// - Caching and offline support
/// - Network error handling
class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  static const String _usersCollection = 'users';
  static const String _addressesSubcollection = 'addresses';
  static const String _preferencesDoc = 'preferences';

  late StreamController<UserModel> _userController;
  late StreamController<List<AddressModel>> _addressesController;
  late StreamController<PreferencesModel> _preferencesController;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _userController = StreamController<UserModel>.broadcast();
    _addressesController = StreamController<List<AddressModel>>.broadcast();
    _preferencesController = StreamController<PreferencesModel>.broadcast();

    _initialized = true;
    debugPrint('[UserDataService] Initialized');
  }

  void dispose() {
    _userController.close();
    _addressesController.close();
    _preferencesController.close();
    debugPrint('[UserDataService] Disposed');
  }

  // ═══════════════════════════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════════════════════════

  /// Load user profile from Firestore with caching
  Future<UserModel?> loadUserProfile(String uid) async {
    try {
      debugPrint('[UserDataService] Loading profile for user: $uid');

      // Try to load from Firestore first
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (!doc.exists) {
        debugPrint('[UserDataService] User profile not found: $uid');
        return null;
      }

      final userData = doc.data() ?? {};
      final userModel = UserModel.fromMap(userData);

      // Cache the profile locally
      await _localStorage.saveToHive('profile', 'user_$uid', userModel.toMap());
      debugPrint('[UserDataService] Profile cached for: $uid');

      _userController.add(userModel);
      return userModel;
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error loading profile: ${e.message}');

      // Try to load from cache
      final cached = _localStorage.getFromHive('profile', 'user_$uid');
      if (cached != null) {
        debugPrint('[UserDataService] Using cached profile for: $uid');
        return UserModel.fromMap(cached as Map<String, dynamic>);
      }

      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error loading profile: $e');

      // Try to load from cache
      final cached = _localStorage.getFromHive('profile', 'user_$uid');
      if (cached != null) {
        debugPrint('[UserDataService] Using cached profile for: $uid');
        return UserModel.fromMap(cached as Map<String, dynamic>);
      }

      rethrow;
    }
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      debugPrint('[UserDataService] Updating profile for user: $uid');

      // Add updated timestamp
      updates['lastLogin'] = DateTime.now();

      await _firestore.collection(_usersCollection).doc(uid).update(updates);

      // Update cache
      final currentProfile = _localStorage.getFromHive('profile', 'user_$uid');
      if (currentProfile != null) {
        final updated = {...(currentProfile as Map), ...updates};
        await _localStorage.saveToHive('profile', 'user_$uid', updated);
      }

      // Reload and emit
      final updatedProfile = await loadUserProfile(uid);
      if (updatedProfile != null) {
        _userController.add(updatedProfile);
      }

      debugPrint('[UserDataService] Profile updated for: $uid');
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error updating profile: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error updating profile: $e');
      rethrow;
    }
  }

  /// Stream of user profile changes
  Stream<UserModel> watchUserProfile(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) throw Exception('User not found');
          return UserModel.fromMap(doc.data() ?? {});
        })
        .handleError((error) {
          debugPrint('[UserDataService] Error watching profile: $error');
          // Return cached profile on error
          final cached = _localStorage.getFromHive('profile', 'user_$uid');
          if (cached != null) {
            return UserModel.fromMap(cached as Map<String, dynamic>);
          }
          throw error as Object;
        });
  }

  // ═══════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════

  /// Add a new delivery address
  Future<String> addAddress(String uid, AddressModel address) async {
    try {
      debugPrint('[UserDataService] Adding address for user: $uid');

      final docRef = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_addressesSubcollection)
          .add(address.toFirestore());

      debugPrint('[UserDataService] Address added: ${docRef.id}');

      // Update cache
      final addresses = await getAddresses(uid);
      _addressesController.add(addresses);

      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error adding address: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error adding address: $e');
      rethrow;
    }
  }

  /// Update an existing address
  Future<void> updateAddress(
    String uid,
    String addressId,
    AddressModel address,
  ) async {
    try {
      debugPrint('[UserDataService] Updating address: $addressId for user: $uid');

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_addressesSubcollection)
          .doc(addressId)
          .update({
        ...address.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[UserDataService] Address updated: $addressId');

      // Update cache
      final addresses = await getAddresses(uid);
      _addressesController.add(addresses);
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error updating address: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error updating address: $e');
      rethrow;
    }
  }

  /// Delete an address
  Future<void> deleteAddress(String uid, String addressId) async {
    try {
      debugPrint('[UserDataService] Deleting address: $addressId for user: $uid');

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_addressesSubcollection)
          .doc(addressId)
          .delete();

      debugPrint('[UserDataService] Address deleted: $addressId');

      // Update cache
      final addresses = await getAddresses(uid);
      _addressesController.add(addresses);
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error deleting address: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error deleting address: $e');
      rethrow;
    }
  }

  /// Get all addresses for a user
  Future<List<AddressModel>> getAddresses(String uid) async {
    try {
      debugPrint('[UserDataService] Fetching addresses for user: $uid');

      final snapshot = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection(_addressesSubcollection)
          .orderBy('createdAt', descending: true)
          .get();

      final addresses = snapshot.docs
          .map((doc) => AddressModel.fromFirestore({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      // Cache addresses
      await _localStorage.saveToHive('profile', 'addresses_$uid',
        addresses.map((a) => a.toMap()).toList());

      debugPrint('[UserDataService] Fetched ${addresses.length} addresses');
      _addressesController.add(addresses);

      return addresses;
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error fetching addresses: ${e.message}');

      // Try cached version
      final cached = _localStorage.getFromHive('profile', 'addresses_$uid');
      if (cached != null && cached is List) {
        return cached
            .map((a) => AddressModel.fromFirestore({'id': (a as Map)['id'], ...Map<String, dynamic>.from(a)}))
            .toList();
      }

      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error fetching addresses: $e');

      // Try cached version
      final cached = _localStorage.getFromHive('profile', 'addresses_$uid');
      if (cached != null && cached is List) {
        return cached
            .map((a) => AddressModel.fromFirestore({'id': a['id'], ...(a as Map<String, dynamic>)}))
            .toList();
      }

      rethrow;
    }
  }

  /// Stream of address changes
  Stream<List<AddressModel>> watchAddresses(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_addressesSubcollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AddressModel.fromFirestore({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList())
        .handleError((error) {
          debugPrint('[UserDataService] Error watching addresses: $error');
          // Return cached addresses on error
          final cached = _localStorage.getFromHive('profile', 'addresses_$uid');
          if (cached != null && cached is List) {
            return cached
                .map((a) => AddressModel.fromFirestore({'id': (a as Map)['id'], ...Map<String, dynamic>.from(a)}))
                .toList();
          }
          throw error as Object;
        });
  }

  // ═══════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═══════════════════════════════════════════════════════════════

  /// Load user preferences
  Future<PreferencesModel> loadPreferences(String uid) async {
    try {
      debugPrint('[UserDataService] Loading preferences for user: $uid');

      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection('metadata')
          .doc(_preferencesDoc)
          .get();

      PreferencesModel preferences;

      if (doc.exists) {
        preferences = PreferencesModel.fromFirestore(doc.data() ?? {});
      } else {
        preferences = PreferencesModel.defaults();
      }

      // Cache preferences
      await _localStorage.saveToHive(
        'profile',
        'preferences_$uid',
        preferences.toMap(),
      );

      _preferencesController.add(preferences);
      return preferences;
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error loading preferences: ${e.message}');

      // Try cached version
      final cached = _localStorage.getFromHive('profile', 'preferences_$uid');
      if (cached != null) {
        return PreferencesModel.fromFirestore(cached as Map<String, dynamic>);
      }

      return PreferencesModel.defaults();
    } catch (e) {
      debugPrint('[UserDataService] Error loading preferences: $e');

      // Try cached version
      final cached = _localStorage.getFromHive('profile', 'preferences_$uid');
      if (cached != null) {
        return PreferencesModel.fromFirestore(cached as Map<String, dynamic>);
      }

      return PreferencesModel.defaults();
    }
  }

  /// Update user preferences
  Future<void> updatePreferences(
    String uid,
    PreferencesModel preferences,
  ) async {
    try {
      debugPrint('[UserDataService] Updating preferences for user: $uid');

      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .collection('metadata')
          .doc(_preferencesDoc)
          .set(
            {
              ...preferences.toFirestore(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

      // Cache preferences
      await _localStorage.saveToHive(
        'profile',
        'preferences_$uid',
        preferences.toMap(),
      );

      _preferencesController.add(preferences);
      debugPrint('[UserDataService] Preferences updated for: $uid');
    } on FirebaseException catch (e) {
      debugPrint('[UserDataService] Firebase error updating preferences: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UserDataService] Error updating preferences: $e');
      rethrow;
    }
  }

  /// Update language preference
  Future<void> updateLanguage(String uid, String language) async {
    try {
      final prefs = await loadPreferences(uid);
      final updated = prefs.copyWith(language: language);
      await updatePreferences(uid, updated);
      debugPrint('[UserDataService] Language updated to: $language');
    } catch (e) {
      debugPrint('[UserDataService] Error updating language: $e');
      rethrow;
    }
  }

  /// Update theme preference
  Future<void> updateTheme(String uid, ThemeMode theme) async {
    try {
      final prefs = await loadPreferences(uid);
      final updated = prefs.copyWith(theme: theme);
      await updatePreferences(uid, updated);
      debugPrint('[UserDataService] Theme updated to: $theme');
    } catch (e) {
      debugPrint('[UserDataService] Error updating theme: $e');
      rethrow;
    }
  }

  /// Stream of preference changes
  Stream<PreferencesModel> watchPreferences(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection('metadata')
        .doc(_preferencesDoc)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return PreferencesModel.fromFirestore(doc.data() ?? {});
          }
          return PreferencesModel.defaults();
        })
        .handleError((error) {
          debugPrint('[UserDataService] Error watching preferences: $error');
          // Return cached preferences on error
          final cached = _localStorage.getFromHive('profile', 'preferences_$uid');
          if (cached != null) {
            return PreferencesModel.fromFirestore(Map<String, dynamic>.from(cached as Map));
          }
          return PreferencesModel.defaults();
        });
  }

  // ═══════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════

  Stream<UserModel> get userStream => _userController.stream;
  Stream<List<AddressModel>> get addressesStream => _addressesController.stream;
  Stream<PreferencesModel> get preferencesStream => _preferencesController.stream;
}
