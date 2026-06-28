import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/fleet_service.dart';
import '../../models/attendance_model.dart';
import '../../utils/app_theme.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends State<AttendanceManagementScreen> {
  final FleetService _fleetService = FleetService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      body: StreamBuilder<List<AttendanceModel>>(
        stream: _fleetService.getAllAttendanceStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading shifts: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }

          final List<AttendanceModel> allShifts = snapshot.data ?? [];
          final List<AttendanceModel> activeShifts = allShifts.where((s) => s.status == 'active').toList();
          final List<AttendanceModel> completedShifts = allShifts.where((s) => s.status == 'completed').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title
                const Text(
                  'Rider Shift Attendance',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor real-time active delivery riders and review check-in/out geo-locations.',
                  style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                ),
                const SizedBox(height: 24),

                // Metrics Summary Cards
                _buildMetricsSection(activeShifts.length, completedShifts.length),
                const SizedBox(height: 24),

                // Main Shift Tracking Tabs/Lists
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Riders Panel
                    Expanded(
                      flex: 4,
                      child: _buildActiveRidersPanel(activeShifts),
                    ),
                    const SizedBox(width: 24),
                    // Shift History Panel
                    Expanded(
                      flex: 6,
                      child: _buildShiftHistoryPanel(completedShifts),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsSection(int activeCount, int completedCount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.grey200),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people, color: AppTheme.success, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activeCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text(
                      'Riders Currently On-Duty',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.grey200),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedCount',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const Text(
                      'Completed Shifts Logged',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRidersPanel(List<AttendanceModel> activeShifts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active On-Duty Riders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${activeShifts.length} Online',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activeShifts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.directions_run, size: 48, color: AppTheme.grey300),
                    SizedBox(height: 12),
                    Text(
                      'No riders currently active.',
                      style: TextStyle(color: AppTheme.grey500, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeShifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final shift = activeShifts[index];
                final duration = DateTime.now().difference(shift.clockInTime);
                final hours = duration.inHours;
                final mins = duration.inMinutes % 60;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                                radius: 18,
                                child: const Icon(Icons.person, color: AppTheme.success, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shift.riderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.grey800,
                                    ),
                                  ),
                                  Text(
                                    'Clocked-in: ${DateFormat('hh:mm a').format(shift.clockInTime)}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '${hours}h ${mins}m',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.grey50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: AppTheme.grey500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Check-in Coordinates: (${shift.clockInLatitude.toStringAsFixed(4)}, ${shift.clockInLongitude.toStringAsFixed(4)})',
                                style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                              ),
                            ),
                          ],
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

  Widget _buildShiftHistoryPanel(List<AttendanceModel> completedShifts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shift History Logs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          if (completedShifts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No historical shift records logged.',
                  style: TextStyle(color: AppTheme.grey500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedShifts.length > 10 ? 10 : completedShifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final shift = completedShifts[index];
                final duration = shift.clockOutTime != null
                    ? shift.clockOutTime!.difference(shift.clockInTime)
                    : Duration.zero;
                final hours = duration.inHours;
                final mins = duration.inMinutes % 60;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.grey100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_toggle_off, color: AppTheme.grey600, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  shift.riderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.grey800,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy').format(shift.clockInTime),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'In: ${DateFormat('hh:mm a').format(shift.clockInTime)} '
                              '• Out: ${shift.clockOutTime != null ? DateFormat('hh:mm a').format(shift.clockOutTime!) : "N/A"}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                            ),
                            if (shift.clockOutLatitude != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Out Coords: (${shift.clockOutLatitude!.toStringAsFixed(4)}, ${shift.clockOutLongitude!.toStringAsFixed(4)})',
                                style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${hours}h ${mins}m',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.grey200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(fontSize: 10, color: AppTheme.grey700),
                            ),
                          ),
                        ],
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
}

