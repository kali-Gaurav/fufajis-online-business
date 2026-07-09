import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_preferences.dart';
import '../providers/profile_provider.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  final CustomerPreferences preferences;

  const PreferencesScreen({super.key, required this.preferences});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late bool _notificationsEnabled;
  late bool _marketingOptIn;
  late String _language;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.preferences.notificationsEnabled;
    _marketingOptIn = widget.preferences.marketingOptIn;
    _language = widget.preferences.language;
  }

  Future<void> _updatePreferences() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(profileNotifierProvider.notifier).updatePreferences({
        'notifications_enabled': _notificationsEnabled,
        'marketing_opt_in': _marketingOptIn,
        'language': _language,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                title: const Text('Language'),
                subtitle: const Text('Choose your preferred language'),
                trailing: DropdownButton<String>(
                  value: _language,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _language) {
                      setState(() => _language = val);
                      _updatePreferences();
                    }
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              SwitchListTile(
                title: const Text('Order Updates'),
                subtitle: const Text('Receive notifications about your order status'),
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() => _notificationsEnabled = val);
                  _updatePreferences();
                },
              ),
              SwitchListTile(
                title: const Text('Promotions & Offers'),
                subtitle: const Text('Receive marketing updates and personalized offers'),
                value: _marketingOptIn,
                onChanged: (val) {
                  setState(() => _marketingOptIn = val);
                  _updatePreferences();
                },
              ),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
