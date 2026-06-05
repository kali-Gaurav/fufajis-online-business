import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Keys
  static const String keyMinAppVersion = 'min_app_version';
  static const String keyLatestAppVersion = 'latest_app_version';
  static const String keyForceUpdateUrl = 'force_update_url';
  static const String keyMaintenanceMode = 'is_maintenance_mode';
  static const String keyMaintenanceMessage = 'maintenance_message';
  static const String keyFestivalMode = 'festival_mode';
  static const String keySupportPhone = 'support_phone';
  static const String keyShowAds = 'show_ads';
  static const String keyFeatureNewCheckout = 'feature_new_checkout';
  static const String keyAnnouncementTitle = 'announcement_title';
  static const String keyAnnouncementMsg = 'announcement_message';
  static const String keyAnnouncementLink = 'announcement_link';
  static const String keyShowAnnouncement = 'show_announcement';
  static const String keyLatestApkUrl = 'latest_apk_url';
  static const String keyLatestBuildNumber = 'latest_build_number';

  Future<void> init() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          // Development optimization: 0 seconds for instant testing
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(minutes: 15),
        ),
      );

      // Standardizing defaults
      await _remoteConfig.setDefaults({
        keyMinAppVersion: '1.0.0',
        keyLatestAppVersion: '1.0.0',
        keyLatestBuildNumber: 0,
        keyLatestApkUrl: '',
        keyForceUpdateUrl:
            'https://play.google.com/store/apps/details?id=com.fufajis.online',
        keyMaintenanceMode: false,
        keyMaintenanceMessage:
            'We are currently updating our systems to serve you better. Please check back soon.',
        keyFestivalMode: 'none',
        keySupportPhone: '+919999999999',
        keyShowAds: true,
        keyFeatureNewCheckout: false,
        keyAnnouncementTitle: 'Update Available!',
        keyAnnouncementMsg: 'New version of Fufaji is live. Update for better speed!',
        keyAnnouncementLink: '',
        keyShowAnnouncement: false,
      });

      await fetchAndActivate();

      // Log initialization to Analytics
      await _analytics.logEvent(name: 'remote_config_initialized');
    } catch (e) {
      debugPrint('Remote Config Initialization Failed: $e');
    }
  }

  Future<void> fetchAndActivate() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote Config Fetch Failed: $e');
    }
  }

  // Getters
  String get minAppVersion => _remoteConfig.getString(keyMinAppVersion);
  String get latestAppVersion => _remoteConfig.getString(keyLatestAppVersion);
  String get forceUpdateUrl => _remoteConfig.getString(keyForceUpdateUrl);
  bool get isMaintenanceMode => _remoteConfig.getBool(keyMaintenanceMode);
  String get maintenanceMessage =>
      _remoteConfig.getString(keyMaintenanceMessage);
  String get festivalMode => _remoteConfig.getString(keyFestivalMode);
  String get supportPhone => _remoteConfig.getString(keySupportPhone);
  bool get showAds => _remoteConfig.getBool(keyShowAds);
  bool get featureNewCheckout => _remoteConfig.getBool(keyFeatureNewCheckout);
  String get announcementTitle => _remoteConfig.getString(keyAnnouncementTitle);
  String get announcementMsg => _remoteConfig.getString(keyAnnouncementMsg);
  String get announcementLink => _remoteConfig.getString(keyAnnouncementLink);
  bool get showAnnouncement => _remoteConfig.getBool(keyShowAnnouncement);
  String get latestApkUrl => _remoteConfig.getString(keyLatestApkUrl);
  int get latestBuildNumber => _remoteConfig.getInt(keyLatestBuildNumber);

  /// Checks if a mandatory update is required.
  Future<bool> isForceUpdateRequired() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return _isVersionLower(packageInfo.version, minAppVersion);
  }

  /// Alias for compatibility
  Future<bool> isUpdateRequired() => isForceUpdateRequired();

  /// Checks if an optional update is available.
  Future<bool> isOptionalUpdateAvailable() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return _isVersionLower(packageInfo.version, latestAppVersion);
  }

  bool _isVersionLower(String current, String target) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> targetParts = target.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < targetParts[i]) return true;
        if (currentParts[i] > targetParts[i]) return false;
      }
    } catch (e) {
      debugPrint('Version comparison error: $e');
    }
    return false;
  }
}
