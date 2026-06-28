import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class NewDevicePendingScreen extends StatelessWidget {
  const NewDevicePendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Pending Approval')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, color: AppTheme.warning, size: 64),
              const SizedBox(height: 24),
              const Text(
                'New Device Detected',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'We noticed you are logging in from a new device. For your security, an alert has been sent to the primary email.\n\nPlease approve this device from an already trusted device or admin panel before continuing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Go back to login screen
                },
                child: const Text('Return to Login'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
