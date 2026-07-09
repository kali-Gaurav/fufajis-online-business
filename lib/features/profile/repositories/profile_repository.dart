import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_response.dart';
import '../services/profile_api.dart';

class ProfileRepository {
  final ProfileApi _api = ProfileApi();
  static const String _cacheKey = 'profile_data_cache';

  /// Fetches the profile. Emits cached data first (if available),
  /// then fetches fresh data from the server.
  Stream<ProfileResponse> getProfileStream() async* {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Emit cache immediately if it exists
    final cachedData = prefs.getString(_cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        yield ProfileResponse.fromJson(json);
      } catch (e) {
        debugPrint('[ProfileRepository] Failed to parse cache: $e');
      }
    }

    // 2. Fetch fresh data from network
    try {
      final freshProfile = await _api.fetchProfile();
      
      // Update cache
      final jsonString = jsonEncode({
        'profile': freshProfile.profile.toJson(),
        'addresses': freshProfile.addresses.map((a) => a.toJson()).toList(),
        'preferences': freshProfile.preferences.toJson(),
      });
      await prefs.setString(_cacheKey, jsonString);
      
      // Emit fresh data
      yield freshProfile;
    } catch (e) {
      debugPrint('[ProfileRepository] Failed to fetch fresh profile: $e');
      if (cachedData == null) {
        rethrow; // Only throw if we don't have cache to fall back on
      }
    }
  }

  // Pass-through mutation methods (let providers handle state updates)
  Future<void> updateProfile(Map<String, dynamic> data) => _api.updateProfile(data);
  Future<void> addAddress(Map<String, dynamic> data) => _api.addAddress(data);
  Future<void> updateAddress(String id, Map<String, dynamic> data) => _api.updateAddress(id, data);
  Future<void> deleteAddress(String id) => _api.deleteAddress(id);
  Future<void> updatePreferences(Map<String, dynamic> data) => _api.updatePreferences(data);
}
