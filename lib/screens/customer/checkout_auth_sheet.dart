import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/otp_rate_limiter.dart';
import '../../utils/app_theme.dart';

class CheckoutAuthSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const CheckoutAuthSheet({super.key, required this.onSuccess});

  @override
  State<CheckoutAuthSheet> createState() => _CheckoutAuthSheetState();
}

class _CheckoutAuthSheetState extends State<CheckoutAuthSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final OtpRateLimiter _rateLimiter = OtpRateLimiter();

  bool _otpSent = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = "Enter a valid phone number");
      return;
    }

    // Check rate limit
    final status = await _rateLimiter.checkRateLimit();
    if (!status.allowed) {
      setState(
        () => _error = "Too many attempts. Try again in ${status.blockedUntilMinutes} minutes.",
      );
      return;
    }

    setState(() => _error = null);

    final formattedPhone = phone.startsWith('+') ? phone : '+91$phone';
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    await auth.sendOTPForCheckout(formattedPhone);
    await _rateLimiter.registerOtpAttempt();

    if (auth.errorMessage != null) {
      setState(() => _error = auth.errorMessage);
    } else {
      setState(() => _otpSent = true);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = "Enter a valid 6-digit OTP");
      return;
    }

    setState(() => _error = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final success = await auth.verifyOTPAndAutoCreateAccount(otp);

    if (success) {
      await _rateLimiter.resetLimits();
      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onSuccess(); // Continue checkout
      }
    } else {
      setState(() => _error = auth.errorMessage ?? "Invalid OTP");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Secure Checkout',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Login to continue with your purchase securely.',
            style: TextStyle(color: AppTheme.grey600),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ),
            const SizedBox(height: 16),
          ],

          if (!_otpSent) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Send OTP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: AppTheme.grey500)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      final success = await auth.signInWithGoogle();
                      if (success && mounted) {
                        Navigator.pop(context); // Close sheet
                        widget.onSuccess(); // Continue checkout
                      }
                    },
              icon: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                height: 24,
              ),
              label: const Text(
                'Continue with Google',
                style: TextStyle(color: AppTheme.grey900, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: AppTheme.grey300),
              ),
            ),
          ] else ...[
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Enter 6-digit OTP',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: auth.isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
