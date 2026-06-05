import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/user_model.dart';
import 'map_picker_screen.dart';

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  bool _isFormOpen = false;
  bool _isLoading = false;
  List<Address> _addresses = [];
  Address? _editingAddress;

  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _fullAddressController = TextEditingController();
  final _villageController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  bool _isDefault = false;
  double? _capturedLatitude;
  double? _capturedLongitude;
  String _addressType = 'House'; // Step 18.3
  
  // Voice Tagging (Step 18.1)
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _voiceTagPath;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _voiceTagPath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/address_tag_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _voiceTagPath = null;
        });
      }
    }
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final list = await authProvider.getAddresses();
    setState(() {
      _addresses = list;
      _isLoading = false;
    });
  }

  void _openAddressForm([Address? address]) {
    if (address != null) {
      _editingAddress = address;
      _labelController.text = address.label;
      _fullAddressController.text = address.fullAddress;
      _villageController.text = address.village;
      _landmarkController.text = address.landmark;
      _pincodeController.text = address.pincode;
      _isDefault = address.isDefault;
      _deliveryInstructionsController.text = address.deliveryInstructions ?? '';
      _capturedLatitude = address.latitude;
      _capturedLongitude = address.longitude;
      _addressType = address.id.contains('shop') ? 'Shop' : address.id.contains('apt') ? 'Apartment' : 'House';
    } else {
      _editingAddress = null;
      _labelController.text = 'Home';
      _fullAddressController.clear();
      _villageController.clear();
      _landmarkController.clear();
      _pincodeController.clear();
      _isDefault = false;
      _deliveryInstructionsController.clear();
      _capturedLatitude = null;
      _capturedLongitude = null;
      _addressType = 'House';
    }
    setState(() => _isFormOpen = true);
  }

  void _closeAddressForm() {
    setState(() => _isFormOpen = false);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _fullAddressController.dispose();
    _villageController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          if (!_isFormOpen)
            TextButton.icon(
              onPressed: () => _openAddressForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isFormOpen
              ? _buildAddressForm()
              : _buildAddressesList(),
    );
  }

  Widget _buildAddressesList() {
    if (_addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: AppTheme.grey400),
              const SizedBox(height: 16),
              const Text(
                'No Saved Addresses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add shipping addresses to speed up your checkout process next time.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.grey500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openAddressForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Shipping Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final address = _addresses[index];
        return _buildAddressCard(address);
      },
    );
  }

  Widget _buildAddressCard(Address address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: address.isDefault
            ? Border.all(color: AppTheme.primary, width: 2)
            : Border.all(color: AppTheme.grey200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: address.isDefault ? AppTheme.primary : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForLabel(address.label),
                      size: 16,
                      color: address.isDefault ? Colors.white : AppTheme.grey700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      address.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: address.isDefault ? Colors.white : AppTheme.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              if (address.isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              const Spacer(),
              // Actions Button Menu
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 20),
                onPressed: () => _openAddressForm(address),
                tooltip: 'Edit Address',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                onPressed: () => _confirmDeleteAddress(address.id),
                tooltip: 'Delete Address',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            address.fullAddress,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.grey900,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (address.village.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_city, size: 14, color: AppTheme.grey500),
                const SizedBox(width: 6),
                Text(
                  'Village/Colony: ${address.village}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                ),
              ],
            ),
          const SizedBox(height: 4),
          if (address.landmark.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.my_location, size: 14, color: AppTheme.grey500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Landmark: ${address.landmark}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.pin_drop, size: 14, color: AppTheme.grey500),
              const SizedBox(width: 6),
              Text(
                'PIN Code: ${address.pincode}',
                style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
              ),
            ],
          ),
          if (address.deliveryInstructions != null && address.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.deliveryInstructions!,
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!address.isDefault) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _setDefaultAddress(address.id),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Set as Default'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          ],
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    if (l.contains('home')) return Icons.home;
    if (l.contains('work') || l.contains('office')) return Icons.business;
    if (l.contains('farm')) return Icons.agriculture;
    return Icons.location_on;
  }

  Future<void> _setDefaultAddress(String addressId) async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.setDefaultAddress(addressId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default address updated!')),
        );
      }
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAddress(String addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address preset?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      try {
        await authProvider.deleteAddress(addressId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted!')),
          );
        }
        await _loadAddresses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildAddressForm() {
    final isEditing = _editingAddress != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _closeAddressForm,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.grey100),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Address' : 'Add New Address',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Step 18.3: Address Type Classification
              const Text('Property Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: ['House', 'Apartment', 'Shop'].map((type) {
                  final isSelected = _addressType == type;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Center(child: Text(type)),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _addressType = type),
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.grey700),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Quick Preset Chips
              const Text('Address Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Home', 'Work', 'Village-Home', 'Farm'].map((label) {
                  final isSelected = _labelController.text == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _labelController.text = label);
                      }
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                    backgroundColor: AppTheme.grey100,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.grey700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Custom Label (e.g., Shop)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please specify label' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'House No. / Building / Street',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_work_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter address details' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                decoration: const InputDecoration(
                  labelText: 'Village or Colony Name',
                  hintText: 'e.g. Govindgarh, Ward No. 5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter village/colony' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: 'Landmark (Highly Recommended)',
                  hintText: 'e.g. Near Water Tank, Opp. Primary School',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assistant_navigation),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Landmark helps rider find you faster' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN Code (6-digit)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return 'Please enter valid 6-digit PIN code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Map Pin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Use GPS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              if (_capturedLatitude != null && _capturedLongitude != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'GPS Captured: ${_capturedLatitude!.toStringAsFixed(5)}, ${_capturedLongitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              
              // Step 18.1: Voice Tagging UI
              const Text('Voice Instructions (for Rider)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _toggleRecording,
                      icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic, color: _isRecording ? Colors.red : AppTheme.primary),
                      iconSize: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isRecording 
                            ? 'Recording... Tap to Stop' 
                            : _voiceTagPath != null 
                                ? 'Voice Tag Attached âœ…' 
                                : 'Record direction hints (e.g. "Behind the big Banyan tree")',
                        style: TextStyle(fontSize: 12, color: _isRecording ? Colors.red : AppTheme.grey600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _deliveryInstructionsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Delivery Instructions (Optional)',
                  hintText: 'e.g., Leave at the door, call before arriving',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_bike),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Set as default shipping address', style: TextStyle(fontWeight: FontWeight.w500)),
                value: _isDefault,
                onChanged: (val) => setState(() => _isDefault = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  isEditing ? 'Update Address' : 'Save Address',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLat: _capturedLatitude ?? 26.9124,
          initialLng: _capturedLongitude ?? 75.7873,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _capturedLatitude = result['lat'];
        _capturedLongitude = result['lng'];
        _fullAddressController.text = result['address'];
      });
      
      // Auto-extract pincode if possible from address
      final RegExp pincodeRegex = RegExp(r'\b\d{6}\b');
      final match = pincodeRegex.firstMatch(result['address']);
      if (match != null) {
        _pincodeController.text = match.group(0)!;
      }
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final String idSuffix = _addressType == 'Shop' ? '_shop' : _addressType == 'Apartment' ? '_apt' : '_house';
      final address = Address(
        id: _editingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}$idSuffix',
        label: _labelController.text.trim(),
        fullAddress: _fullAddressController.text.trim(),
        village: _villageController.text.trim(),
        landmark: _landmarkController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: _capturedLatitude ?? _editingAddress?.latitude ?? 26.9124,
        longitude: _capturedLongitude ?? _editingAddress?.longitude ?? 75.7873,
        isDefault: _isDefault,
        deliveryInstructions: _deliveryInstructionsController.text.trim(),
      );

      if (_editingAddress != null) {
        await authProvider.updateAddress(_editingAddress!.id, address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address updated successfully!')),
          );
        }
      } else {
        await authProvider.addAddress(address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address saved successfully!')),
          );
        }
      }

      _closeAddressForm();
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);

    try {
      await locationProvider.getCurrentLocation();
      if (locationProvider.currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(locationProvider.errorMessage ?? 'Unable to get location'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _capturedLatitude = locationProvider.latitude;
          _capturedLongitude = locationProvider.longitude;
          if (locationProvider.currentAddress.isNotEmpty) {
            _fullAddressController.text = locationProvider.currentAddress;
          }
          if (locationProvider.pincode.isNotEmpty) {
            _pincodeController.text = locationProvider.pincode;
          }
        });
      }

      final probeAddress = Address(
        id: 'probe',
        label: _labelController.text.trim().isEmpty
            ? 'Home'
            : _labelController.text.trim(),
        fullAddress: _fullAddressController.text.trim(),
        village: _villageController.text.trim(),
        landmark: _landmarkController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: _capturedLatitude!,
        longitude: _capturedLongitude!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationProvider.deliveryZoneMessageFor(probeAddress)),
            backgroundColor: locationProvider
                    .isAddressWithinDeliveryRadius(probeAddress)
                ? AppTheme.success
                : AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

