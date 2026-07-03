// ============================================================
//  EmailLoginScreen — Animated premium auth entry for Email
//  Design: orange gradient bg, animated sparkles, staggered
//  form entrance, glow CTA button.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/fufaji_logo.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  late AnimationController _bgCtrl;
  late Animation<double> _bgFade;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _bgFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (mounted && success) {
        // Successful login is handled by the auth state listener pushing to the correct screen
        // or we can route directly if needed.
        final returnPath = GoRouterState.of(context).uri.queryParameters['returnPath'];
        if (returnPath != null && returnPath.isNotEmpty) {
           context.go(returnPath);
        } else {
           // We will rely on the global auth state change which triggers redirect or route them
           final role = GoRouterState.of(context).uri.queryParameters['role'] ?? 'customer';
           if (role == 'customer') context.go('/customer/home');
        }
      } else if (mounted && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.red[700],
          ),
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
                              const FufajiLogo(size: 80, onDark: true),
                              const SizedBox(height: 16),
                              const FadeSlideIn(
                                delay: Duration(milliseconds: 300),
                                child: Text(
                                  "Fufaji's Online",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
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
                        child: Form(
                          key: _formKey,
                          child: StaggeredList(
                            itemDelay: const Duration(milliseconds: 80),
                            children: [
                              const Text(
                                'Login with Email',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.grey900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Enter your email and password to continue",
                                style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                              ),
                              const SizedBox(height: 28),

                              // Email input
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Email Address',
                                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.grey500),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.grey500),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: AppTheme.grey500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // CTA button
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) => SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FufajiGlowButton(
                                    label: 'Sign In',
                                    icon: Icons.login_rounded,
                                    isLoading: auth.isLoading,
                                    onTap: _handleEmailLogin,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
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
