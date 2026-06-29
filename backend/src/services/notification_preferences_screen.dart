/// ============================================================================
/// notification_preferences_screen.dart - Notification Settings UI
/// ============================================================================
/// Features:
/// - Enable/disable notifications by category (orders, promos, reviews, etc.)
/// - Choose notification channels (push, email, SMS)
/// - Set quiet hours
/// - Email frequency settings
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Map<String, dynamic> preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notification_preferences')
          .get();

      setState(() {
        preferences = doc.exists
            ? doc.data() ?? _defaultPreferences()
            : _defaultPreferences();
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading preferences: $error');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _defaultPreferences() {
    return {
      'channels': {
        'push': {
          'orders': true,
          'promotions': true,
          'reviews': true,
          'payments': true,
          'inventory': false,
        },
        'email': {
          'orders': true,
          'promotions': false,
          'reviews': false,
          'payments': true,
          'inventory': false,
        },
        'sms': {
          'orders': false,
          'promotions': false,
          'reviews': false,
          'payments': false,
          'inventory': false,
        },
      },
      'quietHours': {
        'enabled': false,
        'startHour': 22,
        'endHour': 8,
      },
      'emailFrequency': 'daily',
    };
  }

  Future<void> _savePreferences() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notification_preferences')
          .set(preferences, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $error')),
      );
    }
  }

  void _toggleChannel(String channel, String category, bool value) {
    setState(() {
      preferences['channels'][channel][category] = value;
    });
  }

  void _setQuietHours(bool enabled, int? startHour, int? endHour) {
    setState(() {
      preferences['quietHours']['enabled'] = enabled;
      if (startHour != null) {
        preferences['quietHours']['startHour'] = startHour;
      }
      if (endHour != null) {
        preferences['quietHours']['endHour'] = endHour;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final channels = preferences['channels'] as Map<String, dynamic>;
    final quietHours = preferences['quietHours'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // PUSH NOTIFICATIONS
            _buildChannelSection(
              'Push Notifications',
              'Alerts on your phone',
              'push',
              channels['push'] as Map<String, dynamic>,
            ),

            // EMAIL NOTIFICATIONS
            _buildChannelSection(
              'Email Notifications',
              'Messages to your inbox',
              'email',
              channels['email'] as Map<String, dynamic>,
            ),

            // SMS NOTIFICATIONS
            _buildChannelSection(
              'SMS Notifications',
              'Text messages',
              'sms',
              channels['sms'] as Map<String, dynamic>,
            ),

            // QUIET HOURS
            _buildQuietHoursSection(quietHours),

            // EMAIL FREQUENCY
            _buildEmailFrequencySection(),

            // SAVE BUTTON
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _savePreferences,
                icon: const Icon(Icons.save),
                label: const Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSection(
    String title,
    String subtitle,
    String channelKey,
    Map<String, dynamic> categoryMap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ...categoryMap.entries.map((entry) {
          final category = entry.key;
          final enabled = entry.value as bool;

          return CheckboxListTile(
            title: Text(_getCategoryLabel(category)),
            subtitle: Text(_getCategoryDescription(category)),
            value: enabled,
            onChanged: (value) {
              if (value != null) {
                _toggleChannel(channelKey, category, value);
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildQuietHoursSection(Map<String, dynamic> quietHours) {
    final enabled = quietHours['enabled'] as bool;
    final startHour = quietHours['startHour'] as int;
    final endHour = quietHours['endHour'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quiet Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No notifications outside these hours (except high priority)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Enable Quiet Hours'),
          value: enabled,
          onChanged: (value) {
            _setQuietHours(value, null, null);
          },
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time'),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: startHour,
                        items: List.generate(24, (i) => i)
                            .map((hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _setQuietHours(true, value, null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time'),
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        isExpanded: true,
                        value: endHour,
                        items: List.generate(24, (i) => i)
                            .map((hour) => DropdownMenuItem(
                                  value: hour,
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _setQuietHours(true, null, value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmailFrequencySection() {
    final frequency = preferences['emailFrequency'] as String;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email Frequency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How often to receive summary emails',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        RadioListTile(
          title: const Text('Daily'),
          value: 'daily',
          groupValue: frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() => preferences['emailFrequency'] = value);
            }
          },
        ),
        RadioListTile(
          title: const Text('Weekly'),
          value: 'weekly',
          groupValue: frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() => preferences['emailFrequency'] = value);
            }
          },
        ),
        RadioListTile(
          title: const Text('Never'),
          value: 'never',
          groupValue: frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() => preferences['emailFrequency'] = value);
            }
          },
        ),
      ],
    );
  }

  String _getCategoryLabel(String category) {
    const labels = {
      'orders': 'Order Updates',
      'promotions': 'Promotions & Offers',
      'reviews': 'Reviews & Feedback',
      'payments': 'Payments & Refunds',
      'inventory': 'Inventory Alerts',
    };
    return labels[category] ?? category;
  }

  String _getCategoryDescription(String category) {
    const descriptions = {
      'orders': 'Order confirmation, delivery status, etc.',
      'promotions': 'Special offers and discounts',
      'reviews': 'Requests to rate your experience',
      'payments': 'Payment confirmations and refunds',
      'inventory': 'Items back in stock',
    };
    return descriptions[category] ?? '';
  }
}
