import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _villageController;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user?.name);
    _emailController = TextEditingController(text: user?.email);
    _villageController = TextEditingController(text: user?.village);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.white, foregroundColor: AppTheme.grey900),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                decoration: const InputDecoration(labelText: 'Home Village / Area', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Get alerts for order status and deals'),
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
                activeThumbColor: AppTheme.primary,
              ),
              ListTile(
                title: const Text('App Language'),
                subtitle: Text('Selected: ${themeProvider.locale.languageCode == 'en' ? 'English' : 'हिन्दी'}'),
                trailing: const Icon(Icons.language),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English'),
                          onTap: () {
                            themeProvider.setLocale(const Locale('en'));
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('हिन्दी'),
                          onTap: () {
                            themeProvider.setLocale(const Locale('hi'));
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeProvider.themeMode == ThemeModeType.dark,
                onChanged: (val) => themeProvider.setThemeMode(val ? ThemeModeType.dark : ThemeModeType.light),
                activeThumbColor: AppTheme.primary,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await authProvider.updateProfile(
                        name: _nameController.text,
                        email: _emailController.text,
                        village: _villageController.text,
                      );
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved!')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => authProvider.logout(),
                child: const Center(child: Text('Logout from App', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
