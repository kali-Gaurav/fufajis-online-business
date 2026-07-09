import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/profile_provider.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/section_card.dart';
import 'edit_profile_screen.dart';
import 'address_list_screen.dart';
import 'preferences_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsyncValue = ref.watch(profileNotifierProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
          )
        ],
      ),
      body: profileAsyncValue.when(
        data: (data) {
          final profile = data.profile;
          final addresses = data.addresses;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(profileNotifierProvider);
              await ref.read(profileNotifierProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 16),
                // Avatar and basic info
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Icon(Icons.person, size: 40, color: Theme.of(context).primaryColor)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.firstName ?? 'Welcome',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Completion Card
                ProfileCompletionCard(completionPercentage: profile.profileCompletion),

                // Personal Information
                SectionCard(
                  title: 'Personal Information',
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(initialProfile: profile),
                      ),
                    );
                  },
                  children: [
                    _InfoRow(label: 'Name', value: '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim()),
                    _InfoRow(label: 'Phone', value: profile.phone ?? 'Not provided'),
                    _InfoRow(label: 'Email', value: user?.email ?? 'Not provided'),
                  ],
                ),

                // Addresses
                SectionCard(
                  title: 'Delivery Addresses',
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddressListScreen(addresses: addresses),
                      ),
                    );
                  },
                  children: [
                    if (addresses.isEmpty)
                      const Text('No addresses saved yet.', style: TextStyle(color: Colors.grey))
                    else
                      ...addresses.take(2).map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(a.formattedAddress)),
                              ],
                            ),
                          )),
                    if (addresses.length > 2)
                      Text(
                        '+ ${addresses.length - 2} more',
                        style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12),
                      )
                  ],
                ),

                // Preferences
                SectionCard(
                  title: 'Preferences',
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PreferencesScreen(preferences: data.preferences),
                      ),
                    );
                  },
                  children: [
                    _InfoRow(label: 'Language', value: data.preferences.language.toUpperCase()),
                    _InfoRow(
                        label: 'Notifications',
                        value: data.preferences.notificationsEnabled ? 'Enabled' : 'Disabled'),
                  ],
                ),

                // Security (Static for now)
                SectionCard(
                  title: 'Security',
                  children: [
                    _InfoRow(label: 'Authentication', value: 'Verified ✅'),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load profile\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(profileNotifierProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // In a real app with go_router, you'd route back to login here
    // context.go('/login');
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
