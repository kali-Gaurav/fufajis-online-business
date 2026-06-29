import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/session_service.dart';
import '../utils/app_theme.dart';

/// Wraps the app shell and monitors for session inactivity.
///
/// Usage: Wrap your authenticated route body with this widget.
///
/// ```dart
/// SessionTimeoutOverlay(child: OwnerShell())
/// ```
///
/// The overlay shows a warning dialog at [warnAt] minutes before timeout,
/// then auto-signs-out when the timeout fires.
class SessionTimeoutOverlay extends StatefulWidget {
  final Widget child;

  /// How many seconds before expiry to show the warning.
  final int warnAtSecondsRemaining;

  const SessionTimeoutOverlay({
    super.key,
    required this.child,
    this.warnAtSecondsRemaining = 300, // 5 min warning
  });

  @override
  State<SessionTimeoutOverlay> createState() => SessionTimeoutOverlayState();
}

class SessionTimeoutOverlayState extends State<SessionTimeoutOverlay>
    with WidgetsBindingObserver {
  Timer? _checkTimer;
  DateTime _lastActivity = DateTime.now();
  bool _warningShown = false;
  bool _timedOut = false;

  static const Duration _timeout = SessionService.sessionTimeout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startChecking();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Treat returning to foreground as activity if not already timed out
    if (state == AppLifecycleState.resumed && !_timedOut) {
      _recordActivity();
    }
  }

  void _startChecking() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  void _check() {
    if (_timedOut || !mounted) return;

    final idle = DateTime.now().difference(_lastActivity);
    final remaining = _timeout - idle;

    if (remaining.isNegative) {
      _handleTimeout();
    } else if (remaining.inSeconds <= widget.warnAtSecondsRemaining &&
        !_warningShown) {
      _showWarning(remaining.inSeconds);
    }
  }

  /// Call this from any user interaction to reset the timer.
  void _recordActivity() {
    _lastActivity = DateTime.now();
    if (_warningShown) {
      setState(() => _warningShown = false);
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst || !_warningShown);
    }
  }

  void _showWarning(int secondsRemaining) {
    if (!mounted) return;
    setState(() => _warningShown = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TimeoutWarningDialog(
        secondsRemaining: secondsRemaining,
        onStayLoggedIn: () {
          setState(() => _warningShown = false);
          _lastActivity = DateTime.now();
          Navigator.of(ctx).pop();
        },
        onLogout: () {
          Navigator.of(ctx).pop();
          _handleTimeout();
        },
      ),
    );
  }

  Future<void> _handleTimeout() async {
    if (_timedOut || !mounted) return;
    setState(() => _timedOut = true);
    _checkTimer?.cancel();

    try {
      await context.read<AuthProvider>().logout();
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You were signed out due to inactivity.'),
          backgroundColor: AppTheme.warning,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _recordActivity,
      onPanDown: (_) => _recordActivity(),
      child: widget.child,
    );
  }
}

class _TimeoutWarningDialog extends StatefulWidget {
  final int secondsRemaining;
  final VoidCallback onStayLoggedIn;
  final VoidCallback onLogout;

  const _TimeoutWarningDialog({
    required this.secondsRemaining,
    required this.onStayLoggedIn,
    required this.onLogout,
  });

  @override
  State<_TimeoutWarningDialog> createState() => _TimeoutWarningDialogState();
}

class _TimeoutWarningDialogState extends State<_TimeoutWarningDialog> {
  late int _remaining;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _remaining = widget.secondsRemaining;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _countdown?.cancel();
        widget.onLogout();
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  String get _timeText {
    final mins = _remaining ~/ 60;
    final secs = _remaining % 60;
    if (mins > 0) return '$mins:${secs.toString().padLeft(2, '0')} minutes';
    return '$_remaining seconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timer_outlined, color: AppTheme.warning, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Session Expiring Soon', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You will be automatically signed out in',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _remaining < 60 ? AppTheme.error : AppTheme.warning,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _remaining < 60 ? AppTheme.error : AppTheme.warning,
              ),
            ),
            child: Text(
              _timeText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _remaining < 60 ? AppTheme.error : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap "Stay Signed In" to continue your session.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onLogout,
          child: const Text('Sign Out', style: TextStyle(color: AppTheme.grey600)),
        ),
        ElevatedButton(
          onPressed: widget.onStayLoggedIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Stay Signed In'),
        ),
      ],
    );
  }
}
