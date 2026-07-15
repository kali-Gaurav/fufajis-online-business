import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// OTP Verification Dialog for delivery completion
///
/// [Requirements 5.5]: Generates 4-digit OTP for delivery completion,
/// requires customer OTP for delivery verification, displays OTP to delivery agent,
/// and marks otpVerified when confirmed.
class OTPVerificationDialog extends StatefulWidget {
  final String orderNumber;
  final String otp;
  final VoidCallback onVerified;
  final VoidCallback? onCancel;

  const OTPVerificationDialog({
    super.key,
    required this.orderNumber,
    required this.otp,
    required this.onVerified,
    this.onCancel,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getEnteredOTP() {
    return _otpControllers.map((c) => c.text).join();
  }

  bool _isOTPComplete() {
    return _otpControllers.every((c) => c.text.isNotEmpty);
  }

  Future<void> _verifyOTP() async {
    if (!_isOTPComplete()) {
      setState(() {
        _errorMessage = 'Please enter all 4 digits';
      });
      return;
    }

    final enteredOTP = _getEnteredOTP();
    if (enteredOTP != widget.otp) {
      setState(() {
        _errorMessage = 'Incorrect OTP. Please try again.';
      });
      // Clear the fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    // Simulate verification delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
      widget.onVerified();
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.1),
              ),
              child: const Icon(Icons.verified_user, color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verify Delivery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900),
            ),
            const SizedBox(height: 8),
            Text(
              'Order #${widget.orderNumber}',
              style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 24),
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.info.withOpacity(0.3)),
              ),
              child: const Text(
                'Enter the 4-digit OTP provided by the delivery agent to complete the delivery',
                style: TextStyle(fontSize: 12, color: AppTheme.grey700),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 50,
                  height: 60,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    enabled: !_isVerifying,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.grey300, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.error, width: 2),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        if (index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else {
                          _focusNodes[index].unfocus();
                        }
                      }
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    onSubmitted: (_) {
                      if (_isOTPComplete()) {
                        _verifyOTP();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying
                        ? null
                        : () {
                            Navigator.pop(context);
                            widget.onCancel?.call();
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.grey300),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
