import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdService _instance = ShorebirdService._internal();
  factory ShorebirdService() => _instance;
  ShorebirdService._internal();

  final _shorebirdUpdater = ShorebirdUpdater();

  /// Check if a patch is available and download it in the background
  Future<void> checkForUpdates() async {
    try {
      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        debugPrint('[Shorebird] New patch available. Updating...');
        await _shorebirdUpdater.update();
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
      final patch = await _shorebirdUpdater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      return null;
    }
  }
}
