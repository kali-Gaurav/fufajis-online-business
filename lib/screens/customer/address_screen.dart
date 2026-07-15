import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/user_model.dart';
import 'map_picker_screen.dart';
import '../../l10n/app_localizations.dart';

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
  bool _isResolvingLink = false;
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
    _fullAddressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    final text = _fullAddressController.text;
    if (_isResolvingLink) return;

    final bool hasGmaps = text.contains('google.com/maps') ||
        text.contains('maps.app.goo.gl') ||
        text.contains('goo.gl/maps');
    
    final bool hasCoordinates = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)').hasMatch(text);

    if (hasGmaps || hasCoordinates) {
      _checkAndHandleGoogleMapsLink(text);
    }
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
      _addressType = address.id.contains('shop')
          ? 'Shop'
          : address.id.contains('apt')
          ? 'Apartment'
          : 'House';
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
    _fullAddressController.removeListener(_onAddressChanged);
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.translate('savedAddresses'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppTheme.cream,
        foregroundColor: isDark ? Colors.white : AppTheme.grey900,
        elevation: 0,
        actions: [
          if (!_isFormOpen)
            TextButton.icon(
              onPressed: () => _openAddressForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                l10n.translate('addNew'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _isFormOpen
          ? _buildAddressForm()
          : _buildAddressesList(),
    );
  }

  Widget _buildAddressesList() {
    final l10n = AppLocalizations.of(context)!;
    if (_addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: AppTheme.grey400),
              const SizedBox(height: 16),
              Text(
                l10n.translate('noSavedAddresses'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('noSavedAddressesSubtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.grey500),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openAddressForm(),
                icon: const Icon(Icons.add),
                label: Text(l10n.translate('addShippingAddress')),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: address.isDefault
            ? Border.all(color: AppTheme.primary, width: 2)
            : Border.all(color: isDark ? AppTheme.grey800 : AppTheme.grey200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: address.isDefault ? AppTheme.primary : (isDark ? AppTheme.grey900 : AppTheme.grey100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIconForLabel(address.label),
                      size: 16,
                      color: address.isDefault ? Colors.white : (isDark ? AppTheme.grey300 : AppTheme.grey700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getLocalizedLabel(address.label),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: address.isDefault ? Colors.white : (isDark ? AppTheme.grey200 : AppTheme.grey800),
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
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.translate('default'),
                    style: const TextStyle(
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
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.grey900,
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
                  style: TextStyle(fontSize: 13, color: isDark ? AppTheme.grey400 : AppTheme.grey600),
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
                    style: TextStyle(fontSize: 13, color: isDark ? AppTheme.grey400 : AppTheme.grey600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                style: TextStyle(fontSize: 13, color: isDark ? AppTheme.grey400 : AppTheme.grey600),
              ),
            ],
          ),
          if (address.deliveryInstructions != null && address.deliveryInstructions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address.deliveryInstructions!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warning,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
                  label: Text(AppLocalizations.of(context)!.translate('setAsDefault')),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    final l = label.toLowerCase();
    final l10n = AppLocalizations.of(context)!;
    if (l.contains('home') || l == l10n.labelHome.toLowerCase()) return Icons.home;
    if (l.contains('work') || l == l10n.labelWork.toLowerCase() || l.contains('office'))
      return Icons.business;
    if (l.contains('farm') || l == l10n.labelFarm.toLowerCase()) return Icons.agriculture;
    return Icons.location_on;
  }

  String _getLocalizedLabel(String label) {
    final l10n = AppLocalizations.of(context)!;
    switch (label) {
      case 'Home':
        return l10n.labelHome;
      case 'Work':
        return l10n.labelWork;
      case 'Village-Home':
        return l10n.labelVillageHome;
      case 'Farm':
        return l10n.labelFarm;
      default:
        return label;
    }
  }

  Future<void> _setDefaultAddress(String addressId) async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.setDefaultAddress(addressId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Default address updated!')));
      }
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAddress(String addressId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to delete this address preset?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Address deleted!')));
        _loadAddresses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Widget _buildAddressForm() {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = _editingAddress != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.grey900 : AppTheme.grey100,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Address' : 'Add New Address',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Step 18.3: Address Type Classification
              Text(
                l10n.translate('propertyType'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _PropertyTypeChip(
                    label: l10n.typeHouse,
                    value: 'House',
                    groupValue: _addressType,
                    onSelected: (v) => setState(() => _addressType = v),
                  ),
                  _PropertyTypeChip(
                    label: l10n.typeApartment,
                    value: 'Apartment',
                    groupValue: _addressType,
                    onSelected: (v) => setState(() => _addressType = v),
                  ),
                  _PropertyTypeChip(
                    label: l10n.typeShop,
                    value: 'Shop',
                    groupValue: _addressType,
                    onSelected: (v) => setState(() => _addressType = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Quick Preset Chips
              Text(
                l10n.translate('addressType'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LabelPresetChip(
                    label: l10n.labelHome,
                    value: 'Home',
                    current: _labelController.text,
                    onSelected: (v) => setState(() => _labelController.text = v),
                  ),
                  _LabelPresetChip(
                    label: l10n.labelWork,
                    value: 'Work',
                    current: _labelController.text,
                    onSelected: (v) => setState(() => _labelController.text = v),
                  ),
                  _LabelPresetChip(
                    label: l10n.labelVillageHome,
                    value: 'Village-Home',
                    current: _labelController.text,
                    onSelected: (v) => setState(() => _labelController.text = v),
                  ),
                  _LabelPresetChip(
                    label: l10n.labelFarm,
                    value: 'Farm',
                    current: _labelController.text,
                    onSelected: (v) => setState(() => _labelController.text = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: l10n.translate('labelOther'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l10n.translate('invalidLabel') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullAddressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.translate('fullAddress'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.home_work_outlined),
                  alignLabelWithHint: true,
                  helperText: 'Paste a Google Maps share link/coordinates to autofill',
                  helperStyle: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l10n.translate('invalidAddress') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _villageController,
                decoration: InputDecoration(
                  labelText: l10n.translate('villageColony'),
                  hintText: 'e.g. Govindgarh, Ward No. 5',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_city),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l10n.translate('invalidVillage') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _landmarkController,
                decoration: InputDecoration(
                  labelText: l10n.translate('landmarkLabel'),
                  hintText: 'e.g. Near Water Tank, Opp. Primary School',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.assistant_navigation),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? l10n.translate('invalidLandmark') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: l10n.translate('pinCode'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.pin),
                ),
                validator: (val) {
                  if (val == null || val.trim().length != 6) {
                    return l10n.translate('invalidPinCode');
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              Text(
                l10n.translate('voiceInstructions'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.grey900 : AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppTheme.grey800 : AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        color: _isRecording ? AppTheme.error : AppTheme.primary,
                      ),
                      iconSize: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isRecording
                            ? l10n.translate('recordingStop')
                            : _voiceTagPath != null
                            ? l10n.translate('voiceTagAttached')
                            : l10n.translate('recordDirectionHints'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRecording ? AppTheme.error : (isDark ? AppTheme.grey400 : AppTheme.grey600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _deliveryInstructionsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.translate('deliveryInstructions'),
                  hintText: 'e.g., Leave at the door, call before arriving',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.directions_bike),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 12),
              CheckboxListTile(
                title: Text(
                  l10n.translate('setAsDefault'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: Text(
                  isEditing ? l10n.updateAddress : l10n.saveAddress,
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
          initialLat: _capturedLatitude ?? 25.1006,
          initialLng: _capturedLongitude ?? 76.5156,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _capturedLatitude = result['lat'] as double?;
        _capturedLongitude = result['lng'] as double?;
        _fullAddressController.text = result['address'] as String;
      });

      // Auto-extract pincode if possible from address
      final RegExp pincodeRegex = RegExp(r'\b\d{6}\b');
      final match = pincodeRegex.firstMatch(result['address'] as String);
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
      final String idSuffix = _addressType == 'Shop'
          ? '_shop'
          : _addressType == 'Apartment'
          ? '_apt'
          : '_house';
      final address = Address(
        id: _editingAddress?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}$idSuffix',
        label: _labelController.text.trim(),
        fullAddress: _fullAddressController.text.trim(),
        village: _villageController.text.trim(),
        landmark: _landmarkController.text.trim(),
        pincode: _pincodeController.text.trim(),
        latitude: _capturedLatitude ?? _editingAddress?.latitude ?? 25.1006,
        longitude: _capturedLongitude ?? _editingAddress?.longitude ?? 76.5156,
        isDefault: _isDefault,
        deliveryInstructions: _deliveryInstructionsController.text.trim(),
      );

      if (_editingAddress != null) {
        await authProvider.updateAddress(_editingAddress!.id, address);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Address updated successfully!')));
        }
      } else {
        await authProvider.addAddress(address);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Address saved successfully!')));
        }
      }

      _closeAddressForm();
      await _loadAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save address: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, double>?> _resolveGoogleMapsUrl(String urlString) async {
    try {
      final uri = Uri.tryParse(urlString.trim());
      if (uri == null) return null;
      
      final client = http.Client();
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client.send(request);
      
      final String? location = response.headers['location'];
      client.close();
      
      if (location != null && location.isNotEmpty) {
        final Map<String, double>? latLng = _extractLatLngFromUrl(location);
        if (latLng != null) return latLng;
        
        if (location.contains('google.com/maps') ||
            location.contains('maps.app.goo.gl') ||
            location.contains('goo.gl/maps')) {
          return await _resolveGoogleMapsUrl(location);
        }
      } else {
        final directResponse = await http.get(uri);
        final finalUrl = directResponse.request?.url.toString();
        if (finalUrl != null) {
          return _extractLatLngFromUrl(finalUrl);
        }
      }
    } catch (e) {
      debugPrint('Error resolving shortened URL: $e');
    }
    return null;
  }

  Map<String, double>? _extractLatLngFromUrl(String url) {
    final regexes = [
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'place/(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'll=(-?\d+\.\d+),(-?\d+\.\d+)'),
    ];
    for (final reg in regexes) {
      final match = reg.firstMatch(url);
      if (match != null && match.groupCount >= 2) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    }
    return null;
  }

  Future<void> _checkAndHandleGoogleMapsLink(String text) async {
    if (_isResolvingLink) return;
    
    // Find URL in text
    final urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    
    // Also find coordinates in text if no URL is found
    final coordRegex = RegExp(
      r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)',
    );
    
    double? lat;
    double? lng;
    
    if (match != null) {
      final matchedUrl = match.group(0)!;
      if (matchedUrl.contains('google.com/maps') ||
          matchedUrl.contains('maps.app.goo.gl') ||
          matchedUrl.contains('goo.gl/maps')) {
        setState(() {
          _isResolvingLink = true;
          _isLoading = true;
        });
        
        try {
          final directLatLng = _extractLatLngFromUrl(matchedUrl);
          if (directLatLng != null) {
            lat = directLatLng['latitude'];
            lng = directLatLng['longitude'];
          } else {
            final resolvedLatLng = await _resolveGoogleMapsUrl(matchedUrl);
            if (resolvedLatLng != null) {
              lat = resolvedLatLng['latitude'];
              lng = resolvedLatLng['longitude'];
            }
          }
        } catch (e) {
          debugPrint('Error resolving link: $e');
        }
      }
    } else {
      final coordMatch = coordRegex.firstMatch(text);
      if (coordMatch != null) {
        lat = double.tryParse(coordMatch.group(1) ?? '');
        lng = double.tryParse(coordMatch.group(2) ?? '');
      }
    }
    
    if (lat != null && lng != null) {
      try {
        setState(() {
          _isResolvingLink = true;
          _isLoading = true;
        });
        final placemarks = await placemarkFromCoordinates(lat!, lng!);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _capturedLatitude = lat;
            _capturedLongitude = lng;
            
            final parts = [
              place.street,
              place.subLocality,
              place.locality,
              place.subAdministrativeArea,
              place.administrativeArea
            ].where((p) => p != null && p.trim().isNotEmpty).toList();
            
            _fullAddressController.text = parts.join(', ');
            
            if (place.postalCode != null && place.postalCode!.isNotEmpty) {
              _pincodeController.text = place.postalCode!;
            }
            if (place.locality != null && place.locality!.isNotEmpty) {
              _villageController.text = place.locality!;
            } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              _villageController.text = place.subLocality!;
            }
            if (place.name != null && place.name!.isNotEmpty) {
              _landmarkController.text = place.name!;
            }
          });
          
          if (mounted) {
            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
            final probeAddress = Address(
              id: 'probe',
              label: _labelController.text.trim().isEmpty ? 'Home' : _labelController.text.trim(),
              fullAddress: _fullAddressController.text.trim(),
              village: _villageController.text.trim(),
              landmark: _landmarkController.text.trim(),
              pincode: _pincodeController.text.trim(),
              latitude: _capturedLatitude!,
              longitude: _capturedLongitude!,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Address autofilled from location link! ${locationProvider.deliveryZoneMessageFor(probeAddress)}'),
                backgroundColor: locationProvider.isAddressWithinDeliveryRadius(probeAddress)
                    ? AppTheme.success
                    : AppTheme.error,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error reverse geocoding: $e');
      } finally {
        setState(() {
          _isResolvingLink = false;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isResolvingLink = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    try {
      await locationProvider.getCurrentLocation();
      if (locationProvider.currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(locationProvider.errorMessage ?? 'Unable to get location')),
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
        label: _labelController.text.trim().isEmpty ? 'Home' : _labelController.text.trim(),
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
            backgroundColor: locationProvider.isAddressWithinDeliveryRadius(probeAddress)
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

class _PropertyTypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  const _PropertyTypeChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Center(child: Text(label)),
          selected: isSelected,
          onSelected: (val) => onSelected(value),
          selectedColor: AppTheme.primary,
          backgroundColor: isDark ? AppTheme.grey900 : AppTheme.grey100,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : (isDark ? AppTheme.grey400 : AppTheme.grey700),
            fontSize: 12,
          ),
          side: BorderSide(
            color: isSelected ? AppTheme.primary : (isDark ? AppTheme.grey800 : Colors.transparent),
          ),
        ),
      ),
    );
  }
}

class _LabelPresetChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelected;

  const _LabelPresetChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelected(value);
      },
      selectedColor: AppTheme.primary.withOpacity(0.15),
      backgroundColor: isDark ? AppTheme.grey900 : AppTheme.grey100,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : (isDark ? AppTheme.grey400 : AppTheme.grey700),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppTheme.primary : (isDark ? AppTheme.grey800 : Colors.transparent)),
    );
  }
}
