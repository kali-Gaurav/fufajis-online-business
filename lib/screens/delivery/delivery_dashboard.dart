import '../../services/logging_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_widgets.dart';
import '../../services/fleet_service.dart';
import '../../models/attendance_model.dart';
import '../../services/offline_routing_service.dart';
import 'rider_chat.dart';
import 'live_tracking_screen.dart';
import '../../providers/delivery_provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/banner_ad_widget.dart';
import '../../widgets/common/role_restricted_widget.dart';
import '../../utils/responsive.dart';

import '../../widgets/common/fj_button.dart';

class DeliveryDashboard extends StatefulWidget {
  final Widget child;
  const DeliveryDashboard({super.key, required this.child});

  @override
  State<DeliveryDashboard> createState() => _DeliveryDashboardState();
}

class _DeliveryDashboardState extends State<DeliveryDashboard> {
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
  }

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location == '/delivery') return 0;
    if (location.startsWith('/delivery/orders')) return 1;
    if (location.startsWith('/delivery/earnings')) return 2;
    if (location.startsWith('/delivery/trip-sheet')) return 3;
    if (location.startsWith('/delivery/scanner')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/delivery');
        break;
      case 1:
        context.go('/delivery/orders');
        break;
      case 2:
        context.go('/delivery/earnings');
        break;
      case 3:
        context.go('/delivery/trip-sheet');
        break;
      case 4:
        context.go('/delivery/scanner');
        break;
    }
  }

  final List<String> _titles = ['Dashboard', 'Orders', 'Earnings', 'Trip Worksheet', 'Scanner'];

  @override
  Widget build(BuildContext context) {
    final useRail = Responsive.useRailNav(context);
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[selectedIndex]),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _syncService.isOnline,
            builder: (context, online, child) {
              return ValueListenableBuilder<int>(
                valueListenable: _syncService.pendingSyncCount,
                builder: (context, pendingCount, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: online
                          ? (pendingCount > 0
                                ? AppTheme.warning.withValues(alpha: 0.15)
                                : AppTheme.success.withValues(alpha: 0.1))
                          : AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          online ? Icons.cloud_done : Icons.cloud_off,
                          size: 14,
                          color: online
                              ? (pendingCount > 0 ? AppTheme.warning : AppTheme.success)
                              : AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          online
                              ? (pendingCount > 0 ? 'Sync ($pendingCount)' : 'Online')
                              : 'Offline ($pendingCount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: online
                                ? (pendingCount > 0 ? AppTheme.warning : AppTheme.success)
                                : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Search tapped')));
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
          RoleRestrictedWidget(
            allowedRoles: const [UserRole.superAdmin, UserRole.owner],
            child: IconButton(
              onPressed: () => context.push('/role-select'),
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Role',
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Account profile tapped')));
            },
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      body: Row(
        children: [
          if (useRail)
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (index) {
                          _onItemTapped(index, context);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Dashboard'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.local_shipping_outlined),
                            selectedIcon: Icon(Icons.local_shipping),
                            label: Text('Orders'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet),
                            label: Text('Earnings'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.route_outlined),
                            selectedIcon: Icon(Icons.route),
                            label: Text('Trip Sheet'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.qr_code_scanner_outlined),
                            selectedIcon: Icon(Icons.qr_code_scanner),
                            label: Text('Scanner'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (useRail) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: widget.child),
                const BannerAdWidget(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => _onItemTapped(index, context),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.grey500,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping_outlined),
                  activeIcon: Icon(Icons.local_shipping),
                  label: 'Orders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet),
                  label: 'Earnings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.route_outlined),
                  activeIcon: Icon(Icons.route),
                  label: 'Trip',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner_outlined),
                  activeIcon: Icon(Icons.qr_code_scanner),
                  label: 'Scanner',
                ),
              ],
            ),
    );
  }
}

class DeliveryHomePage extends StatefulWidget {
  const DeliveryHomePage({super.key});

  @override
  State<DeliveryHomePage> createState() => _DeliveryHomePageState();
}

class _DeliveryHomePageState extends State<DeliveryHomePage> {
  final FleetService _fleetService = FleetService();
  final OfflineRoutingService _routingService = OfflineRoutingService();

  // Store coordinates (Baran Central Shop)
  static const double storeLat = 25.1006;
  static const double storeLng = 76.5156;

  // Mocking controls
  bool _useMockLocation = true;
  double _mockLat = storeLat;
  double _mockLng = storeLng;
  String _mockPresetName = "At Central Shop (0.0 km)";

  // Clock elapsed timer
  Timer? _shiftTimer;
  String _elapsedTimeString = "00:00:00";
  DateTime? _activeClockInTime;

  @override
  void dispose() {
    _shiftTimer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime clockInTime) {
    if (_activeClockInTime == clockInTime && _shiftTimer != null) return;
    _activeClockInTime = clockInTime;
    _shiftTimer?.cancel();
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final duration = DateTime.now().difference(clockInTime);
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _elapsedTimeString = "$hours:$minutes:$seconds";
      });
    });
  }

  Future<void> _handleClockIn(String riderId, String riderName) async {
    setState(() => _isLoadingLocation = true);
    double currentLat = storeLat;
    double currentLng = storeLng;

    if (_useMockLocation) {
      currentLat = _mockLat;
      currentLng = _mockLng;
    } else {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied ||
              requested == LocationPermission.deniedForever) {
            setState(() => _isLoadingLocation = false);
            _showErrorDialog(
              "Location Permissions Denied",
              "We need GPS permissions to verify you are at the store.",
            );
            return;
          }
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        currentLat = pos.latitude;
        currentLng = pos.longitude;
      } catch (e) {
        setState(() => _isLoadingLocation = false);
        _showErrorDialog("GPS Error", "Failed to retrieve device location: $e");
        return;
      }
    }

    // Calculate geofence distance
    final double distance = _routingService.calculateHaversineDistance(
      currentLat,
      currentLng,
      storeLat,
      storeLng,
    );

    if (distance > 1.0) {
      // Enforced 1km Production Limit
      setState(() => _isLoadingLocation = false);
      _showErrorDialog(
        "Geo-Fence Violation",
        "You are too far from the store to clock in!\n\n"
            "Current Position: (${currentLat.toStringAsFixed(4)}, ${currentLng.toStringAsFixed(4)})\n"
            "Distance to Store: ${distance.toStringAsFixed(2)} km\n"
            "Allowed Radius: 1.00 km\n\n"
            "Please travel closer to the shop to begin your shift.",
      );
      return;
    }

    final newAttendance = AttendanceModel(
      id: 'shift_${DateTime.now().millisecondsSinceEpoch}_$riderId',
      riderId: riderId,
      riderName: riderName,
      clockInTime: DateTime.now(),
      clockInLatitude: currentLat,
      clockInLongitude: currentLng,
      status: 'active',
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    try {
      await _fleetService.clockInRider(newAttendance);
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clocked in successfully! Have a safe shift.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _showErrorDialog("Sync Error", "Failed to register clock-in: $e");
    }
  }

  bool _isLoadingLocation = false;

  Future<void> _handleClockOut(AttendanceModel activeShift) async {
    double currentLat = storeLat;
    double currentLng = storeLng;

    if (_useMockLocation) {
      currentLat = _mockLat;
      currentLng = _mockLng;
    } else {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        currentLat = pos.latitude;
        currentLng = pos.longitude;
      } catch (e, stack) {
        LoggingService().error('Silent error caught', e, stack);
      }
    }

    try {
      await _fleetService.clockOutRider(activeShift.id, currentLat, currentLng);
      _shiftTimer?.cancel();
      _shiftTimer = null;
      _activeClockInTime = null;
      setState(() {
        _elapsedTimeString = "00:00:00";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clocked out successfully. Thank you!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      _showErrorDialog("Sync Error", "Failed to register clock-out: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final deliveryProvider = Provider.of<DeliveryProvider>(context);
    final rider = authProvider.currentUser;
    final riderId = rider?.id ?? 'demo_rider';
    final riderName = rider?.name ?? 'Rahul';

    // Initialize delivery provider if not already
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deliveryProvider.init(riderId);
    });

    return StreamBuilder<List<AttendanceModel>>(
      stream: _fleetService.getRiderAttendanceStream(riderId),
      builder: (context, snapshot) {
        AttendanceModel? activeShift;
        List<AttendanceModel> history = [];

        if (snapshot.hasData) {
          final list = snapshot.data!;
          history = list;
          final activeIndex = list.indexWhere((element) => element.status == 'active');
          if (activeIndex != -1) {
            activeShift = list[activeIndex];
            _startTimer(activeShift.clockInTime);
          } else {
            _shiftTimer?.cancel();
            _shiftTimer = null;
            _activeClockInTime = null;
          }
        }

        final bool isClockedIn = activeShift != null;
        final double currentDistance = _routingService.calculateHaversineDistance(
          _useMockLocation ? _mockLat : storeLat,
          _useMockLocation ? _mockLng : storeLng,
          storeLat,
          storeLng,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              _buildWelcomeCard(riderName),
              const SizedBox(height: 24),

              // Feature 60: Vehicle Mode Selector
              _buildVehicleSelector(deliveryProvider),
              const SizedBox(height: 24),

              // Attendance Check-In Panel
              _buildAttendancePanel(isClockedIn, activeShift, currentDistance, riderId, riderName),
              const SizedBox(height: 24),

              // Location Simulator Panel (Developer/Demo Presets)
              if (kDebugMode || rider?.role == UserRole.superAdmin)
                _buildLocationSimulatorCard(currentDistance),
              if (kDebugMode || rider?.role == UserRole.superAdmin) const SizedBox(height: 24),

              // Stats
              _buildStatsGrid(deliveryProvider),
              const SizedBox(height: 24),

              _buildCashCollectionSummaryCard(riderId),
              const SizedBox(height: 24),

              // Shift Logs Checklist / History
              _buildShiftHistorySection(history),
              const SizedBox(height: 24),

              // Today's Deliveries (Active Tasks)
              _buildTodayDeliveries(deliveryProvider.assignedOrders, deliveryProvider),
              const SizedBox(height: 24),

              // Pickup Queue (Available Orders)
              _buildPickupQueue(deliveryProvider.availableOrders, deliveryProvider, rider),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),

              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Fufaji Delivery v2.4.0 • Enterprise Edition',
                  style: TextStyle(fontSize: 10, color: AppTheme.grey400),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVehicleSelector(DeliveryProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining, color: AppTheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Select Vehicle Mode:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.grey700),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Bike', label: Text('Bike'), icon: Icon(Icons.motorcycle)),
              ButtonSegment(
                value: 'E-Rickshaw',
                label: Text('E-Rickshaw'),
                icon: Icon(Icons.electric_rickshaw),
              ),
            ],
            selected: {provider.vehicleMode},
            onSelectionChanged: (Set<String> newSelection) {
              provider.setVehicleMode(newSelection.first);
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.primary,
              selectedForegroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String riderName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $riderName!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your geofenced shift clock-in to receive orders.',
                  style: TextStyle(fontSize: 14, color: AppTheme.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining, size: 40, color: AppTheme.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendancePanel(
    bool isClockedIn,
    AttendanceModel? activeShift,
    double currentDistance,
    String riderId,
    String riderName,
  ) {
    final color = isClockedIn ? AppTheme.success : AppTheme.grey700;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shift Attendance Console',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isClockedIn ? 'ON DUTY' : 'OFF DUTY',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isClockedIn) ...[
            Text(
              'Shift Started at: ${DateFormat('hh:mm a').format(activeShift!.clockInTime)}',
              style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppTheme.success, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Active Duration: ',
                  style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                ),
                Text(
                  _elapsedTimeString,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FjButton(
              label: 'Clock Out (End Shift)',
              onPressed: () => _handleClockOut(activeShift),
              type: FjButtonType.error,
              width: double.infinity,
            ),
          ] else ...[
            const Text(
              'To start receiving and delivering orders, please clock in. You must be physically present within 1 km of the Jaipur shop base.',
              style: TextStyle(fontSize: 14, color: AppTheme.grey600, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  currentDistance <= 1.0 ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: currentDistance <= 1.0 ? AppTheme.success : AppTheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Distance to Store: ${currentDistance.toStringAsFixed(2)} km ',
                  style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
                ),
                Text(
                  currentDistance <= 1.0 ? '(Within 1 km radius)' : '(Out of Bounds)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: currentDistance <= 1.0 ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FjButton(
              label: 'Clock In (Start Shift)',
              onPressed: _isLoadingLocation ? null : () => _handleClockIn(riderId, riderName),
              isLoading: _isLoadingLocation,
              width: double.infinity,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSimulatorCard(double currentDistance) {
    final presets = [
      {'name': 'At Central Shop (0.0 km)', 'lat': storeLat, 'lng': storeLng},
      {'name': 'Nearby Crossing (1.2 km)', 'lat': 26.9200, 'lng': 75.7900},
      {'name': 'Out-of-Bounds Village (35.4 km)', 'lat': 27.0500, 'lng': 76.1000},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.05),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_searching, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'GPS Geo-Fence Simulator',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _useMockLocation,
                activeThumbColor: AppTheme.info,
                onChanged: (val) {
                  setState(() {
                    _useMockLocation = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Allows testers to mock location offsets to verify geofenced blocking vs validation.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const Divider(height: 24),
          if (_useMockLocation) ...[
            const Text(
              'Select Mock Position Preset:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((preset) {
                final isSelected = _mockPresetName == preset['name'];
                return ChoiceChip(
                  label: Text(preset['name'] as String),
                  selected: isSelected,
                  selectedColor: AppTheme.info.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.info : AppTheme.grey700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _mockPresetName = preset['name'] as String;
                        _mockLat = preset['lat'] as double;
                        _mockLng = preset['lng'] as double;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.grey600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Simulating Coordinates: (${_mockLat.toStringAsFixed(4)}, ${_mockLng.toStringAsFixed(4)})\n'
                      'Distance from base: ${currentDistance.toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 11, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: AppTheme.success),
                SizedBox(width: 8),
                Text(
                  'Using actual physical device GPS provider',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DeliveryProvider provider) {
    final stats = [
      {
        'title': 'Today\'s Task',
        'value': provider.assignedOrders.length.toString(),
        'icon': Icons.local_shipping,
      },
      {
        'title': 'Distance (km)',
        'value': provider.todayDistance.toStringAsFixed(1),
        'icon': Icons.straighten,
      },
      {
        'title': 'Completed',
        'value': provider.completedToday.toString(),
        'icon': Icons.check_circle,
      },
      {
        'title': 'Earnings',
        'value': '₹${provider.todayEarnings.round()}',
        'icon': Icons.account_balance_wallet,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return ScaleBounce(
          onTap: () {
            if (stat['title'] == 'Earnings') {
              context.go('/delivery/earnings');
            } else if (stat['title'] == 'Today\'s Task') {
              context.go('/delivery/orders');
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(stat['icon'] as IconData, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftHistorySection(List<AttendanceModel> history) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift History & Logs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No shift records found.', style: TextStyle(color: AppTheme.grey500)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length > 5 ? 5 : history.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = history[index];
                final duration = item.clockOutTime != null
                    ? item.clockOutTime!.difference(item.clockInTime)
                    : DateTime.now().difference(item.clockInTime);
                final hours = duration.inHours;
                final mins = duration.inMinutes % 60;
                final durationStr = item.status == 'active'
                    ? 'Active Session'
                    : '${hours}h ${mins}m';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.status == 'active'
                              ? AppTheme.success.withValues(alpha: 0.1)
                              : AppTheme.grey100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.status == 'active' ? Icons.play_arrow : Icons.stop,
                          color: item.status == 'active' ? AppTheme.success : AppTheme.grey600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shift: ${DateFormat('dd MMM yyyy').format(item.clockInTime)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.grey800,
                              ),
                            ),
                            Text(
                              'In: ${DateFormat('hh:mm a').format(item.clockInTime)}  '
                              '${item.clockOutTime != null ? "Out: ${DateFormat('hh:mm a').format(item.clockOutTime!)}" : ""}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        durationStr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.status == 'active' ? AppTheme.success : AppTheme.grey700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTodayDeliveries(List<OrderModel> orders, DeliveryProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Active Deliveries',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Text(
                '${orders.length} Active',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No active deliveries. Check pickup queue!'),
              ),
            )
          else
            ...orders.map((order) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delivery_dining, color: AppTheme.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.grey900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse('tel:${order.customerPhone}')),
                                child: const Icon(Icons.phone, size: 16, color: AppTheme.primary),
                              ),
                            ],
                          ),
                          Text(order.customerName, style: const TextStyle(fontSize: 14)),
                          Text(
                            order.deliveryAddress.fullAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.totalAmount.round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _launchMap(
                                order.deliveryAddress.latitude,
                                order.deliveryAddress.longitude,
                              ),
                              icon: const Icon(Icons.navigation, color: AppTheme.info),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            FjButton(
                              label: 'Deliver',
                              onPressed: () async {
                                final snap = await FirebaseFirestore.instance
                                    .collection('deliveries')
                                    .where('orderId', isEqualTo: order.id)
                                    .limit(1)
                                    .get();
                                if (snap.docs.isNotEmpty && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LiveTrackingScreen(deliveryId: snap.docs.first.id),
                                    ),
                                  );
                                } else {
                                  _showOtpVerificationDialog(order.id, provider);
                                }
                              },
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPickupQueue(List<OrderModel> orders, DeliveryProvider provider, UserModel? rider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pickup Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              if (orders.length > 1)
                FjButton(
                  label: 'Accept All',
                  onPressed: () => _handleBulkAccept(orders, provider, rider),
                  icon: Icons.done_all,
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${orders.length} Ready',
                    style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No orders ready for pickup.'),
              ),
            )
          else
            ...orders.map((order) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${order.items.length} items • ₹${order.totalAmount.round()}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                          ),
                        ],
                      ),
                    ),
                    FjButton(
                      label: 'Accept',
                      onPressed: () {
                        if (rider != null) {
                          provider.acceptOrder(order.id, rider);
                        }
                      },
                      type: FjButtonType.success,
                      height: 32,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _handleBulkAccept(
    List<OrderModel> orders,
    DeliveryProvider provider,
    UserModel? rider,
  ) async {
    if (rider == null) return;

    int count = 0;
    for (var order in orders) {
      final success = await provider.acceptOrder(order.id, rider);
      if (success) count++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accepted $count orders successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _launchMap(double lat, double lng) async {
    final url = 'google.navigation:q=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      debugPrint('Could not launch navigation');
    }
  }

  void _showOtpVerificationDialog(String orderId, DeliveryProvider provider) {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    // Auto-focus the OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter 4-digit OTP provided by the customer'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0000'),
            ),
            if (kDebugMode) // Helper for testers
              TextButton(
                onPressed: () => controller.text = '1234',
                child: const Text('Fill Test OTP (1234)'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FjButton(
            label: 'Complete Delivery',
            onPressed: () async {
              final success = await provider.verifyAndCompleteDelivery(orderId, controller.text);
              if (context.mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Delivery Completed! Earnings updated.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Invalid OTP'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.navigation, 'label': 'Navigate', 'color': AppTheme.info},
      {'icon': Icons.qr_code, 'label': 'Scan OTP', 'color': AppTheme.primary},
      {'icon': Icons.phone, 'label': 'Call Customer', 'color': AppTheme.success},
      {'icon': Icons.help, 'label': 'Help', 'color': AppTheme.warning},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: actions.map((action) {
              return GestureDetector(
                onTap: () {
                  if (action['label'] == 'Help') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RiderChatScreen()),
                    );
                  }
                },
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action['icon'] as IconData, color: action['color'] as Color),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey700),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCollectionSummaryCard(String riderId) {
    final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('deliveryAgentId', isEqualTo: riderId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .where('paymentMethod', isEqualTo: 'PaymentMethod.cod')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        // Filter locally by deliveredAt >= startOfDay
        final todayDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['deliveredAt'] as Timestamp?;
          if (timestamp == null) return false;
          return timestamp.toDate().isAfter(startOfDay);
        }).toList();

        double totalCashCollected = 0.0;
        for (var doc in todayDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final amt = data['cashCollectedAmount'] ?? data['totalAmount'] ?? 0.0;
          if (amt is num) {
            totalCashCollected += amt.toDouble();
          } else if (amt is String) {
            totalCashCollected += double.tryParse(amt) ?? 0.0;
          }
        }

        if (totalCashCollected == 0.0) {
          return const SizedBox.shrink(); // Hide if no COD collected today
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.successGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COD CASH COLLECTED TODAY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${totalCashCollected.round()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              FjButton(
                label: 'Settlements',
                onPressed: () {
                  // Direct to settlements management or earnings page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please submit settlement from the Earnings page.'),
                    ),
                  );
                },
                type: FjButtonType.outline,
                height: 40,
              ),
            ],
          ),
        );
      },
    );
  }
}

// End of file.
