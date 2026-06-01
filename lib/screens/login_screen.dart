import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import 'package:flutter/services.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}



class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;
  bool _isEmailMode = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final contact = _isEmailMode ? _emailController.text.trim() : '+91${_phoneController.text.trim()}';
    
    if (_isEmailMode) {
      await authProvider.sendEmailOTP(contact);
    } else {
      await authProvider.sendOTP(contact);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (authProvider.errorMessage == null) {
        context.push('/otp/${Uri.encodeComponent(contact)}?isEmail=$_isEmailMode&role=${_selectedRole.toString().split('.').last}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage!), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 60, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Fufaji's Online",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                "District Hyperlocal Shopping",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.grey600),
              ),
              const SizedBox(height: 40),
              
              const Text(
                "Continue as",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.grey700),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  _RoleButton(
                    label: "Customer",
                    icon: Icons.person_outline,
                    isSelected: _selectedRole == UserRole.customer,
                    onTap: () => setState(() => _selectedRole = UserRole.customer),
                  ),
                  const SizedBox(width: 6),
                  _RoleButton(
                    label: "Owner",
                    icon: Icons.shop_two_outlined,
                    isSelected: _selectedRole == UserRole.shopOwner,
                    onTap: () => setState(() => _selectedRole = UserRole.shopOwner),
                  ),
                  const SizedBox(width: 6),
                  _RoleButton(
                    label: "Delivery",
                    icon: Icons.delivery_dining_outlined,
                    isSelected: _selectedRole == UserRole.deliveryAgent,
                    onTap: () => setState(() => _selectedRole = UserRole.deliveryAgent),
                  ),
                  const SizedBox(width: 6),
                  _RoleButton(
                    label: "Employee",
                    icon: Icons.badge_outlined,
                    isSelected: _selectedRole == UserRole.employee,
                    onTap: () => setState(() => _selectedRole = UserRole.employee),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _isEmailMode = false;
                        _formKey.currentState?.reset();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: !_isEmailMode ? AppTheme.primary : Colors.transparent,
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: Text(
                          "Phone OTP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isEmailMode ? AppTheme.primary : AppTheme.grey600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _isEmailMode = true;
                        _formKey.currentState?.reset();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _isEmailMode ? AppTheme.primary : Colors.transparent,
                              width: 2.0,
                            ),
                          ),
                        ),
                        child: Text(
                          "Email OTP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isEmailMode ? AppTheme.primary : AppTheme.grey600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEmailMode) ...[
                      const Text(
                        "Phone Number",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.grey700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(14),
                            child: const Text("+91", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900)),
                          ),
                          hintText: "00000 00000",
                          hintStyle: TextStyle(fontSize: 18, color: AppTheme.grey400, letterSpacing: 2),
                          counterText: "",
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Phone number is required";
                          if (v.length != 10) return "Enter 10-digit number";
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return "Enter a valid mobile number";
                          return null;
                        },
                      ),
                    ] else ...[
                      const Text(
                        "Email Address",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.grey700),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.grey600),
                          hintText: "name@example.com",
                          hintStyle: TextStyle(fontSize: 16, color: AppTheme.grey400),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return "Email address is required";
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(v)) return "Enter a valid email address";
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: AppTheme.primary,
                  elevation: 4,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                ),
                child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Get OTP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              
              const SizedBox(height: 24),
              const Text(
                "By logging in, you agree to our Terms and Conditions",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.grey50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.grey200),
            boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppTheme.grey600, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isSelected ? Colors.white : AppTheme.grey600
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
