import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String? role;

  const OTPScreen({super.key, required this.phoneNumber, this.role});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
            _startResendTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  void _verifyOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isValid = await authProvider.verifyOTP(_otpController.text);

    if (isValid) {
      if (!mounted) return;
      
      // Feature: High-Security Owner MFA Check
      if (authProvider.isMfaStepRequired) {
        _showMfaLinkDialog(authProvider);
      } else {
        if (mounted) {
          context.go('/'); 
        }
      }
    } else {
      _showError('Invalid OTP. Please try again.');
    }
  }

  void _showMfaLinkDialog(AuthProvider auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Security Hardening'),
          ],
        ),
        content: const Text(
          'This phone number is registered as a Shop Owner. \n\n'
          'For business security, please link your Google Account to complete authorization.',
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final mfaSuccess = await auth.linkGoogleAccount();
              if (mfaSuccess && mounted) {
                Navigator.pop(context);
                context.go('/owner');
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Link Google Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _resendOTP() async {
    if (!_canResend) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.sendOTP(widget.phoneNumber);

    if (authProvider.errorMessage == null) {
      setState(() {
        _resendTimer = 60;
        _canResend = false;
        _otpController.clear();
      });
      _startResendTimer();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppTheme.grey900,
      ),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppTheme.error, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back, color: AppTheme.grey900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.sms_outlined,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'We sent a 6-digit code to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.grey600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // OTP Input
              Center(
                child: Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  keyboardType: TextInputType.number,
                  onCompleted: (value) {
                    if (value.length == 6) {
                      _verifyOTP();
                    }
                  },
                ),
              ),
              const SizedBox(height: 32),
              // Verify Button
              ElevatedButton(
                onPressed: _otpController.text.length == 6 ? _verifyOTP : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Resend OTP
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _resendOTP,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Text(
                        'Resend OTP in $_resendTimer seconds',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey500,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              // Didn't receive OTP
              TextButton(
                onPressed: () {},
                child: const Text(
                  "Didn't receive the code?",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
