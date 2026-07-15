// ============================================================
//  VerificationWallScreen — Triggered when a guest or unverified
//  customer tries a protected action (order, wallet, addresses,
//  rewards, order history).
//
//  FLOW:
//  1. User hits protected route while in guest / unverified state.
//  2. Router or widget calls: context.push('/auth/verify-wall',
//       extra: {'returnPath': '/customer/checkout'})
//  3. User picks Phone OTP or Google Sign-In.
//  4. On success: guest cart is migrated, returnPath is pushed.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guest_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/app_theme.dart';

class VerificationWallScreen extends StatefulWidget {
  /// Where to navigate after successful verification.
  final String returnPath;

  /// Human-readable reason shown to the user.
  final String? reason;

  const VerificationWallScreen({super.key, this.returnPath = '/customer/home', this.reason});

  @override
  State<VerificationWallScreen> createState() => _VerificationWallScreenState();
}

class _VerificationWallScreenState extends State<VerificationWallScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpComplete = false;
  int _resendTimer = 60;
  bool _canResend = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _otpController.addListener(() {
      final done = _otpController.text.length == 6;
      if (done != _otpComplete) setState(() => _otpComplete = done);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── OTP flow ───────────────────────────────────────────────
  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final phone = '+91${_phoneController.text.trim()}';
    await auth.sendOTP(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (auth.errorMessage == null) {
      setState(() {
        _otpSent = true;
        _resendTimer = 60;
        _canResend = false;
      });
      _startResendTimer();
    } else {
      _showError(auth.errorMessage!);
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOTP(_otpController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await _migrateAndProceed();
    } else {
      _showError(auth.errorMessage ?? 'Invalid OTP. Please try again.');
    }
  }

  // ── Google flow ────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await _migrateAndProceed();
    } else if (auth.errorMessage != null) {
      _showError(auth.errorMessage!);
    }
  }

  // ── Post-verification: migrate guest cart, route forward ───
  Future<void> _migrateAndProceed() async {
    final guest = Provider.of<GuestProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // 1. Pull out guest cart items before clearing
    if (guest.isGuestMode && guest.guestCart.isNotEmpty) {
      final guestItems = await guest.extractAndClearForMigration();
      // 2. Merge into verified customer's Firestore cart
      if (auth.currentUser != null) {
        await cart.migrateGuestCart(guestItems, auth.currentUser!.id);
      }
    }

    // 3. Exit guest mode
    await guest.exitGuestMode();

    if (!mounted) return;

    // 4. Navigate to the original destination
    context.go(widget.returnPath);
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
          _startResendTimer();
        } else {
          _canResend = true;
        }
      });
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.error));
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppTheme.grey800),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // ── Header ─────────────────────────────────
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      size: 44,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.grey900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.reason ??
                      'To place orders, track deliveries, and access your history, please verify your identity.',
                  style: TextStyle(fontSize: 14, color: isDark ? AppTheme.grey400 : AppTheme.grey600, height: 1.5),
                  textAlign: TextAlign.center,
                ),

                // ── Guest cart notice ───────────────────────
                Consumer<GuestProvider>(
                  builder: (_, guest, __) {
                    if (!guest.isGuestMode || guest.guestCartItemCount == 0) {
                      return const SizedBox(height: 28);
                    }
                    return Container(
                      margin: const EdgeInsets.only(top: 20, bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            color: AppTheme.warning,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${guest.guestCartItemCount} item(s) in your cart will be saved after verification.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // ── Google Sign-In ──────────────────────────
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 26, color: AppTheme.error),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.grey800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.grey300, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR',
                        style: TextStyle(color: isDark ? AppTheme.grey600 : AppTheme.grey400, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Phone OTP ───────────────────────────────
                if (!_otpSent) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mobile Number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.grey900,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                '+91',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTheme.grey300 : AppTheme.grey700,
                                ),
                              ),
                            ),
                            hintText: '00000 00000',
                            hintStyle: TextStyle(
                              color: isDark ? AppTheme.grey600 : AppTheme.grey400,
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2E) : AppTheme.grey50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF3A3A3C) : AppTheme.grey300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF3A3A3C) : AppTheme.grey300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primary,
                                width: 2.0,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.length != 10) ? 'Enter valid 10-digit number' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Get OTP',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ] else ...[
                  // ── OTP entry ─────────────────────────────
                  Text(
                    'OTP sent to +91 ${_phoneController.text}',
                    style: TextStyle(fontSize: 14, color: isDark ? AppTheme.grey400 : AppTheme.grey600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: isDark ? Colors.white : AppTheme.grey900,
                    ),
                    decoration: InputDecoration(
                      hintText: '------',
                      hintStyle: TextStyle(
                        color: isDark ? AppTheme.grey600 : AppTheme.grey400,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C2C2E) : AppTheme.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF3A3A3C) : AppTheme.grey300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF3A3A3C) : AppTheme.grey300,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.length == 6) _verifyOTP();
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: (_isLoading || !_otpComplete) ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _canResend
                        ? TextButton(
                            onPressed: () {
                              setState(() {
                                _otpSent = false;
                                _otpController.clear();
                              });
                            },
                            child: const Text(
                              'Change Number / Resend OTP',
                              style: TextStyle(color: AppTheme.primary),
                            ),
                          )
                        : Text(
                            'Resend in $_resendTimer s',
                            style: const TextStyle(color: AppTheme.grey500),
                          ),
                  ),
                ],

                const SizedBox(height: 40),
                const Text(
                  '🔒  Your data is encrypted and secure.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.grey400),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
