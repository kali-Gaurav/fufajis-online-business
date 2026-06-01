import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'remote_config_service.dart';
import 'github_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final GitHubService _githubService = GitHubService();

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
      if (context.mounted) _showUpdateDialog(context, isForceUpdate: true);
      return false;
    }

    // 4. Check for Optional Update (Soft) via Remote Config
    // GitHub API check is now a secondary background check or deprecated for soft updates to avoid rate limits.
    final bool softUpdate = await _remoteConfig.isOptionalUpdateAvailable();
    if (softUpdate) {
      if (context.mounted) _showUpdateDialog(context, isForceUpdate: false);
      // Soft updates don't block navigation
      return true;
    }

    return true;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              : 'A new version is available with improved features and bug fixes. Would you like to update now?'
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              onPressed: () => _launchUpdateUrl(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
