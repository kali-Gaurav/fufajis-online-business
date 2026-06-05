import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'remote_config_service.dart';
import 'github_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/release_note_model.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final GitHubService _githubService = GitHubService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns true if the app can proceed to navigation, false if blocked by update/maintenance.
  Future<bool> handleVersionCheck(BuildContext context) async {
    // 1. Refresh config
    await _remoteConfig.fetchAndActivate();

    // 2. Check for Maintenance Mode
    if (_remoteConfig.isMaintenanceMode) {
      if (context.mounted) _showMaintenanceDialog(context);
      return false;
    }

    // 3. Check for Force Update (Mandatory)
    final bool forceUpdate = await _remoteConfig.isForceUpdateRequired();
    if (forceUpdate) {
      if (kReleaseMode) {
        // Try native In-App Update first in release mode
        try {
          AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            await InAppUpdate.performImmediateUpdate();
            return false;
          }
        } catch (e) {
          debugPrint('In-App Update failed: $e');
        }
      }
      
      if (context.mounted) _showUpdateDialog(context, isForceUpdate: true);
      return false;
    }

    // 4. Check for Optional Update (Soft) via Remote Config
    final bool softUpdate = await _remoteConfig.isOptionalUpdateAvailable();
    if (softUpdate) {
      if (kReleaseMode) {
        try {
          AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
            await InAppUpdate.startFlexibleUpdate();
            await InAppUpdate.completeFlexibleUpdate();
          }
        } catch (e) {
          debugPrint('Flexible In-App Update failed: $e');
        }
      }
      
      if (context.mounted) _showUpdateDialog(context, isForceUpdate: false);
      return true;
    }

    // 5. Check if we should show "What's New" for a recent update
    _checkAndShowWhatIsNew(context);

    return true;
  }

  /// Tracks the user's current version in Firestore for adoption metrics
  Future<void> trackUserVersion(String userId) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      await _db.collection('users').doc(userId).update({
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error tracking version: $e');
    }
  }

  /// Shows "What's New" dialog if the user has just updated
  Future<void> _checkAndShowWhatIsNew(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;
    final String? lastShownVersion = prefs.getString('last_shown_release_notes');

    if (lastShownVersion != currentVersion) {
      // Fetch release notes from Firestore
      final snap = await _db.collection('release_notes')
          .doc(currentVersion)
          .get();
      
      if (snap.exists && context.mounted) {
        final note = ReleaseNote.fromMap(snap.data()!);
        _showReleaseNotesDialog(context, note);
        await prefs.setString('last_shown_release_notes', currentVersion);
      }
    }
  }

  void _showReleaseNotesDialog(BuildContext context, ReleaseNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.celebration, color: Colors.orange, size: 40),
            const SizedBox(height: 10),
            Text('What\'s New in v${note.version}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...note.notes.map((n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(n)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  Future<bool> _isGitHubUpdateAvailable() async {
    final latestVersion = await _githubService.getLatestReleaseVersion();
    if (latestVersion == null) return false;

    final packageInfo = await PackageInfo.fromPlatform();
    return _isVersionLower(packageInfo.version, latestVersion);
  }

  bool _isVersionLower(String current, String target) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> targetParts = target.split('.').map(int.parse).toList();

      for (int i = 0; i < currentParts.length && i < targetParts.length; i++) {
        if (currentParts[i] < targetParts[i]) return true;
        if (currentParts[i] > targetParts[i]) return false;
      }
      if (targetParts.length > currentParts.length) return true;
    } catch (e) {
      debugPrint('Version comparison error: $e');
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, {required bool isForceUpdate}) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isForceUpdate ? Icons.system_update_alt : Icons.update,
                color: const Color(0xFFFF5722),
              ),
              const SizedBox(width: 12),
              Text(isForceUpdate ? 'Mandatory Update' : 'New Update Available'),
            ],
          ),
          content: Text(
            isForceUpdate
                ? 'This version of Fufaji\'s Online is no longer supported. Please update to continue.'
                : 'A new version is available with improved features and bug fixes. Would you like to update now?',
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ElevatedButton(
              onPressed: () => _launchUpdateUrl(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.construction, color: Colors.orange),
              SizedBox(width: 12),
              Text('System Upgrade'),
            ],
          ),
          content: Text(_remoteConfig.maintenanceMessage),
          actions: [
            TextButton(
              onPressed: () async {
                final proceed = await handleVersionCheck(context);
                if (proceed && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpdateUrl() async {
    // 1. Try Remote Config URL first (e.g. your own website)
    String urlStr = _remoteConfig.forceUpdateUrl;

    // 2. Fallback to Play Store if URL is default or empty
    if (urlStr.contains('fufaji-online.com/download') || urlStr.isEmpty) {
      const String packageName = 'com.fufajis.online';
      urlStr = 'https://play.google.com/store/apps/details?id=$packageName';
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
