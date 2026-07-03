import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class PhoneVerifyScreen extends StatefulWidget {
  final String phoneNumber;
  final String? role;

  const PhoneVerifyScreen({super.key, required this.phoneNumber, this.role});

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  late TextEditingController _pinController;
  late FocusNode _pinFocusNode;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _pinFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  // Centralised role→route mapping (mirrors SplashScreen + OTPScreen)
  String _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.owner:
      case UserRole.shopOwner:
      case UserRole.branchManager:
      case UserRole.franchiseOwner:
        return '/owner';
      case UserRole.superAdmin:
      case UserRole.admin:
        return '/admin';
      case UserRole.rider:
      case UserRole.deliveryAgent:
      case UserRole.dispatcher:
        return '/delivery';
      case UserRole.employee:
      case UserRole.supplier:
        return '/employee';
      case UserRole.customer:
        return '/customer/home';
    }
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_resendCountdown > 0) {
            _resendCountdown--;
            _startResendTimer();
          }
        });
      }
    });
  }

  Future<void> _handleVerifyOTP() async {
    final otp = _pinController.text;

    if (otp.isEmpty || otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a valid 6-digit OTP')));
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();

      // Parse the role from the query param so it can be applied during verify
      UserRole? parsedRole;
      if (widget.role != null) {
        parsedRole = UserRole.values.firstWhere(
          (e) => e.name == widget.role,
          orElse: () => UserRole.customer,
        );
      }

      final success = await authProvider.verifyPhoneOTP(otp);

      if (success && mounted) {
        // Route directly to the appropriate dashboard — no splash re-init
        final user = authProvider.currentUser;
        final role = user?.role ?? parsedRole ?? UserRole.customer;
        context.go(_routeForRole(role));
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid OTP. Please try again.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _handleResendOTP() async {
    if (_resendCountdown > 0) return;

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.sendOTP(widget.phoneNumber);
      _startResendTimer();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('OTP resent successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: Theme.of(context).textTheme.headlineSmall,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).primaryColor),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(color: Colors.grey[100]),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone Number'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Text(
              'Enter verification code',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a code to ${widget.phoneNumber}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Pinput(
              length: 6,
              controller: _pinController,
              focusNode: _pinFocusNode,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) => _handleVerifyOTP(),
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleVerifyOTP,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.errorMessage != null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      authProvider.errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't receive the code? "),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return TextButton(
                      onPressed: _resendCountdown == 0 ? _handleResendOTP : null,
                      child: _resendCountdown == 0
                          ? const Text('Resend')
                          : Text('Resend in ${_resendCountdown}s'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
