import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class AttendanceComplianceScreen extends StatefulWidget {
  const AttendanceComplianceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceComplianceScreen> createState() =>
      _AttendanceComplianceScreenState();
}

class _AttendanceComplianceScreenState
    extends State<AttendanceComplianceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'today'; // today, week, month
  final List<Map<String, dynamic>> _employees = [
    {
      'id': 'emp_001',
      'name': 'Rajesh Kumar',
      'role': 'Packing Specialist',
      'attendance': 'present',
      'checkInTime': '06:02',
      'checkOutTime': '14:05',
      'totalHours': 8.05,
      'status': 'on_time',
      'complianceScore': 98,
    },
    {
      'id': 'emp_002',
      'name': 'Priya Singh',
      'role': 'Customer Service',
      'attendance': 'present',
      'checkInTime': '14:15',
      'checkOutTime': null,
      'totalHours': 0,
      'status': 'late',
      'complianceScore': 92,
    },
    {
      'id': 'emp_003',
      'name': 'Amit Patel',
      'role': 'Inventory Manager',
      'attendance': 'absent',
      'checkInTime': null,
      'checkOutTime': null,
      'totalHours': 0,
      'status': 'absent',
      'complianceScore': 85,
    },
  ];

  final List<Map<String, dynamic>> _attendanceHistory = [
    {
      'date': DateTime(2026, 7, 10),
      'emp_001': {'status': 'present', 'checkIn': '06:00', 'checkOut': '14:00'},
      'emp_002': {'status': 'present', 'checkIn': '14:00', 'checkOut': '22:00'},
      'emp_003': {'status': 'present', 'checkIn': '22:00', 'checkOut': '06:00'},
    },
    {
      'date': DateTime(2026, 7, 9),
      'emp_001': {'status': 'present', 'checkIn': '06:05', 'checkOut': '14:10'},
      'emp_002': {'status': 'absent', 'checkIn': null, 'checkOut': null},
      'emp_003': {'status': 'present', 'checkIn': '22:00', 'checkOut': '06:00'},
    },
    {
      'date': DateTime(2026, 7, 8),
      'emp_001': {'status': 'present', 'checkIn': '06:00', 'checkOut': '14:00'},
      'emp_002': {'status': 'present', 'checkIn': '14:20', 'checkOut': '22:10'},
      'emp_003': {'status': 'leave', 'checkIn': null, 'checkOut': null},
    },
  ];

  final List<Map<String, dynamic>> _leaveRequests = [
    {
      'id': 'leave_001',
      'employee': 'Rajesh Kumar',
      'type': 'sick_leave',
      'startDate': DateTime(2026, 7, 14),
      'endDate': DateTime(2026, 7, 15),
      'status': 'pending',
      'reason': 'Medical appointment',
    },
    {
      'id': 'leave_002',
      'employee': 'Priya Singh',
      'type': 'vacation',
      'startDate': DateTime(2026, 7, 20),
      'endDate': DateTime(2026, 7, 25),
      'status': 'approved',
      'reason': 'Family vacation',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Attendance & Compliance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Today'),
                onTap: () => setState(() => _selectedView = 'today'),
              ),
              PopupMenuItem(
                child: const Text('This Week'),
                onTap: () => setState(() => _selectedView = 'week'),
              ),
              PopupMenuItem(
                child: const Text('This Month'),
                onTap: () => setState(() => _selectedView = 'month'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'History'),
            Tab(text: 'Leaves'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildHistoryTab(),
          _buildLeavesTab(),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAttendanceStats(),
          const SizedBox(height: 20),
          _buildDateSelector(),
          const SizedBox(height: 20),
          const Text(
            'Employee Attendance',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._employees.map((emp) => _buildAttendanceCard(emp)).toList(),
        ],
      ),
    );
  }

  Widget _buildAttendanceStats() {
    final present = _employees.where((e) => e['attendance'] == 'present').length;
    final absent = _employees.where((e) => e['attendance'] == 'absent').length;
    final late = _employees.where((e) => e['status'] == 'late').length;
    final total = _employees.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'Present',
            value: present.toString(),
            icon: Icons.check_circle,
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Absent',
            value: absent.toString(),
            icon: Icons.cancel,
            color: AppTheme.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Late',
            value: late.toString(),
            icon: Icons.access_time,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: 'Attendance Rate',
            value: '${((present / total) * 100).toStringAsFixed(0)}%',
            icon: Icons.trending_up,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat('EEEE').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> emp) {
    final isPresent = emp['attendance'] == 'present';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emp['role'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAttendanceBadge(emp['attendance']),
              ],
            ),
            const SizedBox(height: 12),
            if (isPresent)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.grey50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Check In',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.grey600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: AppTheme.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    emp['checkInTime'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getTimeStatus(emp['status']),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: _getStatusColor(emp['status']),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (emp['checkOutTime'] != null)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Check Out',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.grey600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: AppTheme.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      emp['checkOutTime'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hours Worked: ${emp['totalHours']}h',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (emp['checkOutTime'] == null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'Still Working',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compliance Score',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: emp['complianceScore'] / 100,
                                minHeight: 4,
                                backgroundColor: AppTheme.grey200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getComplianceColor(emp['complianceScore']),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${emp['complianceScore']}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: const Text('Details', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (status == 'present') {
      bgColor = AppTheme.success.withOpacity(0.1);
      textColor = AppTheme.success;
      label = 'Present';
      icon = Icons.check_circle;
    } else {
      bgColor = AppTheme.error.withOpacity(0.1);
      textColor = AppTheme.error;
      label = 'Absent';
      icon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance History',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._attendanceHistory.map((history) => _buildHistoryCard(history)).toList(),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM dd, yyyy').format(history['date']),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            ..._employees
                .map((emp) {
                  final empId = emp['id'];
                  final empHistory = history[empId] as Map<String, dynamic>;
                  return _buildHistoryEmployeeRow(emp['name'], empHistory);
                })
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryEmployeeRow(String empName, Map<String, dynamic> empHistory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              empName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getHistoryStatusColor(empHistory['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              empHistory['status'].toString().toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: _getHistoryStatusColor(empHistory['status']),
              ),
            ),
          ),
          if (empHistory['checkIn'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${empHistory['checkIn']} - ${empHistory['checkOut']}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.grey600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeavesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave Requests',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Leave'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._leaveRequests.map((leave) => _buildLeaveCard(leave)).toList(),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final isPending = leave['status'] == 'pending';
    final days = leave['endDate'].difference(leave['startDate']).inDays + 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave['employee'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        leave['type'].replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.amber.withOpacity(0.1)
                        : AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    leave['status'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isPending ? Colors.amber : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM').format(leave['startDate'])} - ${DateFormat('dd MMM').format(leave['endDate'])} ($days days)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                leave['reason'],
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.grey700,
                ),
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: const Text('Decline', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeStatus(String status) {
    switch (status) {
      case 'on_time':
        return 'On time';
      case 'late':
        return 'Late';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'on_time':
        return AppTheme.success;
      case 'late':
        return AppTheme.error;
      default:
        return AppTheme.grey600;
    }
  }

  Color _getComplianceColor(int score) {
    if (score >= 95) return AppTheme.success;
    if (score >= 85) return Colors.orange;
    return AppTheme.error;
  }

  Color _getHistoryStatusColor(String status) {
    switch (status) {
      case 'present':
        return AppTheme.success;
      case 'absent':
        return AppTheme.error;
      case 'leave':
        return Colors.blue;
      default:
        return AppTheme.grey600;
    }
  }
}
