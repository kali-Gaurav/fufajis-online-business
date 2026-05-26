import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdService _instance = ShorebirdService._internal();
  factory ShorebirdService() => _instance;
  ShorebirdService._internal();

  final _shorebirdCodePush = ShorebirdCodePush();

  /// Check if a patch is available and download it in the background
  Future<void> checkForUpdates() async {
    try {
      final isShorebirdAvailable = _shorebirdCodePush.isShorebirdAvailable();
      if (!isShorebirdAvailable) {
        debugPrint('[Shorebird] Shorebird is not available.');
        return;
      }

      final isUpdateAvailable = await _shorebirdCodePush.isNewPatchAvailableForDownload();
      if (isUpdateAvailable) {
        debugPrint('[Shorebird] New patch available. Downloading...');
        await _shorebirdCodePush.downloadUpdateIfAvailable();
        debugPrint('[Shorebird] Patch downloaded. It will be applied on next app restart.');
      } else {
        debugPrint('[Shorebird] No new patches found.');
      }
    } catch (e) {
      debugPrint('[Shorebird] Error checking for updates: $e');
    }
  }

  /// Get current patch number
  Future<int?> getCurrentPatchNumber() async {
    try {
      return await _shorebirdCodePush.currentPatchNumber();
    } catch (e) {
      return null;
    }
  }
}
