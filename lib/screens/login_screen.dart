// ============================================================
//  LoginScreen — Production-grade auth entry for all user types
//
//  User types:
//  • Customer  → Phone OTP (verified) OR Continue as Guest
//  • Employee  → Google Sign-In only (role checked server-side)
//  • Owner     → Google Sign-In + Device + PIN/Biometric
//
//  SECURITY CHANGES vs old version:
//  • Quick Login checkbox REMOVED — replaced with "Browse as Guest"
//    which uses GuestProvider (no Firebase anonymous users)
//  • Google logo loaded from local asset (not network URL)
//  • Root/jailbreak check on mount
//  • Security events logged on login failure
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/owner_auth_service.dart';
import '../services/device_security_service.dart';
import '../services/security_event_service.dart';
import 'auth/access_denied_screen.dart';
import 'auth/new_device_pending_screen.dart';
import 'auth/owner_first_login_screen.dart';
import 'auth/owner_daily_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _checkDeviceIntegrity();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Root/jailbreak detection ───────────────────────────────
  Future<void> _checkDeviceIntegrity() async {
    final isCompromised =
        await DeviceSecurityService.isDeviceRootedOrJailbroken();
    if (!mounted || !isCompromised) return;

    // Log security event
    await SecurityEventService().logEvent(
      event: SecurityEventType.rootDetected,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('Security Warning'),
        ]),
        content: const Text(
          'This device appears to be rooted or jailbroken.\n\n'
          'Running Fufaji on a compromised device disables critical security '
          'controls and may expose your account data. Please use a secure device.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('I Understand — Continue'),
          ),
        ],
      ),
    );
  }

  // ── Guest mode ─────────────────────────────────────────────
  Future<void> _continueAsGuest() async {
    HapticFeedback.lightImpact();
    final guest = Provider.of<GuestProvider>(context, listen: false);
    await guest.enterGuestMode();
    if (!mounted) return;
    context.go('/customer/home');
  }

  // ── Google Sign-In ─────────────────────────────────────────
  Future<void> _handleGoogleLogin() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    if (_selectedRole == UserRole.customer) {
      // Customer Google login — uses AuthProvider directly
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        if (auth.isPinRequired || auth.isDeviceVerificationRequired) {
          context.go('/security-pin');
        }
        // Otherwise GoRouter redirect handles routing
      } else if (auth.errorMessage != null) {
        _showError(auth.errorMessage!);
      }
    } else {
      // Employee / Owner — uses secure AuthService with custom claims
      final authService = AuthService();
      final result = await authService.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.status == AuthResultStatus.error ||
          result.status == AuthResultStatus.unauthorized) {
        await SecurityEventService().logEvent(
          event: SecurityEventType.failedLogin,
          email: result.message,
          metadata: {'reason': result.message},
        );
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                AccessDeniedScreen(message: result.message ?? 'Access Denied')));
      } else if (result.status == AuthResultStatus.employeeAccess) {
        context.go('/employee');
      } else if (result.status == AuthResultStatus.ownerAccess) {
        final state =
            await OwnerAuthService.getOwnerLoginState(result.owner!);
        if (!mounted) return;

        if (state == OwnerLoginState.firstLogin) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  OwnerFirstLoginScreen(owner: result.owner!)));
        } else if (state == OwnerLoginState.newDevicePending) {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewDevicePendingScreen()));
        } else if (state == OwnerLoginState.dailyLogin) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  OwnerDailyLoginScreen(owner: result.owner!)));
        }
      }
    }
  }

  // ── Phone OTP ──────────────────────────────────────────────
  Future<void> _handlePhoneLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final contact = '+91${_phoneController.text.trim()}';
    await auth.sendOTP(contact);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (auth.errorMessage == null) {
      context.push(
          '/otp/${Uri.encodeComponent(contact)}?role=${_selectedRole.toString().split('.').last}');
    } else {
      _showError(auth.errorMessage!);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand ─────────────────────────────────────
                Center(
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          size: 52, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Fufaji's Online",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                    const Text(
                      'आपकी अपनी दुकान',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.grey500,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // ── Role selector ──────────────────────────────
                const Text('I am a:',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey700)),
                const SizedBox(height: 10),
                Row(children: [
                  _RoleChip(
                    label: 'Customer',
                    labelHi: 'ग्राहक',
                    icon: Icons.person_outline,
                    selected: _selectedRole == UserRole.customer,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.customer),
                  ),
                  const SizedBox(width: 8),
                  _RoleChip(
                    label: 'Employee',
                    labelHi: 'कर्मचारी',
                    icon: Icons.badge_outlined,
                    selected: _selectedRole == UserRole.employee,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.employee),
                  ),
                  const SizedBox(width: 8),
                  _RoleChip(
                    label: 'Owner',
                    labelHi: 'मालिक',
                    icon: Icons.admin_panel_settings_outlined,
                    selected: _selectedRole == UserRole.shopOwner,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.shopOwner),
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Google button (all roles) ──────────────────
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLogin,
                  icon: const Icon(Icons.g_mobiledata,
                      size: 26, color: Colors.red),
                  label: const Text('Continue with Google',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.grey800)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.grey300, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // ── Customer-only: phone OTP + guest ──────────
                if (_selectedRole == UserRole.customer) ...[
                  const SizedBox(height: 22),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text('OR',
                          style: TextStyle(
                              color: AppTheme.grey400,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 22),

                  // Phone number
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mobile Number',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.grey700)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: const TextStyle(
                              fontSize: 18,
                              letterSpacing: 1,
                              fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              padding: const EdgeInsets.all(14),
                              child: const Text('+91',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.grey700)),
                            ),
                            hintText: '00000 00000',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.length != 10)
                              ? 'Enter valid 10-digit number'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Get OTP button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handlePhoneLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Get OTP',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),

                  const SizedBox(height: 16),

                  // ── Guest mode button ──────────────────────────
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    icon: const Icon(Icons.explore_outlined,
                        color: AppTheme.grey600),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Browse as Guest',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.grey700,
                                fontSize: 15)),
                        Text('No account needed — verify when you order',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.grey500)),
                      ],
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      side: const BorderSide(color: AppTheme.grey200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],

                // ── Owner notice ───────────────────────────────
                if (_selectedRole == UserRole.shopOwner) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.shield_outlined,
                          color: Color(0xFFF9A825), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Owners require Google Sign-In + device approval + PIN for maximum security.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5D4037),
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── Employee notice ────────────────────────────
                if (_selectedRole == UserRole.employee) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF1565C0), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Employees must be pre-registered by the owner. Use the same Google account your owner added.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D47A1),
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 36),
                const Text(
                  '🔒  Secure login · No password required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey400,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role chip widget ───────────────────────────────────────────
class _RoleChip extends StatelessWidget {
  final String label;
  final String labelHi;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.labelHi,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.grey50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.grey200,
                width: 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? Colors.white : AppTheme.grey500,
                size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : AppTheme.grey600)),
            Text(labelHi,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppTheme.grey400)),
          ]),
        ),
      ),
    );
  }
}
