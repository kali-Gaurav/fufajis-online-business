class CustomerProfile {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final String locale;
  final String timezone;
  final int profileCompletion;

  CustomerProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    this.locale = 'en',
    this.timezone = 'UTC',
    this.profileCompletion = 0,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.tryParse(json['date_of_birth']) : null,
      gender: json['gender'] as String?,
      locale: json['locale'] as String? ?? 'en',
      timezone: json['timezone'] as String? ?? 'UTC',
      profileCompletion: json['profile_completion'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'gender': gender,
      'locale': locale,
      'timezone': timezone,
    };
  }
}
