class CustomerPreferences {
  final String id;
  final String language;
  final String currency;
  final String theme;
  final bool notificationsEnabled;
  final bool marketingOptIn;
  final bool voiceSearchEnabled;
  final String? preferredStore;

  CustomerPreferences({
    required this.id,
    this.language = 'en',
    this.currency = 'INR',
    this.theme = 'system',
    this.notificationsEnabled = true,
    this.marketingOptIn = false,
    this.voiceSearchEnabled = true,
    this.preferredStore,
  });

  factory CustomerPreferences.fromJson(Map<String, dynamic> json) {
    return CustomerPreferences(
      id: json['id'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'INR',
      theme: json['theme'] as String? ?? 'system',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      voiceSearchEnabled: json['voice_search_enabled'] as bool? ?? true,
      preferredStore: json['preferred_store'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'currency': currency,
      'theme': theme,
      'notifications_enabled': notificationsEnabled,
      'marketing_opt_in': marketingOptIn,
      'voice_search_enabled': voiceSearchEnabled,
      'preferred_store': preferredStore,
    };
  }
}
