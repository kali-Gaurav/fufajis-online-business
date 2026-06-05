import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/shop_config_model.dart';

class OperatingHoursScreen extends StatefulWidget {
  const OperatingHoursScreen({super.key});

  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  Future<void> _selectTime(BuildContext context, String day, bool isOpenTime, String currentTime) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    final config = provider.shopConfig;
    if (config == null) return;

    final parts = currentTime.split(':');
    final initialHour = int.tryParse(parts.first) ?? 9;
    final initialMinute = int.tryParse(parts.last) ?? 0;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final formattedTime = '$hourStr:$minuteStr';

      final currentDayHours = config.operatingHours[day] ??
          OperatingHours(isOpen: true, openTime: '09:00', closeTime: '21:00');

      final updatedDayHours = isOpenTime
          ? OperatingHours(
              isOpen: currentDayHours.isOpen,
              openTime: formattedTime,
              closeTime: currentDayHours.closeTime,
            )
          : OperatingHours(
              isOpen: currentDayHours.isOpen,
              openTime: currentDayHours.openTime,
              closeTime: formattedTime,
            );

      await provider.updateOperatingHours(day, updatedDayHours);
    }
  }

  void _applyToAll(String sourceDay) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    final config = provider.shopConfig;
    if (config == null) return;

    final sourceHours = config.operatingHours[sourceDay] ??
        OperatingHours(isOpen: true, openTime: '09:00', closeTime: '21:00');

    try {
      final Map<String, OperatingHours> newHoursMap = {};
      for (var day in _days) {
        final current = config.operatingHours[day];
        newHoursMap[day] = OperatingHours(
          isOpen: current?.isOpen ?? true,
          openTime: sourceHours.openTime,
          closeTime: sourceHours.closeTime,
        );
      }

      await provider.updateShopConfig(config.copyWith(operatingHours: newHoursMap));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied times (${sourceHours.openTime} - ${sourceHours.closeTime}) to all days'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShopConfigProvider>(context);
    final config = provider.shopConfig;

    if (config == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Hours', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Switch for auto close
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text('Auto-Close Outside Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Automatically marks the shop as closed in the customer app outside operating hours.'),
                value: config.autoCloseOutsideHours,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) async {
                  await provider.updateShopConfig(config.copyWith(autoCloseOutsideHours: val));
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Weekly Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _days.length,
              itemBuilder: (context, index) {
                final day = _days[index];
                final hours = config.operatingHours[day] ??
                    OperatingHours(isOpen: true, openTime: '09:00', closeTime: '21:00');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hours.isOpen ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: hours.isOpen ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: hours.isOpen
                              ? Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _selectTime(context, day, true, hours.openTime),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          hours.openTime,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('to'),
                                    ),
                                    InkWell(
                                      onTap: () => _selectTime(context, day, false, hours.closeTime),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          hours.closeTime,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(),
                        ),
                        Row(
                          children: [
                            if (hours.isOpen)
                              IconButton(
                                icon: const Icon(Icons.copy_all, color: Colors.blueAccent, size: 20),
                                onPressed: () => _applyToAll(day),
                                tooltip: 'Apply these times to all days',
                              ),
                            Switch(
                              value: hours.isOpen,
                              activeThumbColor: AppTheme.primary,
                              onChanged: (val) async {
                                final updated = OperatingHours(
                                  isOpen: val,
                                  openTime: hours.openTime,
                                  closeTime: hours.closeTime,
                                );
                                await provider.updateOperatingHours(day, updated);
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
