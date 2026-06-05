import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity
class NetworkMonitor extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  NetworkMonitor() {
    _initConnectivity();
    // Use dynamic to handle both ConnectivityResult (older API) and List<ConnectivityResult> (newer API)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      dynamic result,
    ) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _initConnectivity() async {
    try {
      final dynamic result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Could not check connectivity status: $e');
    }
  }

  void _updateConnectionStatus(dynamic result) {
    bool wasOffline = _isOffline;

    if (result is List) {
      // Handle newer List<ConnectivityResult> API
      _isOffline = result.contains(ConnectivityResult.none);
    } else if (result is ConnectivityResult) {
      // Handle older ConnectivityResult API
      _isOffline = result == ConnectivityResult.none;
    }

    if (wasOffline != _isOffline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
