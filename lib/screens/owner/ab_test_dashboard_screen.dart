import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ABTestDashboardScreen extends StatefulWidget {
  const ABTestDashboardScreen({super.key});

  @override
  State<ABTestDashboardScreen> createState() => _ABTestDashboardScreenState();
}

class _ABTestDashboardScreenState extends State<ABTestDashboardScreen> {
  final List<Map<String, dynamic>> _experiments = [
    {
      'id': 'exp_001',
      'title': 'Green Checkout Button Color',
      'status': 'Active',
      'daysRunning': 14,
      'variants': [
        {
          'name': 'Control (Orange Button)',
          'users': 12450,
          'conversions': 452,
          'rate': 3.63,
          'aov': 342.50,
          'ci': '3.31% - 3.95%',
        },
        {
          'name': 'Variant (Green Button)',
          'users': 12510,
          'conversions': 528,
          'rate': 4.22,
          'aov': 358.20,
          'ci': '3.87% - 4.57%',
        },
      ],
      'pValue': 0.018,
      'isSignificant': true,
      'improvement': 16.2,
      'confidenceInterval': '95%',
    },
    {
      'id': 'exp_002',
      'title': 'Free Delivery Threshold ₹199 vs ₹299',
      'status': 'Active',
      'daysRunning': 8,
      'variants': [
        {
          'name': 'Control (₹299)',
          'users': 8200,
          'conversions': 298,
          'rate': 3.63,
          'aov': 412.00,
          'ci': '3.22% - 4.04%',
        },
        {
          'name': 'Variant (₹199)',
          'users': 8150,
          'conversions': 310,
          'rate': 3.80,
          'aov': 387.50,
          'ci': '3.39% - 4.21%',
        },
      ],
      'pValue': 0.420,
      'isSignificant': false,
      'improvement': 4.6,
      'confidenceInterval': 'None',
    },
    {
      'id': 'exp_003',
      'title': 'Homepage Banner Promo Carousel',
      'status': 'Completed',
      'daysRunning': 30,
      'variants': [
        {
          'name': 'Control (Static Banner)',
          'users': 24000,
          'conversions': 864,
          'rate': 3.60,
          'aov': 290.00,
          'ci': '3.36% - 3.84%',
        },
        {
          'name': 'Variant (Animated Carousel)',
          'users': 24150,
          'conversions': 1026,
          'rate': 4.25,
          'aov': 315.00,
          'ci': '4.00% - 4.50%',
        },
      ],
      'pValue': 0.0003,
      'isSignificant': true,
      'improvement': 18.1,
      'confidenceInterval': '99%',
    },
  ];

  Map<String, dynamic>? _selectedExperiment;

  @override
  void initState() {
    super.initState();
    _selectedExperiment = _experiments[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: AppBar(
        title: const Text('A/B Testing Console', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildExperimentSelector(),
              const SizedBox(height: 16),
              if (_selectedExperiment != null) ...[
                _buildSummaryHeader(),
                const SizedBox(height: 16),
                _buildStatisticalSignificanceCard(),
                const SizedBox(height: 16),
                _buildVariantsGrid(),
                const SizedBox(height: 16),
                _buildVisualComparisonChart(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExperimentSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Map<String, dynamic>>(
            value: _selectedExperiment,
            isExpanded: true,
            hint: const Text('Select Experiment'),
            items: _experiments.map((exp) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: exp,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: exp['status'] == 'Active'
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.ownerAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        exp['status'] as String,
                        style: TextStyle(
                          color: exp['status'] == 'Active' ? AppTheme.success : AppTheme.info,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exp['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedExperiment = val;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final exp = _selectedExperiment!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp['title'] as String,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Running for ${exp['daysRunning']} days • Status: ${exp['status']}',
                    style: const TextStyle(color: AppTheme.grey600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics, color: AppTheme.primary, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticalSignificanceCard() {
    final exp = _selectedExperiment!;
    final isSig = exp['isSignificant'] as bool;
    final pVal = exp['pValue'] as double;
    final impr = exp['improvement'] as double;

    return Card(
      color: isSig ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isSig ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isSig ? AppTheme.success : AppTheme.warning,
              size: 48,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSig ? 'Statistically Significant!' : 'Inconclusive / Not Significant',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSig ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSig
                        ? 'Variant B shows a +${impr.toStringAsFixed(1)}% conversion improvement (p-value: ${pVal.toStringAsFixed(4)} < 0.05).'
                        : 'No statistically significant difference found yet (p-value: ${pVal.toStringAsFixed(4)}). Continue running the experiment.',
                    style: TextStyle(
                      color: isSig ? AppTheme.success : AppTheme.warning,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantsGrid() {
    final exp = _selectedExperiment!;
    final variants = (exp['variants'] as List).cast<Map<String, dynamic>>();

    return Row(
      children: [
        Expanded(child: _buildVariantCard(variants[0], isControl: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildVariantCard(variants[1], isControl: false)),
      ],
    );
  }

  Widget _buildVariantCard(Map<String, dynamic> variant, {required bool isControl}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: isControl ? AppTheme.grey400 : AppTheme.primary, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              variant['name'] as String,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.grey800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _buildMetricRow('Visitors', variant['users'].toString()),
            _buildMetricRow('Conversions', variant['conversions'].toString()),
            _buildMetricRow('Conv. Rate', '${variant['rate']}%'),
            _buildMetricRow('Avg. Order', '₹${variant['aov']}'),
            const Divider(height: 16),
            const Text(
              '95% Confidence Interval:',
              style: TextStyle(fontSize: 10, color: AppTheme.grey500),
            ),
            Text(
              variant['ci'] as String,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.grey600, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVisualComparisonChart() {
    final exp = _selectedExperiment!;
    final variants = exp['variants'] as List<dynamic>;
    final rateA = variants[0]['rate'] as double;
    final rateB = variants[1]['rate'] as double;
    final maxRate = rateA > rateB ? rateA : rateB;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversion Rate Comparison',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildBarItem(variants[0]['name'] as String, rateA, maxRate, isControl: true),
            const SizedBox(height: 16),
            _buildBarItem(variants[1]['name'] as String, rateB, maxRate, isControl: false),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem(String name, double rate, double maxRate, {required bool isControl}) {
    final percentageOfMax = maxRate > 0 ? (rate / maxRate) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 12, color: AppTheme.grey700)),
            Text(
              '${rate.toStringAsFixed(2)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final barWidth = constraints.maxWidth * percentageOfMax;
            return Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.grey200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: barWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isControl
                          ? [AppTheme.grey500, AppTheme.grey700]
                          : [AppTheme.primary, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
