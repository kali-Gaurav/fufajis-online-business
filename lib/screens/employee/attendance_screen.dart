import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/scanner_models.dart';

class AttendanceScreen extends StatefulWidget {
  final String? qrCodeId;

  const AttendanceScreen({super.key, this.qrCodeId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  AttendanceRecord? _todayRecord;
  bool _isLoading = false;
  LocationData? _currentLocation;
  final String _attendanceStatus = '';

  bool _autoCheckInDone = false;

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
    _getCurrentLocationThenAutoAct();
  }

  /// Gets GPS then, if this screen was opened via QR scan, auto check-in/out.
  Future<void> _getCurrentLocationThenAutoAct() async {
    await _getCurrentLocation();
    // Only auto-act when opened by the scanner (qrCodeId passed in)
    if (widget.qrCodeId != null &&
        widget.qrCodeId!.isNotEmpty &&
        !_autoCheckInDone) {
      _autoCheckInDone = true;
      await Future.delayed(
          const Duration(milliseconds: 300)); // let UI render first
      if (mounted) await _autoActFromQr();
    }
  }

  /// Auto check-in or check-out depending on today's record — no button needed.
  Future<void> _autoActFromQr() async {
    final isCheckedIn = _todayRecord?.isCheckedIn == true &&
        !(_todayRecord?.isCheckedOut == true);

    if (isCheckedIn) {
      await _checkOut();
    } else {
      await _checkIn();
    }

    // Haptic celebration + show overlay
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();

    if (mounted) _showAutoConfirmOverlay(isCheckedIn ? 'Out' : 'In');
  }

  void _showAutoConfirmOverlay(String type) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AttendanceConfirmOverlay(
        type: type,
        employeeName:
            context.read<AuthProvider>().currentUser?.name ?? 'Employee',
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _currentLocation = LocationData.fromPosition(position);
      });
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _loadTodayAttendance() async {
    final authProvider = context.read<AuthProvider>();
    final service = EmployeeScannerService(
      shopId: authProvider.currentShop?.id ?? '',
      branchId: authProvider.currentBranch?.id ?? '',
      employeeId: authProvider.currentUser?.uid ?? '',
      employeeName: authProvider.currentUser?.name ?? 'Employee',
    );

    final record = await service.getTodayAttendance();
    if (record != null && record.exists) {
      setState(() {
        _todayRecord = AttendanceRecord.fromMap(record.data() as Map<String, dynamic>);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _checkIn() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      final qrCodeId = widget.qrCodeId ??
          'ATTENDANCE-${DateTime.now().millisecondsSinceEpoch}';

      await service.checkIn(
        qrCodeId: qrCodeId,
        location: _currentLocation,
      );

      await _loadTodayAttendance();
      _showSuccess('Checked in successfully!');
    } catch (e) {
      _showError('Check-in failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    if (_todayRecord == null) {
      _showError('No check-in record found');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      await service.checkOut(
        attendanceId: _todayRecord!.id,
        location: _currentLocation,
      );

      await _loadTodayAttendance();
      _showSuccess('Checked out successfully!');
    } catch (e) {
      _showError('Check-out failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final employeeName = authProvider.currentUser?.name ?? 'Employee';
    final isCheckedIn = _todayRecord?.isCheckedIn ?? false;
    final isCheckedOut = _todayRecord?.isCheckedOut ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Employee Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(
                        employeeName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      employeeName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      authProvider.currentBranch?.name ?? 'Branch',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Location Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _currentLocation != null
                          ? Icons.location_on
                          : Icons.location_off,
                      color:
                          _currentLocation != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentLocation != null
                            ? 'Location captured'
                            : 'Getting location...',
                        style: TextStyle(
                          color: _currentLocation != null
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Attendance Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      isCheckedOut
                          ? 'Day Complete'
                          : (isCheckedIn ? 'Checked In' : 'Not Checked In'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    if (isCheckedIn && !isCheckedOut) ...[
                      // Show check-in time
                      _buildTimeDisplay(
                        'Check-in Time',
                        _todayRecord?.checkInTime,
                      ),
                      const SizedBox(height: 16),
                      // Working hours
                      if (_todayRecord?.workingHours != null)
                        _buildTimeDisplay(
                          'Working Hours',
                          null,
                          customValue:
                              '${_todayRecord!.workingHours!.toStringAsFixed(1)} hrs',
                        ),
                      const SizedBox(height: 24),
                      // Check-out button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _checkOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Check Out'),
                        ),
                      ),
                    ] else if (!isCheckedIn) ...[
                      // Check-in button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _checkIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Check In'),
                        ),
                      ),
                    ] else ...[
                      // Show complete record
                      _buildTimeDisplay(
                          'Check-in Time', _todayRecord?.checkInTime),
                      const SizedBox(height: 8),
                      _buildTimeDisplay(
                          'Check-out Time', _todayRecord?.checkOutTime),
                      const SizedBox(height: 8),
                      if (_todayRecord?.workingHours != null)
                        _buildTimeDisplay(
                          'Total Hours',
                          null,
                          customValue:
                              '${_todayRecord!.workingHours!.toStringAsFixed(1)} hrs',
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Scan QR Button
            if (widget.qrCodeId == null)
              OutlinedButton.icon(
                onPressed: () => _showScannerDialog(),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Attendance QR'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(String label, DateTime? time,
      {String? customValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          customValue ??
              (time != null
                  ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : '--:--'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Attendance QR'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Attendance ID',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              // Navigate to self with QR code
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceScreen(qrCodeId: value),
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AttendanceConfirmOverlay
//
// Shown immediately after auto check-in or check-out from QR scan.
// Auto-dismisses after 3 seconds.
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceConfirmOverlay extends StatefulWidget {
  final String type;          // 'In' or 'Out'
  final String employeeName;
  final VoidCallback onDismiss;

  const _AttendanceConfirmOverlay({
    required this.type,
    required this.employeeName,
    required this.onDismiss,
  });

  @override
  State<_AttendanceConfirmOverlay> createState() =>
      _AttendanceConfirmOverlayState();
}

class _AttendanceConfirmOverlayState
    extends State<_AttendanceConfirmOverlay> {
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isIn = widget.type == 'In';
    final color = isIn ? Colors.green : const Color(0xFFE65100);
    final icon = isIn ? Icons.login : Icons.logout;
    final label = isIn ? 'Checked In' : 'Checked Out';
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          const SizedBox(height: 6),
          Text(
            widget.employeeName,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            timeStr,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Text(
            'Closing in $_countdown…',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
