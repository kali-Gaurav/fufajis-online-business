import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/shop_config_provider.dart';
import '../../models/shop_branch_model.dart';

class ShopLocationPickerScreen extends StatefulWidget {
  final ShopBranchModel? branch; // Null if configuring main shop location
  const ShopLocationPickerScreen({super.key, this.branch});

  @override
  State<ShopLocationPickerScreen> createState() => _ShopLocationPickerScreenState();
}

class _ShopLocationPickerScreenState extends State<ShopLocationPickerScreen> {
  LatLng _selectedLatLng = const LatLng(26.9124, 75.7873);
  double _radiusKm = 8.0;
  String _addressController = '';
  GoogleMapController? _mapController;
  bool _isGeocoding = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.branch != null) {
      _selectedLatLng = LatLng(widget.branch!.latitude, widget.branch!.longitude);
      _radiusKm = widget.branch!.deliveryRadiusKm;
      _addressController = widget.branch!.branchAddress;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final config = Provider.of<ShopConfigProvider>(context, listen: false).shopConfig;
        if (config != null) {
          setState(() {
            _selectedLatLng = LatLng(config.shopLatitude, config.shopLongitude);
            _radiusKm = config.maxDeliveryRadiusKm;
            _addressController = config.shopAddress;
          });
        }
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isGeocoding = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final latLng = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedLatLng = latLng;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 13));
        await _reverseGeocode(latLng);
      } else {
        _showSnackBar('Location not found', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Search failed: $e', Colors.red);
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    setState(() => _isGeocoding = true);
    try {
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final formattedAddress = [
          if (p.street != null && p.street!.isNotEmpty) p.street,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality,
          if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) p.subAdministrativeArea,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
          if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode,
        ].join(', ');

        setState(() {
          _addressController = formattedAddress;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _saveLocation() async {
    final provider = Provider.of<ShopConfigProvider>(context, listen: false);
    if (widget.branch != null) {
      final updatedBranch = widget.branch!.copyWith(
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
        branchAddress: _addressController,
        deliveryRadiusKm: _radiusKm,
      );
      await provider.updateBranch(updatedBranch);
    } else {
      if (provider.shopConfig != null) {
        final updatedConfig = provider.shopConfig!.copyWith(
          shopLatitude: _selectedLatLng.latitude,
          shopLongitude: _selectedLatLng.longitude,
          shopAddress: _addressController,
          maxDeliveryRadiusKm: _radiusKm,
        );
        await provider.updateShopConfig(updatedConfig);
      }
    }
    _showSnackBar('Location saved successfully!', AppTheme.success);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShopConfigProvider>(context);
    final zones = widget.branch?.deliveryZones ?? provider.shopConfig?.deliveryZones ?? [];

    // Define concentric circles to overlay on map
    final Set<Circle> circles = {
      Circle(
        circleId: const CircleId('outer_limit'),
        center: _selectedLatLng,
        radius: _radiusKm * 1000,
        fillColor: AppTheme.primary.withValues(alpha: 0.08),
        strokeColor: AppTheme.primary,
        strokeWidth: 2,
      ),
      // Concentric active zones
      ...zones.where((z) => z.isActive).map((z) {
        Color zoneColor = Colors.green;
        if (z.deliveryCharge > 0 && z.deliveryCharge <= 20) {
          zoneColor = Colors.orange;
        } else if (z.deliveryCharge > 20) {
          zoneColor = Colors.red;
        }
        return Circle(
          circleId: CircleId('zone_${z.id}'),
          center: _selectedLatLng,
          radius: z.toRadiusKm * 1000,
          fillColor: zoneColor.withValues(alpha: 0.04),
          strokeColor: zoneColor.withValues(alpha: 0.4),
          strokeWidth: 1,
        );
      }),
    };

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.branch != null ? 'Branch Location Picker' : 'Shop Location Picker',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          // Map View
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLatLng, zoom: 12),
            onMapCreated: (c) => _mapController = c,
            circles: circles,
            markers: {
              Marker(
                markerId: const MarkerId('shop_pin'),
                position: _selectedLatLng,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _selectedLatLng = newPosition;
                  });
                  _reverseGeocode(newPosition);
                },
              ),
            },
            onTap: (pos) {
              setState(() {
                _selectedLatLng = pos;
              });
              _reverseGeocode(pos);
            },
          ),

          // Top Search Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search landmark or address...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      if (_isGeocoding)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _performSearch,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Sheet Custom Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.branch != null ? 'Branch Address' : 'Store Address',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _addressController.isEmpty ? 'Locating...' : _addressController,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Coordinates info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Latitude: ${_selectedLatLng.latitude.toStringAsFixed(5)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(
                        'Longitude: ${_selectedLatLng.longitude.toStringAsFixed(5)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Radius slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Max Delivery Radius',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '${_radiusKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 1.0,
                    max: 50.0,
                    divisions: 49,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.primary.withValues(alpha: 0.2),
                    onChanged: (v) {
                      setState(() {
                        _radiusKm = v;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveLocation,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Confirm Location & Zone',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
