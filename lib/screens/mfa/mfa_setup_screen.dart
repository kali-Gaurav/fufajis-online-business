import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/mfa_password_service.dart';
import 'package:fufajis_online/constants/app_colors.dart';

/// MFA Setup Screen - For first-time admin/owner to create secret password
class MFASetupScreen extends StatefulWidget {
  const MFASetupScreen({super.key});

  @override
  State<MFASetupScreen> createState() => _MFASetupScreenState();
}

class _MFASetupScreenState extends State<MFASetupScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// Get validation requirements
  Map<String, bool> _getValidation(String password) {
    return MFAPasswordService.validatePassword(password);
  }

  /// Handle setup
  Future<void> _handleSetup() async {
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    // Validation
    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please enter both fields');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (!MFAPasswordService.isValidPassword(password)) {
      setState(() =>
          _errorMessage = MFAPasswordService.getValidationMessage(password));
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

      // Complete MFA setup
      final mfaService = auth.mfaService; // Assume this exists in AuthProvider
      final success = await mfaService.completeMFASetup(
        userId: currentUser.id,
        newPassword: password,
      );

      if (!mounted) return;

      if (success) {
        // Navigate to home based on role
        final homeRoute = _getHomeRoute(currentUser.role);
        context.go(homeRoute);
      } else {
        setState(() => _errorMessage = 'Failed to setup password. Try again.');
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
    return roleStr == 'admin' || roleStr == 'shopowner'
        ? '/owner/home'
        : '/employee/home';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validation = _getValidation(_passwordCtrl.text);
    final allValid = validation.values.every((e) => e);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Create Your Secret Password',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'This password protects your admin account.\nYou will enter it each time you log in.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 40),

              // Password field
              Text(
                'Secret Password',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter at least 8 characters',
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
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 24),

              // Confirm field
              Text(
                'Confirm Password',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showPassword,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Re-enter your password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 24),

              // Requirements
              if (_passwordCtrl.text.isNotEmpty) ...[
                Text(
                  'Password Requirements',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 12),
                _RequirementRow(
                  label: 'At least 8 characters',
                  met: validation['minLength'] ?? false,
                ),
                _RequirementRow(
                  label: 'Uppercase letter',
                  met: validation['hasUppercase'] ?? false,
                ),
                _RequirementRow(
                  label: 'Lowercase letter',
                  met: validation['hasLowercase'] ?? false,
                ),
                _RequirementRow(
                  label: 'Number',
                  met: validation['hasNumber'] ?? false,
                ),
                _RequirementRow(
                  label: 'Special character (!@#\$%^&*)',
                  met: validation['hasSpecial'] ?? false,
                ),
                const SizedBox(height: 24),
              ],

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

              // Setup button
              ElevatedButton(
                onPressed: _isLoading ||
                        !allValid ||
                        _passwordCtrl.text != _confirmCtrl.text
                    ? null
                    : _handleSetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      allValid && _passwordCtrl.text == _confirmCtrl.text
                          ? AppColors.primary
                          : Colors.grey[400],
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
                    : const Text('Setup Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Requirement row widget
class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({
    required this.label,
    required this.met,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 20,
            color: met ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
