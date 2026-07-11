import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class ShiftScheduleManagementScreen extends StatefulWidget {
  const ShiftScheduleManagementScreen({Key? key}) : super(key: key);

  @override
  State<ShiftScheduleManagementScreen> createState() =>
      _ShiftScheduleManagementScreenState();
}

class _ShiftScheduleManagementScreenState
    extends State<ShiftScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  String _selectedView = 'month'; // month, week, day
  final List<Map<String, dynamic>> _shifts = [
    {
      'id': 'shift_001',
      'name': 'Morning Shift',
      'startTime': '06:00',
      'endTime': '14:00',
      'duration': 8,
      'color': Colors.blue,
    },
    {
      'id': 'shift_002',
      'name': 'Afternoon Shift',
      'startTime': '14:00',
      'endTime': '22:00',
      'duration': 8,
      'color': Colors.orange,
    },
    {
      'id': 'shift_003',
      'name': 'Night Shift',
      'startTime': '22:00',
      'endTime': '06:00',
      'duration': 8,
      'color': Colors.purple,
    },
  ];

  final List<Map<String, dynamic>> _schedules = [
    {
      'id': 'emp_001',
      'name': 'Rajesh Kumar',
      'role': 'Packing Specialist',
      'shiftId': 'shift_001',
      'shiftName': 'Morning Shift',
      'days': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      'status': 'active',
      'startDate': DateTime(2026, 7, 1),
      'endDate': DateTime(2026, 8, 31),
    },
    {
      'id': 'emp_002',
      'name': 'Priya Singh',
      'role': 'Customer Service',
      'shiftId': 'shift_002',
      'shiftName': 'Afternoon Shift',
      'days': ['Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      'status': 'active',
      'startDate': DateTime(2026, 7, 1),
      'endDate': DateTime(2026, 8, 31),
    },
    {
      'id': 'emp_003',
      'name': 'Amit Patel',
      'role': 'Inventory Manager',
      'shiftId': 'shift_003',
      'shiftName': 'Night Shift',
      'days': ['Thu', 'Fri', 'Sat', 'Sun', 'Mon'],
      'status': 'active',
      'startDate': DateTime(2026, 7, 1),
      'endDate': DateTime(2026, 8, 31),
    },
  ];

  final List<Map<String, dynamic>> _swapRequests = [
    {
      'id': 'req_001',
      'from': 'Rajesh Kumar',
      'to': 'Priya Singh',
      'date': DateTime(2026, 7, 15),
      'reason': 'Personal commitment',
      'status': 'pending',
      'timestamp': DateTime(2026, 7, 10),
    },
    {
      'id': 'req_002',
      'from': 'Amit Patel',
      'to': 'Rajesh Kumar',
      'date': DateTime(2026, 7, 20),
      'reason': 'Medical appointment',
      'status': 'approved',
      'timestamp': DateTime(2026, 7, 9),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          'Shift & Schedule',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Month View'),
                onTap: () => setState(() => _selectedView = 'month'),
              ),
              PopupMenuItem(
                child: const Text('Week View'),
                onTap: () => setState(() => _selectedView = 'week'),
              ),
              PopupMenuItem(
                child: const Text('Day View'),
                onTap: () => setState(() => _selectedView = 'day'),
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
            Tab(text: 'Calendar'),
            Tab(text: 'Shifts'),
            Tab(text: 'Schedules'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildShiftsTab(),
          _buildSchedulesTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthNavigator(),
          const SizedBox(height: 20),
          _buildCalendarGrid(),
          const SizedBox(height: 20),
          _buildDayShifts(),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(
            () => _selectedMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month - 1,
            ),
          ),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_selectedMonth),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(
            () => _selectedMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingWeekday = firstDay.weekday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Weekday headers
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayOffset = index - (startingWeekday - 1);
                final isCurrentMonth = dayOffset > 0 && dayOffset <= daysInMonth;
                final day = isCurrentMonth ? dayOffset : 0;
                final date =
                    isCurrentMonth ? DateTime(_selectedMonth.year, _selectedMonth.month, day) : null;

                return _buildCalendarDay(day, isCurrentMonth, date);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(int day, bool isCurrentMonth, DateTime? date) {
    if (!isCurrentMonth) {
      return Container();
    }

    final hasShifts = day % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.grey200),
        color: day == DateTime.now().day && _selectedMonth.month == DateTime.now().month
            ? AppTheme.primary.withValues(alpha: 0.1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: day == DateTime.now().day && _selectedMonth.month == DateTime.now().month
                    ? AppTheme.primary
                    : AppTheme.grey900,
              ),
            ),
          ),
          if (hasShifts)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayShifts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Shifts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ..._shifts.map((shift) => _buildShiftCard(shift)).toList(),
      ],
    );
  }

  Widget _buildShiftsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shift Types',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._shifts.map((shift) => _buildShiftTypeCard(shift)).toList(),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: shift['color'],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shift['startTime']} - ${shift['endTime']} (${shift['duration']}h)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '3 staff',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTypeCard(Map<String, dynamic> shift) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: shift['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shift['startTime']} - ${shift['endTime']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(child: Text('Edit')),
                    const PopupMenuItem(child: Text('Duplicate')),
                    const PopupMenuItem(child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shift['duration']} hours',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Staff',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '3 employees',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Employee Schedules',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Assign Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._schedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
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
                        schedule['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule['role'],
                        style: const TextStyle(
                          fontSize: 11,
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
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    schedule['status'].toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                              'Assigned Shift',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.grey600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              schedule['shiftName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Working Days',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.grey600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 4,
                              children: (schedule['days'] as List<String>)
                                  .map(
                                    (day) => Text(
                                      day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
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
                              'Valid From',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.grey600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM yyyy').format(schedule['startDate']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valid Until',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.grey600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM yyyy').format(schedule['endDate']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
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
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      backgroundColor: AppTheme.primary,
                    ),
                    child: const Text('Edit', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('View History', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shift Swap Requests',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_swapRequests.where((r) => r['status'] == 'pending').length} pending',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._swapRequests.map((request) => _buildSwapRequestCard(request)).toList(),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> request) {
    final isPending = request['status'] == 'pending';

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
                      Row(
                        children: [
                          Text(
                            request['from'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppTheme.grey600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            request['to'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(request['date']),
                        style: const TextStyle(
                          fontSize: 11,
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
                        ? Colors.amber.withValues(alpha: 0.1)
                        : AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request['status'].toUpperCase(),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                request['reason'],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Requested ${DateFormat('MMM dd').format(request['timestamp'])}',
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.grey500,
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
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
}
