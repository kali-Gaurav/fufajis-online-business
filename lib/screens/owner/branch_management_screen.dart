import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/shop_branch_model.dart';
import '../../models/shop_config_model.dart';
import 'shop_location_picker_screen.dart';
import 'delivery_zones_screen.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _managerController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _managerController.dispose();
    super.dispose();
  }

  void _showBranchDialog({ShopBranchModel? branch}) {
    if (branch != null) {
      _nameController.text = branch.branchName;
      _phoneController.text = branch.contactPhone ?? '';
      _managerController.text = branch.managerId ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
      _managerController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(branch == null ? 'Add Branch' : 'Edit Branch Details'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  hintText: 'e.g. Vaishali Nagar Branch',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  hintText: '+91 98765 43210',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _managerController,
                decoration: const InputDecoration(
                  labelText: 'Manager User ID',
                  hintText: 'Auth User ID of manager',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => _saveBranch(branch: branch),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveBranch({ShopBranchModel? branch}) async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<ShopConfigProvider>(context, listen: false);

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    final String manager = _managerController.text.trim();

    final newBranch = ShopBranchModel(
      id: branch?.id ?? 'branch_${DateTime.now().millisecondsSinceEpoch}',
      branchName: name,
      branchAddress: branch?.branchAddress ?? 'Jaipur, Rajasthan',
      latitude: branch?.latitude ?? 26.9124,
      longitude: branch?.longitude ?? 75.7873,
      deliveryRadiusKm: branch?.deliveryRadiusKm ?? 8.0,
      deliveryZones:
          branch?.deliveryZones ??
          [
            DeliveryZone(
              id: 'zone_b1',
              label: 'Branch Zone 1 - Free (0-3 km)',
              fromRadiusKm: 0.0,
              toRadiusKm: 3.0,
              deliveryCharge: 0.0,
              minOrderForFree: 300.0,
              isActive: true,
            ),
          ],
      isPrimary: branch?.isPrimary ?? false,
      isActive: branch?.isActive ?? true,
      contactPhone: phone.isEmpty ? null : phone,
      managerId: manager.isEmpty ? null : manager,
      operatingHours: branch?.operatingHours ?? _getDefaultHours(),
    );

    try {
      if (branch == null) {
        await provider.addBranch(newBranch);
      } else {
        await provider.updateBranch(newBranch);
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch saved!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save branch: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Map<String, OperatingHours> _getDefaultHours() {
    final Map<String, OperatingHours> hours = {};
    for (var day in [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      hours[day] = OperatingHours(isOpen: true, openTime: '09:00', closeTime: '21:00');
    }
    return hours;
  }

  void _deleteBranch(String id) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    try {
      await provider.removeBranch(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch removed!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete branch: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _toggleBranchActive(ShopBranchModel branch) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    try {
      await provider.updateBranch(branch.copyWith(isActive: !branch.isActive));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _setBranchPrimary(ShopBranchModel branch) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    try {
      // Set all other branches to primary = false, then set this to true
      for (var b in provider.branches) {
        if (b.id != branch.id && b.isPrimary) {
          await provider.updateBranch(b.copyWith(isPrimary: false));
        }
      }
      await provider.updateBranch(branch.copyWith(isPrimary: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch designated as Primary!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShopConfigProvider>(context);
    final branches = provider.branches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Management', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text(
          'Add Branch',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: branches.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Branches Configured',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up additional branch locations to cover more areas.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final b = branches[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  b.branchName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (b.isPrimary)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PRIMARY',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Switch(
                              value: b.isActive,
                              onChanged: (_) => _toggleBranchActive(b),
                              activeThumbColor: AppTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                b.branchAddress,
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (b.contactPhone != null)
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                b.contactPhone!,
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        // Actions row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ShopLocationPickerScreen(branch: b),
                                    ),
                                  ),
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('Map & Radius'),
                                ),
                                TextButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DeliveryZonesScreen(branch: b),
                                    ),
                                  ),
                                  icon: const Icon(Icons.delivery_dining, size: 16),
                                  label: const Text('Zones'),
                                ),
                              ],
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showBranchDialog(branch: b);
                                } else if (val == 'primary') {
                                  _setBranchPrimary(b);
                                } else if (val == 'delete') {
                                  _deleteBranch(b.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Info')),
                                if (!b.isPrimary)
                                  const PopupMenuItem(
                                    value: 'primary',
                                    child: Text('Set as Primary'),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete Branch',
                                    style: TextStyle(color: AppTheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
