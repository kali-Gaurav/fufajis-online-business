import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class ReportsAnalyticsExportScreen extends StatefulWidget {
  const ReportsAnalyticsExportScreen({Key? key}) : super(key: key);

  @override
  State<ReportsAnalyticsExportScreen> createState() =>
      _ReportsAnalyticsExportScreenState();
}

class _ReportsAnalyticsExportScreenState
    extends State<ReportsAnalyticsExportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime(2026, 6, 11);
  DateTime _endDate = DateTime(2026, 7, 11);

  final List<Map<String, dynamic>> _reports = [
    {
      'id': 'report_001',
      'name': 'Monthly Sales Report',
      'description': 'Comprehensive sales analysis by product and region',
      'lastGenerated': DateTime(2026, 7, 10, 14, 30),
      'frequency': 'Monthly',
      'format': ['PDF', 'Excel', 'CSV'],
      'pages': 24,
    },
    {
      'id': 'report_002',
      'name': 'Inventory Status Report',
      'description': 'Stock levels, movement, and expiry tracking',
      'lastGenerated': DateTime(2026, 7, 11, 9, 0),
      'frequency': 'Weekly',
      'format': ['PDF', 'Excel'],
      'pages': 12,
    },
    {
      'id': 'report_003',
      'name': 'Employee Performance',
      'description': 'Staff productivity, attendance, and compliance metrics',
      'lastGenerated': DateTime(2026, 7, 9, 10, 15),
      'frequency': 'Monthly',
      'format': ['PDF', 'Excel', 'CSV'],
      'pages': 18,
    },
    {
      'id': 'report_004',
      'name': 'Financial Summary',
      'description': 'Revenue, expenses, and profit analysis',
      'lastGenerated': DateTime(2026, 7, 1, 16, 45),
      'frequency': 'Monthly',
      'format': ['PDF', 'Excel'],
      'pages': 16,
    },
  ];

  final List<Map<String, dynamic>> _dashboards = [
    {
      'id': 'dash_001',
      'name': 'Executive Dashboard',
      'description': 'High-level business metrics and KPIs',
      'widgets': 8,
      'lastUpdated': DateTime(2026, 7, 11, 10, 30),
    },
    {
      'id': 'dash_002',
      'name': 'Operations Dashboard',
      'description': 'Daily operations, orders, and logistics tracking',
      'widgets': 12,
      'lastUpdated': DateTime(2026, 7, 11, 11, 0),
    },
    {
      'id': 'dash_003',
      'name': 'Customer Analytics',
      'description': 'Customer behavior, segmentation, and RFM analysis',
      'widgets': 10,
      'lastUpdated': DateTime(2026, 7, 11, 9, 45),
    },
  ];

  final List<Map<String, dynamic>> _exportHistory = [
    {
      'id': 'export_001',
      'reportName': 'Monthly Sales Report',
      'format': 'PDF',
      'date': DateTime(2026, 7, 10, 14, 30),
      'size': '2.4 MB',
      'status': 'completed',
    },
    {
      'id': 'export_002',
      'reportName': 'Inventory Status Report',
      'format': 'Excel',
      'date': DateTime(2026, 7, 11, 9, 0),
      'size': '1.8 MB',
      'status': 'completed',
    },
    {
      'id': 'export_003',
      'reportName': 'Employee Performance',
      'format': 'CSV',
      'date': DateTime(2026, 7, 9, 10, 15),
      'size': '0.9 MB',
      'status': 'completed',
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
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Reports'),
            Tab(text: 'Dashboards'),
            Tab(text: 'Export History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildDashboardsTab(),
          _buildExportHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangeSelector(),
          const SizedBox(height: 20),
          const Text(
            'Available Reports',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._reports.map((report) => _buildReportCard(report)).toList(),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.grey300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.grey600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: AppTheme.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.grey300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'To',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.grey600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.description, color: AppTheme.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report['description'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
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
                        'Frequency',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report['frequency'],
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
                        'Pages',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report['pages']}',
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
                        'Last Generated',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd').format(report['lastGenerated']),
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
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: report['format'].length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final format = report['format'][index];
                  return ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 14),
                    label: Text(format),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Dashboards',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._dashboards.map((dashboard) => _buildDashboardCard(dashboard)).toList(),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(Map<String, dynamic> dashboard) {
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.dashboard, color: AppTheme.primary, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dashboard['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dashboard['description'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
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
                        'Widgets',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${dashboard['widgets']}',
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
                        'Last Updated',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('HH:mm').format(dashboard['lastUpdated']),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: const Text('Customize', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Export History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.delete_sweep, size: 14),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._exportHistory.map((export) => _buildExportHistoryCard(export)).toList(),
        ],
      ),
    );
  }

  Widget _buildExportHistoryCard(Map<String, dynamic> export) {
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        export['reportName'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(export['date']),
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
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    export['format'],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
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
                        'File Size',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        export['size'],
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
                        'Status',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          export['status'].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share, size: 14),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
