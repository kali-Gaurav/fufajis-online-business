import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/phone_login_screen.dart';
import '../screens/auth/phone_verify_screen.dart';

/// App Router Configuration
/// Centralized routing for the Fufaji application

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
    routes: [
      // Authentication Routes
      GoRoute(
        path: '/phone-login',
        name: 'phoneLogin',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/phone-verify',
        name: 'phoneVerify',
        builder: (context, state) {
          final phoneNumber = state.extra as String?;
          if (phoneNumber == null) {
            return const Scaffold(
              body: Center(
                child: Text('Phone number not provided'),
              ),
            );
          }
          return PhoneVerifyScreen(phoneNumber: phoneNumber);
        },
      ),

      // Add your other routes here
      // Example:
      // GoRoute(
      //   path: '/home',
      //   name: 'home',
      //   builder: (context, state) => const HomeScreen(),
      // ),
    ],

    // Redirect logic for authentication flow
    redirect: (context, state) {
      // Add your redirect logic here
      // Example: redirect unauthenticated users to login
      return null;
    },
  );

  /// Navigate to phone login screen
  static void goToPhoneLogin(BuildContext context) {
    context.pushNamed('phoneLogin');
  }

  /// Navigate to phone verification screen
  static void goToPhoneVerify(BuildContext context, String phoneNumber) {
    context.pushNamed('phoneVerify', extra: phoneNumber);
  }

  /// Navigate to home screen (or main app)
  static void goToHome(BuildContext context) {
    context.goNamed('home');
  }

  /// Go back
  static void goBack(BuildContext context) {
    context.pop();
  }
}
