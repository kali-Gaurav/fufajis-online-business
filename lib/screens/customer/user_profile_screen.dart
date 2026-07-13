import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/models/address_model.dart';

import 'package:fufajis_online/providers/user_provider.dart';
import 'package:fufajis_online/providers/theme_provider.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';

/// Customer User Profile Screen
///
/// Displays and manages:
/// - User profile information (name, email, phone)
/// - Profile picture
/// - Language settings
/// - Theme settings
/// - Delivery addresses
/// - Sign out
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.read<UserProvider>();
    if (userProvider.currentUser != null) {
      _nameController.text = userProvider.currentUser!.name ?? '';
      _emailController.text = userProvider.currentUser!.email ?? '';
      _phoneController.text = userProvider.currentUser!.phoneNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditingProfile = !_isEditingProfile;
    });
  }

  Future<void> _saveProfile() async {
    final userProvider = context.read<UserProvider>();

    try {
      await userProvider.updateProfile({
        'name': _nameController.text,
        'email': _emailController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
        _toggleEditMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showAddAddressDialog() {
    showDialog(context: context, builder: (_) => const _AddAddressDialog());
  }

  void _showEditAddressDialog(AddressModel address) {
    showDialog(
      context: context,
      builder: (_) => _EditAddressDialog(address: address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final user = userProvider.currentUser;

          if (user == null) {
            return const Center(child: Text('No user data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                _buildProfileHeader(user),
                const SizedBox(height: 24),

                // Profile Information Section
                _buildProfileSection(user),
                const SizedBox(height: 24),

                // Preferences Section
                _buildPreferencesSection(),
                const SizedBox(height: 24),

                // Addresses Section
                _buildAddressesSection(userProvider),
                const SizedBox(height: 24),

                // Sign Out Button
                _buildSignOutButton(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: user.profileImage != null
              ? NetworkImage(user.profileImage as String)
              : null,
          backgroundColor: Colors.grey[300],
          child: user.profileImage == null
              ? Icon(Icons.person, size: 50, color: Colors.grey[600])
              : null,
        ),
        const SizedBox(height: 16),
        Text(user.name ?? 'User', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          user.phoneNumber,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildProfileSection(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Profile Information', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: _toggleEditMode,
                  child: Text(_isEditingProfile ? 'Cancel' : 'Edit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEditingProfile) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  label: Text('Name'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  label: Text('Email'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  label: Text('Phone Number'),
                  border: OutlineInputBorder(),
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _saveProfile, child: const Text('Save Changes')),
              ),
            ] else ...[
              _buildInfoRow('Name', user.name ?? 'Not set'),
              const SizedBox(height: 12),
              _buildInfoRow('Email', user.email ?? 'Not set'),
              const SizedBox(height: 12),
              _buildInfoRow('Phone', user.phoneNumber),
              const SizedBox(height: 12),
              _buildInfoRow('Member Since', _formatDate(user.createdAt)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildLanguageToggle(),
            const Divider(height: 24),
            _buildThemeToggle(),
            const Divider(height: 24),
            _buildNotificationToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Consumer2<UserProvider, ThemeProvider>(
      builder: (context, userProvider, themeProvider, _) {
        final currentLang = themeProvider.languageCode;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Language', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  currentLang == 'en' ? 'English' : 'हिन्दी',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            Switch(
              value: currentLang == 'hi',
              onChanged: (value) async {
                await themeProvider.toggleLanguage();
                if (mounted) {
                  await userProvider.updateLanguage(value ? 'hi' : 'en');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeToggle() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  _getThemeName(themeProvider.themeMode),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            PopupMenuButton<ThemeModeType>(
              onSelected: (mode) {
                themeProvider.setThemeMode(mode);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: ThemeModeType.light, child: Text('Light')),
                const PopupMenuItem(value: ThemeModeType.dark, child: Text('Dark')),
                const PopupMenuItem(value: ThemeModeType.system, child: Text('System')),
              ],
              child: Icon(_getThemeIcon(themeProvider.themeMode)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationToggle() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final prefs = userProvider.preferences;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  prefs?.notificationsEnabled == true ? 'Enabled' : 'Disabled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            Switch(
              value: prefs?.notificationsEnabled ?? true,
              onChanged: (value) {
                userProvider.toggleNotifications(value);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddressesSection(UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Delivery Addresses', style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton.icon(
              onPressed: _showAddAddressDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (userProvider.addresses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No addresses saved yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: userProvider.addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final address = userProvider.addresses[index];
              return _buildAddressCard(address, userProvider);
            },
          ),
      ],
    );
  }

  Widget _buildAddressCard(AddressModel address, UserProvider userProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(address.addressType.name.toUpperCase()),
                  backgroundColor: AppTheme.info.withOpacity(0.1),
                ),
                if (address.isDefault)
                  const Chip(label: Text('Default'), backgroundColor: AppTheme.success),
              ],
            ),
            const SizedBox(height: 8),
            Text(address.toString(), style: Theme.of(context).textTheme.bodyMedium),
            if (address.landmark != null) ...[
              const SizedBox(height: 4),
              Text(
                'Landmark: ${address.landmark}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: () => userProvider.setDefaultAddress(address.id),
                    child: const Text('Set as Default'),
                  ),
                TextButton(
                  onPressed: () => _showEditAddressDialog(address),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _showDeleteAddressDialog(address, userProvider),
                  child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAddressDialog(AddressModel address, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete this address?\n\n$address'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await userProvider.deleteAddressById(address.id);
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Address deleted')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w700)),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    context.read<UserProvider>().clearUserData();
                    context.go('/login');
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.error,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _getThemeName(ThemeModeType mode) {
    switch (mode) {
      case ThemeModeType.light:
        return 'Light';
      case ThemeModeType.dark:
        return 'Dark';
      case ThemeModeType.system:
        return 'System';
    }
  }

  IconData _getThemeIcon(ThemeModeType mode) {
    switch (mode) {
      case ThemeModeType.light:
        return Icons.light_mode;
      case ThemeModeType.dark:
        return Icons.dark_mode;
      case ThemeModeType.system:
        return Icons.brightness_auto;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog();

  @override
  State<_AddAddressDialog> createState() => __AddAddressDialogState();
}

class __AddAddressDialogState extends State<_AddAddressDialog> {
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _landmarkController;
  AddressType _selectedType = AddressType.home;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalCodeController = TextEditingController();
    _landmarkController = TextEditingController();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _streetController,
              decoration: const InputDecoration(
                label: Text('Street Address'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(label: Text('City'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(label: Text('State'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postalCodeController,
              decoration: const InputDecoration(
                label: Text('Postal Code'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landmarkController,
              decoration: const InputDecoration(
                label: Text('Landmark (Optional)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AddressType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                label: Text('Address Type'),
                border: OutlineInputBorder(),
              ),
              items: AddressType.values
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type.name.toUpperCase())),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            if (_streetController.text.isEmpty ||
                _cityController.text.isEmpty ||
                _stateController.text.isEmpty ||
                _postalCodeController.text.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
              return;
            }

            final address = AddressModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              street: _streetController.text,
              city: _cityController.text,
              state: _stateController.text,
              postalCode: _postalCodeController.text,
              country: 'India',
              latitude: 0.0,
              longitude: 0.0,
              addressType: _selectedType,
              landmark: _landmarkController.text.isEmpty ? null : _landmarkController.text,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            try {
              await context.read<UserProvider>().addNewAddress(address);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Address added successfully')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditAddressDialog extends StatefulWidget {
  final AddressModel address;

  const _EditAddressDialog({required this.address});

  @override
  State<_EditAddressDialog> createState() => __EditAddressDialogState();
}

class __EditAddressDialogState extends State<_EditAddressDialog> {
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _landmarkController;
  late AddressType _selectedType;

  @override
  void initState() {
    super.initState();
    _streetController = TextEditingController(text: widget.address.street);
    _cityController = TextEditingController(text: widget.address.city);
    _stateController = TextEditingController(text: widget.address.state);
    _postalCodeController = TextEditingController(text: widget.address.postalCode);
    _landmarkController = TextEditingController(text: widget.address.landmark ?? '');
    _selectedType = widget.address.addressType;
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Address', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _streetController,
              decoration: const InputDecoration(
                label: Text('Street Address'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(label: Text('City'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stateController,
              decoration: const InputDecoration(label: Text('State'), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _postalCodeController,
              decoration: const InputDecoration(
                label: Text('Postal Code'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landmarkController,
              decoration: const InputDecoration(
                label: Text('Landmark (Optional)'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AddressType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                label: Text('Address Type'),
                border: OutlineInputBorder(),
              ),
              items: AddressType.values
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type.name.toUpperCase())),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            if (_streetController.text.isEmpty ||
                _cityController.text.isEmpty ||
                _stateController.text.isEmpty ||
                _postalCodeController.text.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
              return;
            }

            final updatedAddress = widget.address.copyWith(
              street: _streetController.text,
              city: _cityController.text,
              state: _stateController.text,
              postalCode: _postalCodeController.text,
              addressType: _selectedType,
              landmark: _landmarkController.text.isEmpty ? null : _landmarkController.text,
              updatedAt: DateTime.now(),
            );

            try {
              await context.read<UserProvider>().updateExistingAddress(
                widget.address.id,
                updatedAddress,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Address updated successfully')));
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}
