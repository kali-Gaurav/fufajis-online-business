import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'fleet_tracking_dashboard.dart';

class RiderManagementScreen extends StatefulWidget {
  const RiderManagementScreen({super.key});

  @override
  State<RiderManagementScreen> createState() => _RiderManagementScreenState();
}

class _RiderManagementScreenState extends State<RiderManagementScreen> {
  final UserService _userService = UserService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  void _showAddRiderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authorize New Rider', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Ramesh Kumar',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+919876543210',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rider must use this number to login via OTP.',
              style: TextStyle(fontSize: 10, color: AppTheme.grey500),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final phone = _phoneController.text.trim();
              final name = _nameController.text.trim();
              if (phone.isNotEmpty && name.isNotEmpty) {
                final owner = Provider.of<AuthProvider>(context, listen: false).currentUser;
                await _userService.authorizeUser(
                  phone,
                  UserRole.deliveryAgent,
                  name,
                  owner?.id ?? 'owner',
                );
                if (mounted) {
                  Navigator.pop(context);
                  _phoneController.clear();
                  _nameController.clear();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Rider authorized successfully')));
                }
              }
            },
            child: const Text('Authorize'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Fleet', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FleetTrackingDashboard()),
            ),
            icon: const Icon(Icons.map, color: AppTheme.primary),
            label: const Text('Live Map', style: TextStyle(color: AppTheme.primary)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _userService.getAuthorizedRidersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          final riders = snapshot.data ?? [];

          if (riders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delivery_dining, size: 64, color: AppTheme.grey300),
                  const SizedBox(height: 16),
                  const Text('No riders authorized yet.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddRiderDialog,
                    child: const Text('Add Your First Rider'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: riders.length,
            itemBuilder: (context, index) {
              final rider = riders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.info,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(rider['name'] ?? 'Unknown'),
                  subtitle: Text(rider['phoneNumber'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text(
                            'Deauthorize Rider?',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          content: const Text(
                            'This rider will lose access to the Delivery Dashboard immediately.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes, Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _userService.deauthorizeUser(rider['phoneNumber']);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRiderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
