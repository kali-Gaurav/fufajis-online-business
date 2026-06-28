import 'package:flutter/material.dart';
import '../../services/owner_auth_service.dart';
import '../../models/owner_model.dart';
import 'package:pinput/pinput.dart';
import '../../services/device_security_service.dart';
import '../../utils/app_theme.dart';
import 'owner_daily_login_screen.dart';

class OwnerFirstLoginScreen extends StatefulWidget {
  final Owner owner;

  const OwnerFirstLoginScreen({super.key, required this.owner});

  @override
  _OwnerFirstLoginScreenState createState() => _OwnerFirstLoginScreenState();
}

class _OwnerFirstLoginScreenState extends State<OwnerFirstLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  int _step = 0; // 0: Register Device, 1: Create PIN, 2: Enable Biometrics
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricsSupport();
  }

  Future<void> _checkBiometricsSupport() async {
    bool supported = await DeviceSecurityService.canCheckBiometrics();
    if (mounted) {
      setState(() => _canCheckBiometrics = supported);
    }
  }

  Future<void> _registerDevice() async {
    setState(() => _isLoading = true);
    await OwnerAuthService.registerDevice(widget.owner.email, true);
    setState(() {
      _isLoading = false;
      _step = 1;
    });
  }

  Future<void> _finishSetup(bool enableBiometrics) async {
    setState(() => _isLoading = true);
    String pinHash = await OwnerAuthService.setupFirstLogin(
      widget.owner.email,
      _pinController.text,
      enableBiometrics,
    );
    setState(() => _isLoading = false);

    // Navigate to daily login
    Owner updatedOwner = widget.owner.copyWith(
      biometricEnabled: enableBiometrics,
      pinHash: pinHash,
    );
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OwnerDailyLoginScreen(owner: updatedOwner)),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Time Setup')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step == 0) ...[
                const Icon(Icons.devices, size: 64, color: AppTheme.info),
                const SizedBox(height: 24),
                const Text(
                  'Register This Device',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'To ensure security, this device needs to be registered as an authorized owner device.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const CircularProgressIndicator(color: AppTheme.primary)
                else
                  ElevatedButton(
                    onPressed: _registerDevice,
                    child: const Text('Register Device'),
                  ),
              ] else if (_step == 1) ...[
                const Icon(Icons.password, size: 64, color: AppTheme.info),
                const SizedBox(height: 24),
                const Text(
                  'Create Security PIN',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Create a 6-digit PIN for daily login.'),
                const SizedBox(height: 24),
                Pinput(
                  controller: _pinController,
                  length: 6,
                  obscureText: true,
                  onCompleted: (pin) {
                    setState(() {
                      _step = 2;
                    });
                  },
                ),
              ] else if (_step == 2) ...[
                const Icon(Icons.fingerprint, size: 64, color: AppTheme.info),
                const SizedBox(height: 24),
                const Text(
                  'Enable Biometrics',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_canCheckBiometrics) ...[
                  const Text('Would you like to use FaceID/TouchID for faster login?'),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator(color: AppTheme.primary)
                  else ...[
                    ElevatedButton(
                      onPressed: () => _finishSetup(true),
                      child: const Text('Enable Biometrics'),
                    ),
                    TextButton(
                      onPressed: () => _finishSetup(false),
                      child: const Text('Skip for now'),
                    )
                  ]
                ] else ...[
                  const Text('Biometrics are not supported on this device.'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _finishSetup(false),
                    child: const Text('Complete Setup'),
                  ),
                ]
              ]
            ],
          ),
        ),
      ),
    );
  }
}
