import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/trusted_device_service.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});

  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final TrustedDeviceService _trustedDeviceService = TrustedDeviceService();
  String _currentDeviceId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentDeviceId();
  }

  Future<void> _loadCurrentDeviceId() async {
    final id = await TrustedDeviceService.getDeviceId();
    if (mounted) setState(() => _currentDeviceId = id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final uid = auth.currentUser?.id;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Devices')),
        body: const Center(child: Text('Please login first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _trustedDeviceService.getMyDevices(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          final devices = snapshot.data ?? [];

          if (devices.isEmpty) {
            return const Center(child: Text('No devices found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isCurrent = device['deviceId'] == _currentDeviceId;
              final isTrusted = device['trusted'] == true;
              
              DateTime? lastLogin;
              if (device['lastLogin'] != null && device['lastLogin'] is Timestamp) {
                lastLogin = (device['lastLogin'] as Timestamp).toDate();
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(
                    isCurrent ? Icons.phone_android : Icons.devices,
                    color: isCurrent ? AppTheme.primary : AppTheme.grey600,
                    size: 32,
                  ),
                  title: Row(
                    children: [
                      Text(
                        (device['deviceName'] as String?) ?? 'Unknown Device',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('This Device', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        lastLogin != null ? 'Last active: ${DateFormat.yMMMd().add_jm().format(lastLogin)}' : 'Never active',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTrusted ? 'Trusted Device' : 'Not Trusted',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTrusted ? AppTheme.success : AppTheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: AppTheme.error),
                    onPressed: () => _revokeAccess(context, uid, device['deviceId'] as String),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _revokeAccess(BuildContext context, String uid, String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This device will be logged out and will need OTP to login again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _trustedDeviceService.revokeDevice(uid, deviceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device access revoked')),
        );
      }
    }
  }
}
