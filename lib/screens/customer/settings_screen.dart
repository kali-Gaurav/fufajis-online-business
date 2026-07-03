import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../utils/app_theme.dart';
import '../../services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context);

    // Get localized language string directly from accessibility provider
    final currentLang = accessibilityProvider.preferredLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(accessibilityProvider.label(en: 'Settings', hi: 'सेटिंग्स')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                accessibilityProvider.label(en: 'Profile Information', hi: 'प्रोफ़ाइल जानकारी'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: accessibilityProvider.label(en: 'Display Name', hi: 'नाम'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: accessibilityProvider.label(en: 'Email Address', hi: 'ईमेल पता'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                decoration: InputDecoration(
                  labelText: accessibilityProvider.label(
                    en: 'Home Village / Area',
                    hi: 'गांव / क्षेत्र',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                accessibilityProvider.label(en: 'Preferences', hi: 'पसंद (सेटिंग्स)'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(
                  accessibilityProvider.label(
                    en: 'Simple Mode (Elderly)',
                    hi: 'सरल मोड (बुजुर्गों के लिए)',
                  ),
                ),
                subtitle: Text(
                  accessibilityProvider.label(
                    en: 'Larger text, simpler buttons & Hindi language',
                    hi: 'बड़े अक्षर, आसान बटन और हिंदी भाषा',
                  ),
                ),
                value: accessibilityProvider.isElderlyMode,
                onChanged: (val) => accessibilityProvider.setElderlyMode(val),
                activeThumbColor: AppTheme.primary,
              ),
              if (accessibilityProvider.isElderlyMode) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    accessibilityProvider.label(en: 'Text Size', hi: 'अक्षर का आकार'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Slider(
                  min: 1.2,
                  max: 1.6,
                  divisions: 4,
                  label: '${(accessibilityProvider.fontScale * 100).round()}%',
                  value: accessibilityProvider.fontScale,
                  onChanged: (val) => accessibilityProvider.setFontScale(val),
                  activeColor: AppTheme.primary,
                ),
              ],
              SwitchListTile(
                title: Text(
                  accessibilityProvider.label(en: 'Push Notifications', hi: 'पुश नोटिफिकेशन'),
                ),
                subtitle: Text(
                  accessibilityProvider.label(
                    en: 'Get alerts for order status and deals',
                    hi: 'ऑर्डर और ऑफर के अलर्ट पाएं',
                  ),
                ),
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
                activeThumbColor: AppTheme.primary,
              ),
              ListTile(
                title: Text(accessibilityProvider.label(en: 'App Language', hi: 'ऐप की भाषा')),
                subtitle: Text(
                  accessibilityProvider.label(
                    en: 'Selected: ${currentLang == 'en' ? 'English' : 'हिन्दी'}',
                    hi: 'चुना हुआ: ${currentLang == 'en' ? 'English' : 'हिन्दी'}',
                  ),
                ),
                trailing: const Icon(Icons.language),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text(
                            'English',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            themeProvider.setLocale(const Locale('en'));
                            accessibilityProvider.setPreferredLanguage('en');
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text(
                            'हिन्दी',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onTap: () {
                            themeProvider.setLocale(const Locale('hi'));
                            accessibilityProvider.setPreferredLanguage('hi');
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              SwitchListTile(
                title: Text(
                  accessibilityProvider.label(en: 'Dark Mode', hi: 'डार्क मोड (काली स्क्रीन)'),
                ),
                value: themeProvider.themeMode == ThemeModeType.dark,
                onChanged: (val) =>
                    themeProvider.setThemeMode(val ? ThemeModeType.dark : ThemeModeType.light),
                activeThumbColor: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                accessibilityProvider.label(en: 'System', hi: 'सिस्टम'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(
                  accessibilityProvider.label(en: 'Check for Updates', hi: 'अपडेट के लिए जांचें'),
                ),
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        accessibilityProvider.label(
                          en: 'Current Version: ${snapshot.data!.version}',
                          hi: 'वर्तमान संस्करण: ${snapshot.data!.version}',
                        ),
                      );
                    }
                    return Text(
                      accessibilityProvider.label(
                        en: 'Checking version...',
                        hi: 'संस्करण की जाँच की जा रही है...',
                      ),
                    );
                  },
                ),
                trailing: const Icon(Icons.system_update),
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        accessibilityProvider.label(
                          en: 'Checking for updates...',
                          hi: 'अपडेट की जांच कर रहे हैं...',
                        ),
                      ),
                    ),
                  );
                  final hasUpdate = await UpdateService().handleVersionCheck(context);
                  if (hasUpdate && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          accessibilityProvider.label(
                            en: 'You are on the latest version!',
                            hi: 'आप नवीनतम संस्करण पर हैं!',
                          ),
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                },
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              accessibilityProvider.label(
                                en: 'Settings saved!',
                                hi: 'सेटिंग्स सुरक्षित हो गईं!',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    accessibilityProvider.label(en: 'SAVE SETTINGS', hi: 'सेटिंग्स सुरक्षित करें'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => authProvider.logout(),
                child: Center(
                  child: Text(
                    accessibilityProvider.label(en: 'Logout from App', hi: 'ऐप से लॉगआउट करें'),
                    style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
