import 'package:flutter/material.dart';
import '../../services/device_security_service.dart';
import '../../services/security_event_service.dart';
import '../../providers/auth_provider.dart';

class ReauthenticationDialog extends StatefulWidget {
  final String actionDescription;

  const ReauthenticationDialog({super.key, required this.actionDescription});

  static Future<bool> show(BuildContext context, String actionDescription) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReauthenticationDialog(actionDescription: actionDescription),
    );
    return result ?? false;
  }

  @override
  _ReauthenticationDialogState createState() => _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<ReauthenticationDialog> {
  final TextEditingController _passwordController = TextEditingController();

  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await DeviceSecurityService.canCheckBiometrics();
    if (canCheck) {
      final success = await DeviceSecurityService.authenticateBiometrics(
        'Verify identity for ${widget.actionDescription}',
      );
      if (success) {
        _logSuccess('biometrics');
        if (mounted) Navigator.pop(context, true);
      }
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Please enter your PIN');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final authProvider = AuthProvider.instance;
    final email = authProvider.currentUser?.email;

    final isValid = await DeviceSecurityService.validatePinLocally(pin, email);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (isValid) {
      _logSuccess('pin');
      Navigator.pop(context, true);
    } else {
      _logFailure('pin');
      setState(() {
        _errorText = 'Invalid PIN. Please try again.';
        _pinController.clear();
      });

      final lockoutStatus = await DeviceSecurityService.getLockoutStatus();
      if (lockoutStatus.isLocked) {
        setState(
          () => _errorText =
              'Too many failed attempts. Locked for ${lockoutStatus.remainingMinutes} min.',
        );
      }
    }
  }

  void _logSuccess(String method) {
    SecurityEventService().logEvent(
      event: SecurityEventType.reauthenticationSuccess,
      userId: AuthProvider.instance.currentUser?.id ?? 'unknown',
      metadata: {'action': widget.actionDescription, 'method': method},
    );
  }

  void _logFailure(String method) {
    SecurityEventService().logEvent(
      event: SecurityEventType.reauthenticationFailed,
      userId: AuthProvider.instance.currentUser?.id ?? 'unknown',
      metadata: {'action': widget.actionDescription, 'method': method},
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Security Verification Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are about to ${widget.actionDescription}. Please verify your identity to continue.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Enter Security PIN',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
