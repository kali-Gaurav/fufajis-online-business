// ============================================================
//  PhoneLoginScreen — Animated premium auth entry
//  Design: orange gradient bg, animated sparkles, staggered
//  form entrance, glow CTA button — same visual language as splash.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/fufaji_logo.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> with SingleTickerProviderStateMixin {
  late PhoneNumber _phoneNumber;
  final TextEditingController _phoneController = TextEditingController();
  bool _isValidPhone = false;
  late AnimationController _bgCtrl;
  late Animation<double> _bgFade;

  @override
  void initState() {
    super.initState();
    _phoneNumber = PhoneNumber(isoCode: 'IN');
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _bgFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  void _validatePhone(String phone) {
    setState(() {
      _isValidPhone = phone.isNotEmpty && phone.length >= 10;
    });
  }

  Future<void> _handlePhoneLogin() async {
    if (!_isValidPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid phone number'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }
    try {
      final authProvider = context.read<AuthProvider>();
      final phoneNumber = '+${_phoneNumber.dialCode}${_phoneController.text}';
      await authProvider.sendOTP(phoneNumber);
      if (mounted && context.mounted) {
        final role = GoRouterState.of(context).uri.queryParameters['role'] ?? 'customer';
        context.push(
          '/auth/phone-verify?phone=${Uri.encodeComponent(phoneNumber)}&role=${Uri.encodeComponent(role)}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgFade,
        builder: (_, child) => Opacity(opacity: _bgFade.value, child: child),
        child: FloatingSparklesBackground(
          sparkleCount: 7,
          child: SafeArea(
            child: Column(
              children: [
                // ── Top orange hero section ─────────────────────────
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      // Back Button
                      Positioned(
                        top: 10,
                        left: 10,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      Center(
                        child: BounceIn(
                          delay: const Duration(milliseconds: 100),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const FufajiLogo(size: 100, onDark: true),
                              const SizedBox(height: 20),
                              const FadeSlideIn(
                                delay: Duration(milliseconds: 300),
                                child: Text(
                                  "Fufaji's Online",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 420),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                                  ),
                                  child: const Text(
                                    'आपकी अपनी दुकान  ·  Your own store',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── White card form section ─────────────────────────
                Expanded(
                  flex: 5,
                  child: ScaleInFade(
                    delay: const Duration(milliseconds: 200),
                    beginScale: 0.92,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: SingleChildScrollView(
                        child: StaggeredList(
                          itemDelay: const Duration(milliseconds: 80),
                          children: [
                            const Text(
                              'Login with Phone',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.grey900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "We'll send a one-time verification code",
                              style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                            ),
                            const SizedBox(height: 28),

                            // Phone input
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _isValidPhone ? AppTheme.primary : Colors.grey.shade300,
                                  width: _isValidPhone ? 2 : 1,
                                ),
                              ),
                              child: InternationalPhoneNumberInput(
                                onInputChanged: (PhoneNumber number) {
                                  _phoneNumber = number;
                                },
                                onInputValidated: (bool value) {
                                  _validatePhone(_phoneController.text);
                                },
                                selectorConfig: const SelectorConfig(
                                  selectorType: PhoneInputSelectorType.DROPDOWN,
                                ),
                                ignoreBlank: false,
                                autoValidateMode: AutovalidateMode.disabled,
                                maxLength: 15,
                                textFieldController: _phoneController,
                                formatInput: true,
                                inputDecoration: InputDecoration(
                                  hintText: 'Phone Number',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                initialValue: _phoneNumber,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // CTA button
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) => SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FufajiGlowButton(
                                  label: 'Send OTP',
                                  icon: Icons.send_rounded,
                                  isLoading: auth.isLoading,
                                  onTap: _isValidPhone ? _handlePhoneLogin : null,
                                  color: _isValidPhone ? AppTheme.primary : Colors.grey[400],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Error state
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                if (auth.errorMessage == null) {
                                  return const SizedBox.shrink();
                                }
                                return ScaleInFade(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      border: Border.all(color: Colors.red.shade200),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red[700], size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: TextStyle(color: Colors.red[800], fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[500], size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Standard SMS rates may apply',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
