// ============================================================
//  NetworkErrorScreen — Redesigned Offline/No-Internet Screen
//  Upgraded to PopScope, features a pulsing WiFi icon,
//  staggered details, and a modern connection monitor state.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/app_theme.dart';
import '../services/network_monitor.dart';
import '../widgets/animated_widgets.dart';

class NetworkErrorScreen extends StatefulWidget {
  const NetworkErrorScreen({super.key});

  @override
  State<NetworkErrorScreen> createState() => _NetworkErrorScreenState();
}

class _NetworkErrorScreenState extends State<NetworkErrorScreen> {
  late NetworkMonitor _networkMonitor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _networkMonitor = NetworkMonitor.instance;
    _networkMonitor.addListener(_onNetworkStatusChanged);
  }

  @override
  void dispose() {
    _networkMonitor.removeListener(_onNetworkStatusChanged);
    super.dispose();
  }

  void _onNetworkStatusChanged() {
    if (_networkMonitor.isOnline) {
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    final subTextColor = isDark ? Colors.white70 : AppTheme.grey600;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
        appBar: AppBar(
          title: const Text('No Connection', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing Wi-Fi Off Icon
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  child: PulseGlow(
                    glowColor: AppTheme.primary.withValues(alpha: 0.2),
                    maxRadius: 16,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.grey800 : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12),
                        ],
                      ),
                      child: const Icon(Icons.wifi_off_rounded, size: 64, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error Title
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'No Internet Connection',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Error Description
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    'Please check your internet connection and try again. '
                    'You can also use offline mode to browse cached data.',
                    style: TextStyle(fontSize: 16, color: subTextColor, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Retry Button with loading spinner
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity,
                    child: ScaleBounce(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              await _networkMonitor.checkConnectivity();
                              await Future.delayed(const Duration(milliseconds: 800));
                              if (mounted) setState(() => _isLoading = false);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Try Again',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Offline Mode Button
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: double.infinity,
                    child: ScaleBounce(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Offline mode enabled. Viewing cached data.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        context.pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                          border: Border.all(color: isDark ? AppTheme.grey800 : AppTheme.grey200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Use Offline Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Connection Tips Card
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2C) : AppTheme.grey200,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Troubleshooting Tips:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTip('Check WiFi or cellular connection', subTextColor),
                        const SizedBox(height: 8),
                        _buildTip('Restart your router or device', subTextColor),
                        const SizedBox(height: 8),
                        _buildTip('Try disabling WiFi and use mobile data', subTextColor),
                        const SizedBox(height: 8),
                        _buildTip('Check if airplane mode is enabled', subTextColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Live Connection Status Monitor Banner
                FadeSlideIn(
                  duration: AppTheme.durationMedium,
                  delay: const Duration(milliseconds: 350),
                  child: StreamBuilder<bool>(
                    stream: _networkMonitor.onConnectivityChanged,
                    builder: (context, snapshot) {
                      final isOnline = snapshot.data ?? false;
                      final bannerColor = isOnline ? AppTheme.success : AppTheme.error;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: bannerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated connection state dot
                            PulseGlow(
                              glowColor: bannerColor.withValues(alpha: 0.25),
                              maxRadius: 4,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: bannerColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isOnline ? 'Connection Restored' : 'Offline - Monitoring...',
                              style: TextStyle(
                                color: bannerColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTip(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: TextStyle(fontSize: 16, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13)),
        ),
      ],
    );
  }
}
