import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fufaji/providers/report_provider.dart';
import 'package:fufaji/widgets/analytics/report_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure provider is initialized
      context.read<ReportProvider>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Export'),
        elevation: 0,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, reportProvider, _) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickGenerateSection(context, reportProvider),
                  const SizedBox(height: 24),
                  _buildScheduledReportsSection(context, reportProvider),
                  const SizedBox(height: 24),
                  _buildReportsListSection(context, reportProvider),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickGenerateSection(
    BuildContext context,
    ReportProvider reportProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Generate',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickReportButton(
              context,
              'Daily Report',
              Icons.calendar_today,
              Colors.blue,
              () {
                reportProvider.generateReport(type: 'daily');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily report generated')),
                );
              },
            ),
            _buildQuickReportButton(
              context,
              'Weekly Report',
              Icons.calendar_view_week,
              Colors.green,
              () {
                reportProvider.generateReport(type: 'weekly');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Weekly report generated')),
                );
              },
            ),
            _buildQuickReportButton(
              context,
              'Monthly Report',
              Icons.calendar_view_month,
              Colors.orange,
              () {
                reportProvider.generateReport(type: 'monthly');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Monthly report generated')),
                );
              },
            ),
            _buildQuickReportButton(
              context,
              'Custom Report',
              Icons.tune,
              Colors.purple,
              () {
                reportProvider.generateReport(type: 'custom');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Custom report generated')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickReportButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledReportsSection(
    BuildContext context,
    ReportProvider reportProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scheduled Reports',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showScheduleDialog(context, reportProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildScheduledReportItem(
            context,
            'Daily Revenue',
            'Every day at 9:00 PM',
            Icons.schedule,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildScheduledReportItem(
            context,
            'Weekly Summary',
            'Every Monday at 10:00 AM',
            Icons.schedule,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildScheduledReportItem(
            context,
            'Monthly Analytics',
            'First day of month at 8:00 AM',
            Icons.schedule,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledReportItem(
    BuildContext context,
    String title,
    String schedule,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                schedule,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildReportsListSection(
    BuildContext context,
    ReportProvider reportProvider,
  ) {
    final reports = reportProvider.availableReports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Reports (${reports.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[600]
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports generated yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          ...reports.map((report) {
            return ReportCard(
              report: report,
              onTap: () {
                reportProvider.selectReport(report);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${report.title} selected')),
                );
              },
              onExportPdf: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exporting ${report.title} as PDF')),
                );
              },
              onExportCsv: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exporting ${report.title} as CSV')),
                );
              },
            );
          }).toList(),
      ],
    );
  }

  void _showScheduleDialog(BuildContext context, ReportProvider reportProvider) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedFrequency = 'daily';
        String? selectedTime = '09:00';

        return AlertDialog(
          title: const Text('Schedule Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (value) {
                  selectedFrequency = value;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedTime,
                onChanged: (value) {
                  selectedTime = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                reportProvider.scheduleEmailReport(
                  reportType: 'scheduled',
                  frequency: selectedFrequency,
                  email: 'owner@fufaji.com',
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report scheduled successfully')),
                );
              },
              child: const Text('Schedule'),
            ),
          ],
        );
      },
    );
  }
}
