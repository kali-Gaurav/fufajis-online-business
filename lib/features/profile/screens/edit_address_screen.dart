import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_address.dart';
import '../providers/profile_provider.dart';
import '../utils/profile_validator.dart';

class EditAddressScreen extends ConsumerStatefulWidget {
  final CustomerAddress? address; // null means new address

  const EditAddressScreen({super.key, this.address});

  @override
  ConsumerState<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends ConsumerState<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _recipientNameController;
  late TextEditingController _phoneController;
  late TextEditingController _houseNumberController;
  late TextEditingController _streetController;
  late TextEditingController _landmarkController;
  late TextEditingController _villageController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  
  bool _isDefault = false;
  String _label = 'Home';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _recipientNameController = TextEditingController(text: a?.recipientName ?? '');
    _phoneController = TextEditingController(text: a?.phone ?? '');
    _houseNumberController = TextEditingController(text: a?.houseNumber ?? '');
    _streetController = TextEditingController(text: a?.street ?? '');
    _landmarkController = TextEditingController(text: a?.landmark ?? '');
    _villageController = TextEditingController(text: a?.village ?? '');
    _cityController = TextEditingController(text: a?.city ?? '');
    _stateController = TextEditingController(text: a?.state ?? '');
    _postalCodeController = TextEditingController(text: a?.postalCode ?? '');
    _isDefault = a?.isDefault ?? false;
    _label = a?.label ?? 'Home';
    if (_label.isEmpty) _label = 'Home';
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _villageController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'label': _label,
      'recipient_name': _recipientNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'house_number': _houseNumberController.text.trim(),
      'street': _streetController.text.trim(),
      'landmark': _landmarkController.text.trim(),
      'village': _villageController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _stateController.text.trim(),
      'postal_code': _postalCodeController.text.trim(),
      'is_default': _isDefault,
    };

    try {
      if (widget.address == null) {
        await ref.read(profileNotifierProvider.notifier).addAddress(data);
      } else {
        await ref.read(profileNotifierProvider.notifier).updateAddress(widget.address!.id, data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.address == null ? 'Address added' : 'Address updated'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.address == null ? 'Add Address' : 'Edit Address'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveAddress,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientNameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (val) => ProfileValidator.validateRequired(val, 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), prefixText: '+91 '),
              keyboardType: TextInputType.phone,
              validator: ProfileValidator.validatePhone,
            ),
            
            const SizedBox(height: 24),
            const Text('Address Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _houseNumberController,
              decoration: const InputDecoration(labelText: 'House No.', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(labelText: 'Street', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _villageController,
              decoration: const InputDecoration(labelText: 'Village / Area', border: OutlineInputBorder()),
              validator: (val) => ProfileValidator.validateRequired(val, 'Village / Area'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _landmarkController,
              decoration: const InputDecoration(labelText: 'Landmark', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                    validator: (val) => ProfileValidator.validateRequired(val, 'City'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                    validator: (val) => ProfileValidator.validateRequired(val, 'State'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalCodeController,
              decoration: const InputDecoration(labelText: 'PIN Code', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: ProfileValidator.validatePinCode,
            ),
            
            const SizedBox(height: 24),
            const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            DropdownButtonFormField<String>(
              value: _label,
              decoration: const InputDecoration(labelText: 'Save As', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Home', child: Text('Home')),
                DropdownMenuItem(value: 'Work', child: Text('Work')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _label = val);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Set as default address'),
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
