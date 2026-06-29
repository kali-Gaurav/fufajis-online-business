import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufajis_online/providers/user_provider.dart';
import 'package:fufajis_online/providers/theme_provider.dart';
import 'package:fufajis_online/services/local_storage_service.dart';
import 'package:fufajis_online/services/export_service.dart';
import 'package:fufajis_online/services/user_service.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/app_theme.dart';

/// User Settings Screen (shared across all user roles)
///
/// Features:
/// - Language selection (English/Hindi)
/// - Theme selection (Light/Dark/System)
/// - Notification preferences
/// - Privacy policy
/// - GDPR: Data export
/// - GDPR: Account deletion
/// - Sign out
/// - Version information
class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  late PackageInfo _packageInfo;
  bool _isLoadingVersion = true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      setState(() => _isLoadingVersion = false);
    } catch (e) {
      debugPrint('Error loading package info: $e');
      setState(() => _isLoadingVersion = false);
    }
  }

  Future<void> _exportUserData() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );

    try {
      final path = await ExportService().exportUserData(user.id);
      if (mounted) Navigator.pop(context);
      
      await Share.shareXFiles(
        [XFile(path)],
        text: 'My Fufaji Store personal data export (GDPR/DPDP compliance).',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warning: This action cannot be undone.'),
            SizedBox(height: 12),
            Text('Deleting your account will:'),
            Text('- Remove all your profile data'),
            Text('- Delete all your addresses'),
            Text('- Clear your order history'),
            Text('- Cancel any active subscriptions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );

              try {
                await UserService().deleteUserAccount(user.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your account has been deleted successfully.')),
                  );
                  context.read<UserProvider>().clearUserData();
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Clear user data
                context.read<UserProvider>().clearUserData();

                // Clear local storage
                final localStorage = LocalStorageService();
                await localStorage.clearUserData();

                // Navigate to login
                if (mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionTitle('Appearance'),
            _buildLanguageOption(),
            _buildThemeOption(),
            const SizedBox(height: 24),

            // Notifications Section
            _buildSectionTitle('Notifications'),
            _buildNotificationOption(),
            const SizedBox(height: 24),

            // Privacy & Data Section
            _buildSectionTitle('Privacy & Data'),
            _buildPrivacyOption(),
            _buildDataExportOption(),
            const SizedBox(height: 24),

            // Danger Zone Section
            _buildSectionTitle('Account', isRed: true),
            _buildAccountDeletionOption(),
            _buildSignOutOption(),
            const SizedBox(height: 24),

            // About Section
            _buildSectionTitle('About'),
            _buildVersionOption(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isRed ? AppTheme.error : null,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildLanguageOption() {
    return Consumer2<UserProvider, ThemeProvider>(
      builder: (context, userProvider, themeProvider, _) {
        final currentLang = themeProvider.languageCode;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      currentLang == 'en' ? 'English' : 'हिन्दी',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                Switch(
                  value: currentLang == 'hi',
                  onChanged: (value) async {
                    try {
                      await themeProvider.toggleLanguage();
                      if (mounted) {
                        await userProvider.updateLanguage(value ? 'hi' : 'en');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      _getThemeName(themeProvider.themeMode),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                PopupMenuButton<ThemeModeType>(
                  onSelected: (mode) {
                    themeProvider.setThemeMode(mode);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ThemeModeType.light,
                      child: Row(
                        children: [
                          Icon(Icons.light_mode, size: 18),
                          SizedBox(width: 12),
                          Text('Light'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ThemeModeType.dark,
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode, size: 18),
                          SizedBox(width: 12),
                          Text('Dark'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ThemeModeType.system,
                      child: Row(
                        children: [
                          Icon(Icons.brightness_auto, size: 18),
                          SizedBox(width: 12),
                          Text('System'),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    _getThemeIcon(themeProvider.themeMode),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationOption() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final prefs = userProvider.preferences;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      prefs?.notificationsEnabled == true ? 'Enabled' : 'Disabled',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                Switch(
                  value: prefs?.notificationsEnabled ?? true,
                  onChanged: (value) {
                    try {
                      userProvider.toggleNotifications(value);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyOption() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.open_in_new),
        onTap: () {
          // In a real app, open privacy policy link
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Privacy policy link opening...')),
          );
        },
      ),
    );
  }

  Widget _buildDataExportOption() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.download),
        title: const Text('Export My Data (GDPR)', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Download all your personal data', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_forward),
        onTap: _exportUserData,
      ),
    );
  }

  Widget _buildAccountDeletionOption() {
    return Card(
      color: AppTheme.error.withValues(alpha: 0.1),
      child: ListTile(
        leading: const Icon(Icons.delete_outline, color: AppTheme.error),
        title: const Text(
          'Delete Account (GDPR)',
          style: TextStyle(color: AppTheme.error),
        ),
        subtitle: const Text('Permanently delete your account and data', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.arrow_forward, color: AppTheme.error),
        onTap: _deleteAccount,
      ),
    );
  }

  Widget _buildSignOutOption() {
    return Card(
      color: AppTheme.error.withValues(alpha: 0.1),
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppTheme.error),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.error),
        ),
        trailing: const Icon(Icons.arrow_forward, color: AppTheme.error),
        onTap: _signOut,
      ),
    );
  }

  Widget _buildVersionOption() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Version',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  _isLoadingVersion
                      ? 'Loading...'
                      : '${_packageInfo.version} (Build ${_packageInfo.buildNumber})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
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
}
