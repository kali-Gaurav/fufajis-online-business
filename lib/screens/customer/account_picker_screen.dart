import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class AccountPickerScreen extends StatelessWidget {
  const AccountPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final accounts = auth.recentAccounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Account', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select an account to continue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        account['name'] as String? ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(account['phoneNumber'] as String? ?? ''),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // Normally this would trigger OTP login or auto-login if token is valid.
                        // For now, if we have their token we might be able to auto-login.
                        // If not, redirect to login with phone number prefilled.
                        context.push('/login');
                      },
                    ),
                  );
                },
              ),
            ),
            OutlinedButton(
              onPressed: () {
                context.push('/login');
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add another account'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.go('/customer/home');
              },
              child: const Text('Browse as Guest'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
