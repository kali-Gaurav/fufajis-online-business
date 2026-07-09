import 'customer_profile.dart';
import 'customer_address.dart';
import 'customer_preferences.dart';

class ProfileResponse {
  final CustomerProfile profile;
  final List<CustomerAddress> addresses;
  final CustomerPreferences preferences;

  ProfileResponse({
    required this.profile,
    required this.addresses,
    required this.preferences,
  });

  factory ProfileResponse.fromJson(Map<String, dynamic> json) {
    return ProfileResponse(
      profile: CustomerProfile.fromJson(json['profile'] ?? {}),
      addresses: (json['addresses'] as List<dynamic>?)
              ?.map((e) => CustomerAddress.fromJson(e))
              .toList() ??
          [],
      preferences: CustomerPreferences.fromJson(json['preferences'] ?? {}),
    );
  }
}
