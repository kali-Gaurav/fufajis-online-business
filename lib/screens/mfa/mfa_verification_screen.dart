import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'package:fufajis_online/constants/app_colors.dart';

/// MFA Verification Screen - Enter password to complete login
class MFAVerificationScreen extends StatefulWidget {
  const MFAVerificationScreen({super.key});

  @override
  State<MFAVerificationScreen> createState() => _MFAVerificationScreenState();
}

class _MFAVerificationScreenState extends State<MFAVerificationScreen> {
  final _passwordCtrl = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _attemptsRemaining = 3;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Handle verification
  Future<void> _handleVerify() async {
    final password = _passwordCtrl.text.trim();

    if (password.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        setState(() => _errorMessage = 'User not found. Please log in again.');
        return;
      }

      // Verify MFA password (you'll need to add this to AuthProvider)
      final mfaService = auth.mfaService;
      final success = await mfaService.verifyMFAPassword(
        userId: currentUser.id,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to home
        final homeRoute = _getHomeRoute(currentUser.role);
        context.go(homeRoute);
      } else {
        // Get attempts remaining
        _attemptsRemaining =
            await mfaService.getAttemptsRemaining(currentUser.id);
        final isLocked = await mfaService.isAccountLocked(currentUser.id);

        if (isLocked) {
          setState(() => _errorMessage =
              'Too many attempts. Account locked for 15 minutes.');
        } else {
          setState(() {
            _passwordCtrl.clear();
            _errorMessage =
                'Incorrect password ($_attemptsRemaining attempts remaining)';
          });
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getHomeRoute(dynamic role) {
    final roleStr = role.toString().split('.').last.toLowerCase();
    if (roleStr == 'admin' || roleStr == 'shopowner') return '/owner/home';
    if (roleStr == 'employee') return '/employee/home';
    if (roleStr == 'deliveryagent') return '/delivery/home';
    return '/customer/home';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => false, // Prevent going back
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.verified_user_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify Your Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'One more step to complete your login',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 48),

                // Password field
                Text(
                  'Enter Secret Password',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPassword,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: 'Your secret password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: _isLoading ? null : (_) => _handleVerify(),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                const SizedBox(height: 12),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Contact your admin to reset your password'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style:
                                TextStyle(color: AppColors.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Attempts counter
                Center(
                  child: Text(
                    'Attempts remaining: $_attemptsRemaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _attemptsRemaining <= 1
                              ? AppColors.error
                              : Colors.grey[600],
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // Verify button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Verify & Login'),
                ),
                const SizedBox(height: 24),

                // Security info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your password is protected by PBKDF2 encryption. Never share it with anyone.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                        ),
                      ),
                    ],
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
