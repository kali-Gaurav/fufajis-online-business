import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/device_security_service.dart';
import '../../models/owner_model.dart';
import '../../utils/app_theme.dart';
import '../owner/dynamic_pricing_console.dart'; // Placeholder for dashboard
import 'package:pinput/pinput.dart';

class OwnerDailyLoginScreen extends StatefulWidget {
  final Owner owner;

  const OwnerDailyLoginScreen({super.key, required this.owner});

  @override
  _OwnerDailyLoginScreenState createState() => _OwnerDailyLoginScreenState();
}

class _OwnerDailyLoginScreenState extends State<OwnerDailyLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  Timer? _lockoutTimer;
  bool _isLockedOut = false;
  int _remainingLockMinutes = 0;

  @override
  void initState() {
    super.initState();
    _checkLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometrics();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final lockout = await DeviceSecurityService.getLockoutStatus();
    if (lockout.isLocked) {
      setState(() {
        _isLockedOut = true;
        _remainingLockMinutes = lockout.remainingMinutes;
        _error = 'Too many failed attempts. Device is locked for $_remainingLockMinutes minutes.';
        _pinController.clear();
      });
      _startLockoutTimer();
    } else {
      setState(() {
        _isLockedOut = false;
        _error = '';
      });
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      final lockout = await DeviceSecurityService.getLockoutStatus();
      if (lockout.isLocked) {
        if (mounted) {
          setState(() {
            _remainingLockMinutes = lockout.remainingMinutes;
            _error = 'Too many failed attempts. Device is locked for $_remainingLockMinutes minutes.';
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isLockedOut = false;
            _error = '';
          });
        }
      }
    });
  }

  Future<void> _checkBiometrics() async {
    final lockout = await DeviceSecurityService.getLockoutStatus();
    if (lockout.isLocked) return; // Prevent biometrics during lockout

    if (widget.owner.biometricEnabled) {
      bool success = await DeviceSecurityService.authenticateBiometrics("Log in to Owner Dashboard");
      if (success) {
        _navigateToDashboard();
      }
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DynamicPricingConsole()),
    );
  }

  Future<void> _verifyPin() async {
    if (_isLockedOut) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    bool isValid = await DeviceSecurityService.validatePinLocally(_pinController.text, widget.owner.email);
    
    setState(() {
      _isLoading = false;
    });

    if (isValid) {
      _navigateToDashboard();
    } else {
      final lockout = await DeviceSecurityService.getLockoutStatus();
      if (lockout.isLocked) {
        _checkLockout();
      } else {
        setState(() {
          _error = 'Invalid PIN. Please try again.';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: AppTheme.info),
              const SizedBox(height: 24),
              Text(
                'Welcome back, ${widget.owner.email}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              const Text('Enter your Security PIN', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Pinput(
                controller: _pinController,
                length: 6,
                obscureText: true,
                enabled: !_isLockedOut,
                onCompleted: (pin) => _verifyPin(),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _error, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w500)
                ),
              ],
              const SizedBox(height: 32),
              if (_isLoading) const CircularProgressIndicator(color: AppTheme.primary),
              if (!_isLoading && widget.owner.biometricEnabled && !_isLockedOut)
                TextButton.icon(
                  onPressed: _checkBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use Biometrics'),
                )
            ],
          ),
        ),
      ),
    );
  }
}
