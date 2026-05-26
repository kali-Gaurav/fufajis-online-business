import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_monitor.dart';

/// A wrapper widget that shows an offline indicator at the bottom
/// of the screen when the device loses network connection.
class OfflineIndicator extends StatelessWidget {
  final Widget child;

  const OfflineIndicator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NetworkMonitor(),
      child: Consumer<NetworkMonitor>(
        builder: (context, monitor, _) {
          return Stack(
            children: [
              child,
              if (monitor.isOffline)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    child: SafeArea(
                      top: false,
                      child: Container(
                        color: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'No internet connection. You are browsing offline.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
