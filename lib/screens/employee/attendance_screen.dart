import 'package:flutter/material.dart';
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
  String _attendanceStatus = '';

  @override
  void initState() {
    super.initState();
    _loadTodayAttendance();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
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
        title: Text('Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Employee Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      child: Text(
                        employeeName[0].toUpperCase(),
                        style: TextStyle(fontSize: 32),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      employeeName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      authProvider.currentBranch?.name ?? 'Branch',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Location Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _currentLocation != null
                          ? Icons.location_on
                          : Icons.location_off,
                      color:
                          _currentLocation != null ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 8),
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

            SizedBox(height: 24),

            // Attendance Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      isCheckedOut
                          ? 'Day Complete'
                          : (isCheckedIn ? 'Checked In' : 'Not Checked In'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 24),
                    if (isCheckedIn && !isCheckedOut) ...[
                      // Show check-in time
                      _buildTimeDisplay(
                        'Check-in Time',
                        _todayRecord?.checkInTime,
                      ),
                      SizedBox(height: 16),
                      // Working hours
                      if (_todayRecord?.workingHours != null)
                        _buildTimeDisplay(
                          'Working Hours',
                          null,
                          customValue:
                              '${_todayRecord!.workingHours!.toStringAsFixed(1)} hrs',
                        ),
                      SizedBox(height: 24),
                      // Check-out button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _checkOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Check Out'),
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
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Check In'),
                        ),
                      ),
                    ] else ...[
                      // Show complete record
                      _buildTimeDisplay(
                          'Check-in Time', _todayRecord?.checkInTime),
                      SizedBox(height: 8),
                      _buildTimeDisplay(
                          'Check-out Time', _todayRecord?.checkOutTime),
                      SizedBox(height: 8),
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

            SizedBox(height: 24),

            // Scan QR Button
            if (widget.qrCodeId == null)
              OutlinedButton.icon(
                onPressed: () => _showScannerDialog(),
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Scan Attendance QR'),
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
        Text(label, style: TextStyle(color: Colors.grey)),
        Text(
          customValue ??
              (time != null
                  ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : '--:--'),
          style: TextStyle(
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
        title: Text('Enter Attendance QR'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
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
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
