// ============================================================
//  AuthScreen — Customer onboarding (Screen 3/4)
//
//  Design: Phone OTP authentication
//  - Phone number input with country code
//  - OTP verification via Firebase
//  - Email (optional)
//  - Display name
//  - Sign up flow
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isPhoneEntered = false;
  bool _isOtpSent = false;
  bool _isVerifying = false;
  bool _isSigningUp = false;
  String? _errorMessage;
  String? _successMessage;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runAnimations();
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut),
    );
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _fadeCtrl.forward();
  }

  void _onPhoneChanged() {
    setState(() {
      _isPhoneEntered = _phoneCtrl.text.length >= 10;
    });
  }

  Future<void> _sendOtp() async {
    if (!_isPhoneEntered) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // In a real app, integrate with Firebase
      // await FirebaseAuth.instance.verifyPhoneNumber(
      //   phoneNumber: '+91${_phoneCtrl.text}',
      //   verificationCompleted: (credential) async {
      //     await FirebaseAuth.instance.signInWithCredential(credential);
      //   },
      //   verificationFailed: (e) {
      //     setState(() => _errorMessage = e.message);
      //   },
      //   codeSent: (verificationId, forceResendingToken) {
      //     setState(() => _isOtpSent = true);
      //   },
      //   codeAutoRetrievalTimeout: (verificationId) {},
      // );

      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isOtpSent = true;
        _successMessage = 'OTP sent to +91${_phoneCtrl.text}';
        _resendCountdown = 60;
      });
      _startResendCountdown();
    } catch (e) {
      setState(() => _errorMessage = 'Error sending OTP: ${e.toString()}');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _resendCountdown--);
        if (_resendCountdown > 0) {
          _startResendCountdown();
        }
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // In a real app, verify with Firebase
      // final credential = PhoneAuthProvider.credential(
      //   verificationId: _verificationId,
      //   smsCode: _otpCtrl.text,
      // );
      // await FirebaseAuth.instance.signInWithCredential(credential);

      // Mock implementation
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isOtpSent = false;
        _successMessage = 'Phone verified! Now complete your profile';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Invalid OTP. Please try again.');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _completeSignup() async {
    if (_nameCtrl.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    setState(() {
      _isSigningUp = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // Create user profile
      await auth.updateUserProfile(
        name: _nameCtrl.text,
        email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
        phone: _phoneCtrl.text,
      );

      if (!mounted) return;
      _successMessage = 'Welcome to Fufaji!';

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        context.go('/onboarding/incentive');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error creating account: ${e.toString()}');
    } finally {
      setState(() => _isSigningUp = false);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: _fadeCtrl,
        builder: (context, _) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Progress indicator ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Title ────────────────────────────────────
                    Text(
                      _isOtpSent ? 'Enter OTP' : 'Phone Number',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isOtpSent
                          ? 'We\'ve sent a 6-digit code to your phone'
                          : 'Enter your phone number to sign up',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                    ),

                    const SizedBox(height: 32),

                    // ── Error message ────────────────────────────
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.red,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Success message ─────────────────────────
                    if (_successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.green,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Phone input section ──────────────────────
                    if (!_isOtpSent) ...[
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        enabled: !_isVerifying,
                        maxLength: 10,
                        decoration: InputDecoration(
                          prefixText: '+91 ',
                          hintText: 'Enter phone number',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B00),
                              width: 2,
                            ),
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isPhoneEntered && !_isVerifying
                              ? _sendOtp
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Send OTP',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                        ),
                      ),
                    ],

                    // ── OTP input section ────────────────────────
                    if (_isOtpSent) ...[
                      // OTP input fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => SizedBox(
                            width: 50,
                            height: 60,
                            child: TextField(
                              controller: _otpCtrl,
                              onChanged: (value) {
                                setState(() {});
                              },
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              enabled: !_isVerifying,
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1F1F1F)
                                    : const Color(0xFFF5F5F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFE0E0E0),
                                  ),
                                ),
                              ),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _otpCtrl.text.length == 6 && !_isVerifying
                              ? _verifyOtp
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Verify OTP',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: TextButton(
                          onPressed: _resendCountdown == 0 ? _sendOtp : null,
                          child: Text(
                            _resendCountdown > 0
                                ? 'Resend OTP in ${_resendCountdown}s'
                                : 'Resend OTP',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _resendCountdown > 0
                                      ? Colors.grey[500]
                                      : const Color(0xFFFF6B00),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ],

                    // ── Profile completion ───────────────────────
                    if (!_isOtpSent) ...[
                      const SizedBox(height: 32),
                      Text(
                        'Profile Details',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Your name',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B00),
                              width: 2,
                            ),
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email (optional)',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF6B00),
                              width: 2,
                            ),
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: !_isSigningUp ? _completeSignup : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSigningUp
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Create Account',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
