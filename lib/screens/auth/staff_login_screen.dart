import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_theme.dart';
import '../../widgets/animated_widgets.dart';

// In a real app, you would inject your AuthService or AuthProvider to handle the login.
// Assuming authProvider.signInStaff(id, pin) exists.

class StaffLoginScreen extends StatefulWidget {
  final String role; // 'employee' or 'delivery_agent'
  
  const StaffLoginScreen({super.key, required this.role});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loginId = _idController.text.trim();
    final pin = _pinController.text;

    if (loginId.isEmpty || pin.isEmpty) {
      setState(() => _errorMessage = 'Please enter ID and PIN');
      return;
    }
    
    if (pin.length != 4) {
      setState(() => _errorMessage = 'PIN must be 4 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // NOTE: Replace with actual authProvider call when connected
      // await Provider.of<AuthProvider>(context, listen: false).signInStaff(loginId, pin, widget.role);
      
      // Simulate network request
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        if (widget.role == 'employee') {
          context.go('/employee/home');
        } else {
          context.go('/delivery/dashboard');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.grey900;
    
    final isEmployee = widget.role == 'employee';
    final accentColor = isEmployee ? AppTheme.employeeAccent : AppTheme.deliveryAccent;
    final title = isEmployee ? 'Employee Login' : 'Delivery Agent Login';
    final icon = isEmployee ? Icons.badge_outlined : Icons.delivery_dining_rounded;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              FadeSlideIn(
                child: Icon(
                  icon,
                  size: 64,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    labelText: isEmployee ? 'Employee ID (e.g. EMP001)' : 'Agent ID (e.g. AGT001)',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: '4-Digit PIN',
                    prefixIcon: const Icon(Icons.password_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 32),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                child: TextButton(
                  onPressed: () {
                    context.push('/auth/staff-register?role=${widget.role}');
                  },
                  child: Text(
                    'Request Access',
                    style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
