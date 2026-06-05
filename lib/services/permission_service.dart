import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:connectivity_plus/connectivity_plus.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Requests critical permissions for the app (Step 5.1, 5.2)
  Future<void> requestAllPermissions() async {
    await _requestLocationPermission();
    await _requestNotificationPermission();
    await _requestBackgroundLocationPermission();
  }

  Future<bool> _requestLocationPermission() async {
    var status = await ph.Permission.location.request();
    return status.isGranted;
  }

  Future<bool> _requestBackgroundLocationPermission() async {
    // Only required for Delivery Agents (Step 5.1)
    var status = await ph.Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<bool> _requestNotificationPermission() async {
    // For Android 13+ (Step 5.2)
    var status = await ph.Permission.notification.request();
    return status.isGranted;
  }

  /// Checks current network status (Step 5.3)
  Future<bool> isNetworkConnected() async {
    final dynamic connectivityRes = await Connectivity().checkConnectivity();
    final List<ConnectivityResult> connectivityResult = (connectivityRes is List) 
        ? List<ConnectivityResult>.from(connectivityRes) 
        : [connectivityRes as ConnectivityResult];
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}
