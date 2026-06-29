import 'package:flutter/foundation.dart';
import 'package:fufajis_online/models/user_model.dart';
import 'package:fufajis_online/models/address_model.dart';
import 'package:fufajis_online/models/preferences_model.dart';
import 'package:fufajis_online/services/user_data_service.dart';

/// User State Management Provider
///
/// Manages:
/// - Current user profile
/// - List of delivery addresses
/// - User preferences (theme, language)
/// - Loading states
/// - Error handling
///
/// Uses ChangeNotifier for efficient UI updates
class UserProvider with ChangeNotifier {
  final UserDataService _userDataService = UserDataService();

  // State
  UserModel? _currentUser;
  List<AddressModel> _addresses = [];
  PreferencesModel? _preferences;
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get currentUser => _currentUser;
  List<AddressModel> get addresses => _addresses;
  PreferencesModel? get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isAuthenticated => _currentUser != null;
  bool get hasAddresses => _addresses.isNotEmpty;

  AddressModel? get defaultAddress {
    try {
      return _addresses.firstWhere((a) => a.isDefault);
    } catch (e) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════════════════════════

  /// Load user profile and related data
  Future<void> loadUserData(String uid) async {
    try {
      _setLoading(true);
      _error = null;

      // Load profile
      final user = await _userDataService.loadUserProfile(uid);
      _currentUser = user;

      // Load addresses
      if (user != null) {
        _addresses = await _userDataService.getAddresses(uid);
      }

      // Load preferences
      final prefs = await _userDataService.loadPreferences(uid);
      _preferences = prefs;

      debugPrint('[UserProvider] User data loaded for: $uid');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint('[UserProvider] Error loading user data: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile with partial data
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      await _userDataService.updateUserProfile(_currentUser!.id, updates);

      // Update local state
      if (updates.containsKey('name')) {
        _currentUser = _currentUser!.copyWith(name: updates['name']?.toString());
      }
      if (updates.containsKey('email')) {
        _currentUser = _currentUser!.copyWith(email: updates['email'] as String?);
      }
      if (updates.containsKey('profileImage')) {
        _currentUser = _currentUser!.copyWith(profileImage: updates['profileImage'] as String?);
      }
      if (updates.containsKey('phoneNumber')) {
        _currentUser = _currentUser!.copyWith(phoneNumber: updates['phoneNumber'] as String?);
      }

      debugPrint('[UserProvider] Profile updated');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update profile: $e';
      debugPrint('[UserProvider] Error updating profile: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user name
  Future<void> updateName(String name) async {
    await updateProfile({'name': name});
  }

  /// Update user email
  Future<void> updateEmail(String email) async {
    await updateProfile({'email': email});
  }

  /// Update user phone
  Future<void> updatePhoneNumber(String phoneNumber) async {
    await updateProfile({'phoneNumber': phoneNumber});
  }

  /// Update profile image
  Future<void> updateProfileImage(String imageUrl) async {
    await updateProfile({'profileImage': imageUrl});
  }

  /// Watch user profile changes
  Stream<UserModel> watchUserProfile(String uid) {
    return _userDataService.watchUserProfile(uid).handleError((Object error) {
      _error = 'Error watching profile: $error';
      notifyListeners();
      throw error;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════

  /// Add a new delivery address
  Future<String> addNewAddress(AddressModel address) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      throw Exception('No user logged in');
    }

    try {
      _setLoading(true);
      _error = null;

      final addressId = await _userDataService.addAddress(_currentUser!.id, address);

      // Reload addresses
      _addresses = await _userDataService.getAddresses(_currentUser!.id);

      debugPrint('[UserProvider] Address added: $addressId');
      notifyListeners();

      return addressId;
    } catch (e) {
      _error = 'Failed to add address: $e';
      debugPrint('[UserProvider] Error adding address: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing address
  Future<void> updateExistingAddress(String addressId, AddressModel address) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      await _userDataService.updateAddress(
        _currentUser!.id,
        addressId,
        address,
      );

      // Reload addresses
      _addresses = await _userDataService.getAddresses(_currentUser!.id);

      debugPrint('[UserProvider] Address updated: $addressId');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update address: $e';
      debugPrint('[UserProvider] Error updating address: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete an address
  Future<void> deleteAddressById(String addressId) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      await _userDataService.deleteAddress(_currentUser!.id, addressId);

      // Remove from local list
      _addresses.removeWhere((a) => a.id == addressId);

      debugPrint('[UserProvider] Address deleted: $addressId');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete address: $e';
      debugPrint('[UserProvider] Error deleting address: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Set address as default
  Future<void> setDefaultAddress(String addressId) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      _setLoading(true);
      _error = null;

      // Mark all as non-default and set the selected one as default
      for (final address in _addresses) {
        await _userDataService.updateAddress(
          _currentUser!.id,
          address.id,
          address.copyWith(isDefault: address.id == addressId),
        );
      }

      // Reload addresses
      _addresses = await _userDataService.getAddresses(_currentUser!.id);

      debugPrint('[UserProvider] Default address set: $addressId');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to set default address: $e';
      debugPrint('[UserProvider] Error setting default address: $e');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Reload addresses from Firestore
  Future<void> reloadAddresses() async {
    if (_currentUser == null) return;

    try {
      _addresses = await _userDataService.getAddresses(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to reload addresses: $e';
      debugPrint('[UserProvider] Error reloading addresses: $e');
      notifyListeners();
    }
  }

  /// Watch address changes
  Stream<List<AddressModel>> watchAddresses(String uid) {
    return _userDataService.watchAddresses(uid).handleError((error) {
      _error = 'Error watching addresses: $error';
      notifyListeners();
      throw error as Object;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═══════════════════════════════════════════════════════════════

  /// Load preferences
  Future<void> loadPreferences(String uid) async {
    try {
      _preferences = await _userDataService.loadPreferences(uid);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load preferences: $e';
      debugPrint('[UserProvider] Error loading preferences: $e');
      notifyListeners();
    }
  }

  /// Update preferences
  Future<void> updatePreferencesModel(PreferencesModel prefs) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      await _userDataService.updatePreferences(_currentUser!.id, prefs);
      _preferences = prefs;
      debugPrint('[UserProvider] Preferences updated');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update preferences: $e';
      debugPrint('[UserProvider] Error updating preferences: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Update language
  Future<void> updateLanguage(String language) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      await _userDataService.updateLanguage(_currentUser!.id, language);
      _preferences = _preferences?.copyWith(language: language);
      debugPrint('[UserProvider] Language updated to: $language');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update language: $e';
      debugPrint('[UserProvider] Error updating language: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Update theme
  Future<void> updateTheme(ThemeMode theme) async {
    if (_currentUser == null) {
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    try {
      await _userDataService.updateTheme(_currentUser!.id, theme);
      _preferences = _preferences?.copyWith(theme: theme);
      debugPrint('[UserProvider] Theme updated to: $theme');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update theme: $e';
      debugPrint('[UserProvider] Error updating theme: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle notifications
  Future<void> toggleNotifications(bool enabled) async {
    if (_currentUser == null) return;
    try {
      final updated = _preferences?.copyWith(notificationsEnabled: enabled);
      if (updated != null) {
        await _userDataService.updatePreferences(_currentUser!.id, updated);
        _preferences = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[UserProvider] Error toggling notifications: $e');
    }
  }

  /// Watch preferences
  Stream<PreferencesModel> watchPreferences(String uid) {
    return _userDataService.watchPreferences(uid).handleError((error) {
      _error = 'Error watching preferences: $error';
      notifyListeners();
      throw error as Object;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════

  /// Clear all user data on logout
  void clearUserData() {
    _currentUser = null;
    _addresses = [];
    _preferences = null;
    _error = null;
    _isLoading = false;
    debugPrint('[UserProvider] User data cleared');
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  void _setLoading(bool value) {
    _isLoading = value;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
