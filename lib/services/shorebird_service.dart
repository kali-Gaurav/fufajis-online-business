import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:flutter/foundation.dart';
import 'logging_service.dart';

class ShorebirdService {
  static final ShorebirdService _instance = ShorebirdService._internal();
  factory ShorebirdService() => _instance;
  ShorebirdService._internal();

  final _shorebirdUpdater = ShorebirdUpdater();
  bool _updateChecked = false;

  /// Check if a patch is available and download it in the background
  Future<void> checkForUpdates() async {
    // Shorebird is only available in release builds and on supported platforms.
    if (kDebugMode) {
      return;
    }

    try {
      // Only check once per session to avoid redundant logs
      if (_updateChecked) return;
      _updateChecked = true;

      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        LoggingService().info('[Shorebird] New patch available. Updating...');
        await _shorebirdUpdater.update();
        LoggingService().info(
          '[Shorebird] Patch downloaded. It will be applied on next app restart.',
        );
      } else {
        LoggingService().info('[Shorebird] No new patches found.');
      }
    } catch (e, stack) {
      LoggingService().error('[Shorebird] Error checking for updates', e, stack);
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
