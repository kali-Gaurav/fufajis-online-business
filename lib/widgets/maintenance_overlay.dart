import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/app_theme.dart';

class MaintenanceOverlay extends StatelessWidget {
  final VoidCallback? onRetry;

  const MaintenanceOverlay({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppTheme.primaryColor.withOpacity(0.05)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branded/Maintenance Animation
            SizedBox(
              height: 250,
              child: Lottie.network(
                'https://assets9.lottiefiles.com/packages/lf20_0yfs9fpa.json', // Maintenance animation
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.settings_suggest_outlined,
                  size: 100,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "System Under Maintenance",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Fufaji is currently polishing the shop to serve you better. We'll be back online in a few minutes.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Check Status", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                // Potential WhatsApp support link
              },
              child: const Text("Contact Support", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
