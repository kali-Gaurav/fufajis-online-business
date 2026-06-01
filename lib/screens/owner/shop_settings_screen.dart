import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/shop_config_model.dart';
import 'shop_location_picker_screen.dart';
import 'delivery_zones_screen.dart';
import 'branch_management_screen.dart';
import 'operating_hours_screen.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  late TextEditingController _minOrderController;
  late TextEditingController _flatFeeController;
  
  late TextEditingController _codLimitController;
  late TextEditingController _creditLimitController;
  late TextEditingController _cashbackPctController;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final config = Provider.of<ShopConfigProvider>(context).shopConfig;
      if (config != null) {
        _nameController = TextEditingController(text: config.shopName);
        _addressController = TextEditingController(text: config.shopAddress);
        _phoneController = TextEditingController(text: config.shopPhone);
        _emailController = TextEditingController(text: config.shopEmail);
        
        _minOrderController = TextEditingController(text: config.minOrderAmount.toString());
        _flatFeeController = TextEditingController(text: config.flatDeliveryFee.toString());
        
        _codLimitController = TextEditingController(text: config.maxCodLimit.toString());
        _creditLimitController = TextEditingController(text: config.maxCreditLimit.toString());
        _cashbackPctController = TextEditingController(text: config.cashbackPercentage.toString());
        
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _nameController.dispose();
      _addressController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _minOrderController.dispose();
      _flatFeeController.dispose();
      _codLimitController.dispose();
      _creditLimitController.dispose();
      _cashbackPctController.dispose();
    }
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    final config = provider.shopConfig;
    if (config == null) return;

    final updatedConfig = config.copyWith(
      shopName: _nameController.text.trim(),
      shopAddress: _addressController.text.trim(),
      shopPhone: _phoneController.text.trim(),
      shopEmail: _emailController.text.trim(),
      minOrderAmount: double.parse(_minOrderController.text),
      flatDeliveryFee: double.parse(_flatFeeController.text),
      maxCodLimit: double.parse(_codLimitController.text),
      maxCreditLimit: double.parse(_creditLimitController.text),
      cashbackPercentage: double.parse(_cashbackPctController.text),
    );

    try {
      await provider.updateShopConfig(updatedConfig);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.red),
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
        title: const Text('Shop Settings & Configurations', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: AppTheme.primary),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Shop Open status status
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: SwitchListTile(
                  title: const Text('Shop Open for Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: const Text('Toggle whether customers can place orders right now.'),
                  value: config.isOpen,
                  activeColor: AppTheme.success,
                  inactiveThumbColor: AppTheme.error,
                  onChanged: (val) => provider.setShopOpen(val),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 4,
                color: config.isEmergencyMode ? Colors.red.shade50 : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: config.isEmergencyMode
                      ? BorderSide(color: Colors.red.shade300, width: 2)
                      : BorderSide.none,
                ),
                child: SwitchListTile(
                  title: const Text(
                    '⚠️ EMERGENCY OPERATIONS MODE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                  ),
                  subtitle: const Text(
                    'Activates emergency protocols (limits capacities, disables express orders, prioritizes pickup-first).',
                  ),
                  value: config.isEmergencyMode,
                  activeColor: Colors.red,
                  onChanged: (val) => provider.toggleEmergencyMode(),
                ),
              ),
              const SizedBox(height: 16),

              // Shop Profile Info
              _buildSectionHeader('Store Identity & Profile'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Shop Name'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Shop Address'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter address' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number'),
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email Address'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location & Zones Config
              _buildSectionHeader('Delivery Zone Settings'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map, color: AppTheme.primary),
                      title: const Text('Location Picker & Delivery Radius'),
                      subtitle: Text('${config.shopLatitude.toStringAsFixed(4)}, ${config.shopLongitude.toStringAsFixed(4)} (Radius: ${config.maxDeliveryRadiusKm}km)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ShopLocationPickerScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delivery_dining, color: Colors.orange),
                      title: const Text('Concentric Delivery Slabs (Zones)'),
                      subtitle: Text('${config.deliveryZones.length} Zones defined'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DeliveryZonesScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.store, color: Colors.blue),
                      title: const Text('Multi-Branch Management'),
                      subtitle: Text('${provider.branches.length} Branches added'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const BranchManagementScreen()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer, color: Colors.teal),
                      title: const Text('Operating Hours Schedule'),
                      subtitle: const Text('Configure shop opening/closing hours per day'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const OperatingHoursScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Pricing and Limits
              _buildSectionHeader('Pricing & Limit Thresholds'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minOrderController,
                              decoration: const InputDecoration(labelText: 'Min Order Amount (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _flatFeeController,
                              decoration: const InputDecoration(labelText: 'Fallback Flat Delivery (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codLimitController,
                              decoration: const InputDecoration(labelText: 'Max COD Limit (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _creditLimitController,
                              decoration: const InputDecoration(labelText: 'Max Khata/Credit Limit (₹)'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Autopilot and Cashback
              _buildSectionHeader('Business Engines (Autopilot & Cashback)'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Autopilot Dynamic Pricing'),
                      subtitle: const Text('Automatically updates product rates matching wholesale Mandi prices.'),
                      value: config.isAutoPilotEnabled,
                      activeColor: AppTheme.primary,
                      onChanged: (val) async {
                        await provider.updateShopConfig(config.copyWith(isAutoPilotEnabled: val));
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Enable Cashback rewards'),
                      subtitle: const Text('Give rewards to customers on successful order completions.'),
                      value: config.enableCashback,
                      activeColor: AppTheme.primary,
                      onChanged: (val) async {
                        await provider.updateShopConfig(config.copyWith(enableCashback: val));
                      },
                    ),
                    if (config.enableCashback)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: TextFormField(
                          controller: _cashbackPctController,
                          decoration: const InputDecoration(labelText: 'Cashback Percentage (%)', hintText: 'e.g. 5.0'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Save All Configurations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
      ),
    );
  }
}
