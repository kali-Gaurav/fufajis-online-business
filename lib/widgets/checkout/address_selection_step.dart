import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/checkout/voice_landmark_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

/// Step 1: Address Selection Widget
class AddressSelectionStep extends StatefulWidget {
  final Address? selectedAddress;
  final ValueChanged<Address> onAddressSelected;
  final VoidCallback onContinue;
  final ValueChanged<String?> onVoiceLandmarkRecorded;

  const AddressSelectionStep({
    super.key,
    this.selectedAddress,
    required this.onAddressSelected,
    required this.onContinue,
    required this.onVoiceLandmarkRecorded,
  });

  @override
  State<AddressSelectionStep> createState() => _AddressSelectionStepState();
}

class _AddressSelectionStepState extends State<AddressSelectionStep> {
  List<Address> _addresses = [];
  bool _loadingAddresses = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _loadingAddresses = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final list = await authProvider.getAddresses();
    setState(() {
      _addresses = list;
      if (_addresses.isNotEmpty && widget.selectedAddress == null) {
        final defaultAddr = _addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => _addresses.first,
        );
        widget.onAddressSelected(defaultAddr);
      }
      _loadingAddresses = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentAddress = widget.selectedAddress;
    final isInDeliveryZone = currentAddress != null &&
        locationProvider.isAddressWithinDeliveryRadius(currentAddress);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.grey900,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/customer/addresses'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add New'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Loading state
        if (_loadingAddresses)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          )
        else if (_addresses.isEmpty)
          // No addresses state
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.location_off,
                  size: 48,
                  color: AppTheme.grey400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No saved addresses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a delivery address to continue',
                  style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/customer/addresses'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          // Address list
          ..._addresses.map((address) => _buildAddressCard(address)),

        const SizedBox(height: 16),

        // Voice Landmark Tagging
        if (widget.selectedAddress != null && isInDeliveryZone) ...[
          VoiceLandmarkWidget(
            onRecordingComplete: (path) => widget.onVoiceLandmarkRecorded(path),
          ),
          const SizedBox(height: 16),
        ],

        // Selected address map preview
        if (widget.selectedAddress != null) ...[
          _buildMapPreview(widget.selectedAddress!),
          const SizedBox(height: 12),
          // Delivery zone status
          _buildDeliveryZoneStatus(isInDeliveryZone, locationProvider),
        ],

        const SizedBox(height: 24),

        // Continue button
        ElevatedButton(
          onPressed: widget.selectedAddress != null && isInDeliveryZone
              ? widget.onContinue
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: AppTheme.grey300,
          ),
          child: const Text(
            'Continue to Payment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(Address address) {
    final isSelected = widget.selectedAddress?.id == address.id;
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final isInDeliveryZone = locationProvider.isAddressWithinDeliveryRadius(address);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.grey300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (isInDeliveryZone) {
            widget.onAddressSelected(address);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      address.label.toLowerCase() == 'home'
                          ? Icons.home
                          : Icons.business,
                      color: isSelected ? AppTheme.primary : AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.primary : AppTheme.grey900,
                              ),
                            ),
                            if (address.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
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
                            ],
                          ],
                        ),
                        Text(
                          address.fullAddress,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.grey600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppTheme.primary),
                ],
              ),
              if (!isInDeliveryZone) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: AppTheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationProvider.deliveryZoneMessageFor(address),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPreview(Address address) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Map placeholder - in production, use Google Maps widget
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.map,
                    size: 40,
                    color: AppTheme.grey400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address.fullAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Map pin overlay
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      address.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryZoneStatus(bool isInDeliveryZone, LocationProvider locationProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInDeliveryZone
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInDeliveryZone
              ? AppTheme.success.withValues(alpha: 0.35)
              : AppTheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isInDeliveryZone ? Icons.check_circle_outline : Icons.block,
            color: isInDeliveryZone ? AppTheme.success : AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isInDeliveryZone
                  ? 'Delivery available at this address'
                  : widget.selectedAddress != null
                      ? locationProvider.deliveryZoneMessageFor(widget.selectedAddress!)
                      : 'Please select a valid address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isInDeliveryZone ? AppTheme.success : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

