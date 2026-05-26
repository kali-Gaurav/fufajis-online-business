import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  Future<void> requestAllPermissions() async {
    await _requestLocationPermission();
    await _requestNotificationPermission();
  }

  Future<bool> _requestLocationPermission() async {
    var status = await ph.Permission.location.request();
    if (status.isGranted) {
      return true;
    } else {
      debugPrint('Location permission denied');
      return false;
    }
  }

  Future<bool> _requestNotificationPermission() async {
    // For Android 13+
    var status = await ph.Permission.notification.request();
    return status.isGranted;
  }
}
