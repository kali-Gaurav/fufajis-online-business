import '../../../services/api_client.dart';
import '../models/customer_address.dart';
import '../models/customer_preferences.dart';
import '../models/customer_profile.dart';
import '../models/profile_response.dart';

class ProfileApi {
  final ApiClient _apiClient = ApiClient.instance;

  Future<ProfileResponse> fetchProfile() async {
    final response = await _apiClient.get('/api/v1/profile');
    return ProfileResponse.fromJson(response.data);
  }

  Future<CustomerProfile> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiClient.patch('/api/v1/profile', data);
    return CustomerProfile.fromJson(response.data['profile']);
  }

  Future<CustomerAddress> addAddress(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/api/v1/profile/addresses', data);
    return CustomerAddress.fromJson(response.data['address']);
  }

  Future<CustomerAddress> updateAddress(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.patch('/api/v1/profile/addresses/$id', data);
    return CustomerAddress.fromJson(response.data['address']);
  }

  Future<void> deleteAddress(String id) async {
    await _apiClient.delete('/api/v1/profile/addresses/$id');
  }

  Future<CustomerPreferences> updatePreferences(Map<String, dynamic> data) async {
    final response = await _apiClient.patch('/api/v1/profile/preferences', data);
    return CustomerPreferences.fromJson(response.data['preferences']);
  }
}
