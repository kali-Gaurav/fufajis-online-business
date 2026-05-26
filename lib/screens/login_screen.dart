import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  UserRole _selectedRole = UserRole.customer;
  bool _isLoading = false;

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final phoneNumber = '+91${_phoneController.text.trim()}';
    
    // In a real app, we'd send OTP here. 
    // The provider already handles the logic.
    await authProvider.sendOTP(phoneNumber);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (authProvider.errorMessage == null) {
        // Pass the selected role to OTP screen or store it in provider for post-OTP setup
        context.push('/otp/$phoneNumber?role=${_selectedRole.toString().split('.').last}');
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
              // Brand Logo/Icon
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
              
              // Role Selection
              Row(
                children: [
                  _RoleButton(
                    label: "Customer",
                    icon: Icons.person_outline,
                    isSelected: _selectedRole == UserRole.customer,
                    onTap: () => setState(() => _selectedRole = UserRole.customer),
                  ),
                  const SizedBox(width: 12),
                  _RoleButton(
                    label: "Owner",
                    icon: Icons.shop_two_outlined,
                    isSelected: _selectedRole == UserRole.shopOwner,
                    onTap: () => setState(() => _selectedRole = UserRole.shopOwner),
                  ),
                  const SizedBox(width: 12),
                  _RoleButton(
                    label: "Delivery",
                    icon: Icons.delivery_dining_outlined,
                    isSelected: _selectedRole == UserRole.deliveryAgent,
                    onTap: () => setState(() => _selectedRole = UserRole.deliveryAgent),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Phone Number",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.grey700),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
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
                      validator: (v) => (v == null || v.length != 10) ? "Enter 10-digit number" : null,
                    ),
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
