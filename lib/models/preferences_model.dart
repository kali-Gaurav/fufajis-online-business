import 'package:cloud_firestore/cloud_firestore.dart';

enum ThemeMode { light, dark, system }

class PreferencesModel {
  final String language; // 'en', 'hi'
  final ThemeMode theme; // light, dark, system
  final bool notificationsEnabled;
  final bool biometricEnabled;
  final bool pinEnabled;
  final List<String> mutedCategories; // Category IDs for which notifications are disabled
  final bool marketingEmails;
  final bool orderUpdates;
  final bool promotions;
  final DateTime updatedAt;

  PreferencesModel({
    this.language = 'en',
    this.theme = ThemeMode.system,
    this.notificationsEnabled = true,
    this.biometricEnabled = false,
    this.pinEnabled = false,
    this.mutedCategories = const [],
    this.marketingEmails = true,
    this.orderUpdates = true,
    this.promotions = true,
    required this.updatedAt,
  });

  /// Parse DateTime from various sources
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  factory PreferencesModel.fromFirestore(Map<String, dynamic> map) {
    return PreferencesModel(
      language: map['language'] as String? ?? 'en',
      theme: ThemeMode.values.firstWhere(
        (e) => e.toString() == map['theme'] as String?,
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      biometricEnabled: map['biometricEnabled'] as bool? ?? false,
      pinEnabled: map['pinEnabled'] as bool? ?? false,
      mutedCategories: List<String>.from(map['mutedCategories'] as Iterable? ?? []),
      marketingEmails: map['marketingEmails'] as bool? ?? true,
      orderUpdates: map['orderUpdates'] as bool? ?? true,
      promotions: map['promotions'] as bool? ?? true,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  factory PreferencesModel.fromMap(Map<String, dynamic> map) {
    return PreferencesModel.fromFirestore(map);
  }

  /// Default preferences for new users
  factory PreferencesModel.defaults() {
    return PreferencesModel(
      language: 'en',
      theme: ThemeMode.system,
      notificationsEnabled: true,
      biometricEnabled: false,
      pinEnabled: false,
      mutedCategories: const [],
      marketingEmails: true,
      orderUpdates: true,
      promotions: true,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'language': language,
      'theme': theme.toString(),
      'notificationsEnabled': notificationsEnabled,
      'biometricEnabled': biometricEnabled,
      'pinEnabled': pinEnabled,
      'mutedCategories': mutedCategories,
      'marketingEmails': marketingEmails,
      'orderUpdates': orderUpdates,
      'promotions': promotions,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  PreferencesModel copyWith({
    String? language,
    ThemeMode? theme,
    bool? notificationsEnabled,
    bool? biometricEnabled,
    bool? pinEnabled,
    List<String>? mutedCategories,
    bool? marketingEmails,
    bool? orderUpdates,
    bool? promotions,
    DateTime? updatedAt,
  }) {
    return PreferencesModel(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      mutedCategories: mutedCategories ?? this.mutedCategories,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PreferencesModel(language: $language, theme: $theme, notifications: $notificationsEnabled)';
  }
}
