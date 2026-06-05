import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/shop_config_model.dart';
import '../../models/shop_branch_model.dart';

class DeliveryZonesScreen extends StatefulWidget {
  final ShopBranchModel? branch; // Null if main shop
  const DeliveryZonesScreen({super.key, this.branch});

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _chargeController = TextEditingController();
  final _minOrderFreeController = TextEditingController();

  DeliveryZone? _editingZone;

  @override
  void dispose() {
    _labelController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _chargeController.dispose();
    _minOrderFreeController.dispose();
    super.dispose();
  }

  void _showZoneForm({DeliveryZone? zone}) {
    _editingZone = zone;
    if (zone != null) {
      _labelController.text = zone.label;
      _fromController.text = zone.fromRadiusKm.toString();
      _toController.text = zone.toRadiusKm.toString();
      _chargeController.text = zone.deliveryCharge.toString();
      _minOrderFreeController.text = zone.minOrderForFree.toString();
    } else {
      _labelController.clear();
      _fromController.clear();
      _toController.clear();
      _chargeController.clear();
      _minOrderFreeController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      zone == null ? 'Add Delivery Zone' : 'Edit Delivery Zone',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Label / Name',
                    hintText: 'e.g. Zone 1 - Nearby',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a label' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromController,
                        decoration: const InputDecoration(
                          labelText: 'From Distance (km)',
                          hintText: 'e.g. 0.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _toController,
                        decoration: const InputDecoration(
                          labelText: 'To Distance (km)',
                          hintText: 'e.g. 3.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) {
                            return 'Invalid number';
                          }
                          final from = double.tryParse(_fromController.text) ?? 0.0;
                          final to = double.tryParse(v) ?? 0.0;
                          if (to <= from) {
                            return 'Must be > From';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _chargeController,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Charge (₹)',
                          hintText: 'e.g. 30.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid number' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderFreeController,
                        decoration: const InputDecoration(
                          labelText: 'Free if Order > (₹)',
                          hintText: 'e.g. 500.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid number' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveZone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    zone == null ? 'Add Zone' : 'Update Zone',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveZone() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<ShopConfigProvider>(context, listen: false);

    final fromRadius = double.parse(_fromController.text);
    final toRadius = double.parse(_toController.text);
    final charge = double.parse(_chargeController.text);
    final minOrderFree = double.parse(_minOrderFreeController.text);
    final label = _labelController.text.trim();

    // Validate overlaps and ordering
    final zones = widget.branch?.deliveryZones ?? provider.shopConfig?.deliveryZones ?? [];
    final List<DeliveryZone> tempZones = List.from(zones);
    if (_editingZone != null) {
      tempZones.removeWhere((z) => z.id == _editingZone!.id);
    }
    tempZones.add(DeliveryZone(
      id: 'temp',
      label: label,
      fromRadiusKm: fromRadius,
      toRadiusKm: toRadius,
      deliveryCharge: charge,
      minOrderForFree: minOrderFree,
      isActive: true,
    ));
    tempZones.sort((a, b) => a.fromRadiusKm.compareTo(b.fromRadiusKm));

    for (int i = 1; i < tempZones.length; i++) {
      final prev = tempZones[i - 1];
      final curr = tempZones[i];
      if (curr.fromRadiusKm < prev.toRadiusKm) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zone overlap detected! "${curr.label}" starts at ${curr.fromRadiusKm} km, which is less than preceding zone "${prev.label}" ending at ${prev.toRadiusKm} km.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final zone = DeliveryZone(
      id: _editingZone?.id ?? 'zone_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      fromRadiusKm: fromRadius,
      toRadiusKm: toRadius,
      deliveryCharge: charge,
      minOrderForFree: minOrderFree,
      isActive: _editingZone?.isActive ?? true,
    );

    try {
      if (widget.branch != null) {
        final List<DeliveryZone> updatedZones = List.from(widget.branch!.deliveryZones);
        if (_editingZone == null) {
          updatedZones.add(zone);
        } else {
          final idx = updatedZones.indexWhere((element) => element.id == _editingZone!.id);
          updatedZones[idx] = zone;
        }
        double maxRadius = widget.branch!.deliveryRadiusKm;
        for (var z in updatedZones) {
          if (z.isActive && z.toRadiusKm > maxRadius) {
            maxRadius = z.toRadiusKm;
          }
        }
        await provider.updateBranch(widget.branch!.copyWith(
          deliveryZones: updatedZones,
          deliveryRadiusKm: maxRadius,
        ));
      } else {
        if (_editingZone == null) {
          await provider.addDeliveryZone(zone);
        } else {
          await provider.updateDeliveryZone(zone);
        }
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery zone saved successfully!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving zone: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteZone(String id) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    try {
      if (widget.branch != null) {
        final List<DeliveryZone> updatedZones = widget.branch!.deliveryZones.where((z) => z.id != id).toList();
        double maxRadius = 0.0;
        for (var z in updatedZones) {
          if (z.isActive && z.toRadiusKm > maxRadius) {
            maxRadius = z.toRadiusKm;
          }
        }
        await provider.updateBranch(widget.branch!.copyWith(
          deliveryZones: updatedZones,
          deliveryRadiusKm: maxRadius > 0.0 ? maxRadius : widget.branch!.deliveryRadiusKm,
        ));
      } else {
        await provider.removeDeliveryZone(id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zone deleted!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _toggleZoneActive(DeliveryZone zone) async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    final updatedZone = zone.copyWith(isActive: !zone.isActive);
    try {
      if (widget.branch != null) {
        final List<DeliveryZone> updatedZones = widget.branch!.deliveryZones.map((z) {
          return z.id == zone.id ? updatedZone : z;
        }).toList();
        await provider.updateBranch(widget.branch!.copyWith(deliveryZones: updatedZones));
      } else {
        await provider.updateDeliveryZone(updatedZone);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShopConfigProvider>(context);
    final zones = widget.branch != null ? widget.branch!.deliveryZones : (provider.shopConfig?.deliveryZones ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.branch != null ? '${widget.branch!.branchName} - Delivery Zones' : 'Delivery Zones Configuration',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showZoneForm(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Zone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: zones.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No Delivery Zones Defined', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('Define concentric circles around the shop for zone pricing.', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: zones.length,
              itemBuilder: (context, index) {
                final zone = zones[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              zone.label,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Switch(
                              value: zone.isActive,
                              onChanged: (_) => _toggleZoneActive(zone),
                              activeThumbColor: AppTheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Range', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  '${zone.fromRadiusKm} km - ${zone.toRadiusKm} km',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Charge', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  zone.deliveryCharge == 0 ? 'FREE' : '₹${zone.deliveryCharge}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: zone.deliveryCharge == 0 ? Colors.green : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Free Order Limit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${zone.minOrderForFree}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _showZoneForm(zone: zone),
                              tooltip: 'Edit Zone',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteZone(zone.id),
                              tooltip: 'Delete Zone',
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
