import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late NotificationSettings _settings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _settings = NotificationSettings(
      orderUpdates: provider.settings.orderUpdates,
      promotions: provider.settings.promotions,
      priceDrops: provider.settings.priceDrops,
      shopUpdates: provider.settings.shopUpdates,
      systemMessages: provider.settings.systemMessages,
      quietHoursStart: provider.settings.quietHoursStart,
      quietHoursEnd: provider.settings.quietHoursEnd,
      frequencyLimitPerHour: provider.settings.frequencyLimitPerHour,
    );

    if (authProvider.currentUser != null) {
      provider.initialize(authProvider.currentUser!.id).then((_) {
        if (mounted) {
          setState(() {
            _settings = NotificationSettings(
              orderUpdates: provider.settings.orderUpdates,
              promotions: provider.settings.promotions,
              priceDrops: provider.settings.priceDrops,
              shopUpdates: provider.settings.shopUpdates,
              systemMessages: provider.settings.systemMessages,
              quietHoursStart: provider.settings.quietHoursStart,
              quietHoursEnd: provider.settings.quietHoursEnd,
              frequencyLimitPerHour: provider.settings.frequencyLimitPerHour,
            );
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Notification Types'),
            _buildSettingsCard([
              _buildSwitchTile(
                'Order Updates',
                'Track your order status and delivery',
                _settings.orderUpdates,
                (val) => setState(() => _settings.orderUpdates = val),
              ),
              _buildSwitchTile(
                'Promotions & Offers',
                'Get notified about deals and coupons',
                _settings.promotions,
                (val) => setState(() => _settings.promotions = val),
              ),
              _buildSwitchTile(
                'Price Drop Alerts',
                'Updates on items in your wishlist',
                _settings.priceDrops,
                (val) => setState(() => _settings.priceDrops = val),
              ),
              _buildSwitchTile(
                'Shop Updates',
                'New products from followed shops',
                _settings.shopUpdates,
                (val) => setState(() => _settings.shopUpdates = val),
              ),
              _buildSwitchTile(
                'System Messages',
                'App updates and maintenance notices',
                _settings.systemMessages,
                (val) => setState(() => _settings.systemMessages = val),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Quiet Hours'),
            _buildSettingsCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No notifications between these hours',
                      style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerButton(
                            'From',
                            _settings.quietHoursStart,
                            () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _settings.quietHoursStart,
                              );
                              if (time != null) {
                                setState(() => _settings.quietHoursStart = time);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerButton('To', _settings.quietHoursEnd, () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _settings.quietHoursEnd,
                            );
                            if (time != null) {
                              setState(() => _settings.quietHoursEnd = time);
                            }
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Frequency Limits'),
            _buildSettingsCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maximum notifications per hour',
                      style: TextStyle(fontSize: 13, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _settings.frequencyLimitPerHour.toDouble(),
                      min: 1,
                      max: 50,
                      divisions: 49,
                      label: '${_settings.frequencyLimitPerHour} per hour',
                      onChanged: (val) {
                        setState(() => _settings.frequencyLimitPerHour = val.toInt());
                      },
                    ),
                    Center(
                      child: Text(
                        '${_settings.frequencyLimitPerHour} notifications per hour',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Settings',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // Update provider settings
      notificationProvider.updateOrderUpdates(_settings.orderUpdates);
      notificationProvider.updatePromotions(_settings.promotions);
      notificationProvider.updatePriceDrops(_settings.priceDrops);
      notificationProvider.updateShopUpdates(_settings.shopUpdates);
      notificationProvider.updateSystemMessages(_settings.systemMessages);
      notificationProvider.updateQuietHours(_settings.quietHoursStart, _settings.quietHoursEnd);
      notificationProvider.updateFrequencyLimit(_settings.frequencyLimitPerHour);

      // Save to Firestore
      await notificationProvider.saveSettings(user.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving settings: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.grey500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.grey500)),
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primary,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        if (title != 'System Messages') const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildTimePickerButton(String label, TimeOfDay time, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.grey600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.grey300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.access_time, size: 18, color: AppTheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
