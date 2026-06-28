import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity
class NetworkMonitor extends ChangeNotifier {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  static NetworkMonitor get instance => _instance;
  NetworkMonitor._internal() {
    _initConnectivity();
    _connectivity.onConnectivityChanged.listen((dynamic result) {
      _updateConnectionStatus(result);
    });
  }

  final Connectivity _connectivity = Connectivity();
  bool _isOffline = false;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;

  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged.map((result) {
    return !result.contains(ConnectivityResult.none);
  });

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  void _updateConnectionStatus(dynamic result) {
    bool wasOffline = _isOffline;
    if (result is List) {
      _isOffline = result.isEmpty || result.contains(ConnectivityResult.none);
    } else {
      _isOffline = result == ConnectivityResult.none;
    }
    if (wasOffline != _isOffline) {
      notifyListeners();
    }
  }

  Future<void> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  @override
  void dispose() {
    // Note: Singleton dispose might not be desired, but keeping for compatibility
    super.dispose();
  }
}
