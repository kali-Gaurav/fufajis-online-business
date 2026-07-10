import 'package:flutter/material.dart';
import '../../models/delivery_feedback_model.dart';
import '../../utils/app_theme.dart';

class DeliveryFeedbackScreen extends StatefulWidget {
  final String employeeId;
  final List<DeliveryFeedbackModel> feedback;

  const DeliveryFeedbackScreen({
    super.key,
    required this.employeeId,
    required this.feedback,
  });

  @override
  State<DeliveryFeedbackScreen> createState() => _DeliveryFeedbackScreenState();
}

class _DeliveryFeedbackScreenState extends State<DeliveryFeedbackScreen> {
  String _selectedDateRange = '7d';

  List<DeliveryFeedbackModel> _getFilteredFeedback() {
    List<DeliveryFeedbackModel> filtered = widget.feedback
        .where((f) => f.employeeId == widget.employeeId)
        .toList();

    if (_selectedDateRange == '7d') {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      filtered =
          filtered.where((f) => f.createdAt.isAfter(sevenDaysAgo)).toList();
    } else if (_selectedDateRange == '30d') {
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30));
      filtered =
          filtered.where((f) => f.createdAt.isAfter(thirtyDaysAgo)).toList();
    }

    return filtered;
  }

  double _getAverageRating() {
    final filtered = _getFilteredFeedback();
    if (filtered.isEmpty) return 0.0;
    final sum =
        filtered.map((f) => f.serviceRating).reduce((a, b) => a + b);
    return sum / filtered.length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredFeedback();
    final avgRating = _getAverageRating();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Delivery Feedback'),
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Score Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.8),
                    AppTheme.primary.withValues(alpha: 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Performance Score',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '${avgRating.toStringAsFixed(1)}/5.0',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Based on ${filtered.length} deliveries',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['7d', '30d', 'all']
                        .map((range) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(
                                    range == '7d'
                                        ? 'This Week'
                                        : range == '30d'
                                            ? 'This Month'
                                            : 'All Time',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: _selectedDateRange == range,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedDateRange = range;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Service Metrics
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Metrics',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard('Punctual', '95%', Icons.schedule),
                  const SizedBox(height: 8),
                  _buildMetricCard('Polite', '98%', Icons.sentiment_satisfied),
                  const SizedBox(height: 8),
                  _buildMetricCard('Careful Handling', '94%',
                      Icons.shield_check),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Recent Feedback
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Recent Feedback',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No feedback yet',
                    style: TextStyle(
                      color: AppTheme.grey600,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: List.generate(
                    filtered.length,
                    (index) {
                      final fb = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            border: Border.all(color: AppTheme.grey200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        Icons.star,
                                        size: 16,
                                        color: i < fb.serviceRating
                                            ? AppTheme.primary
                                            : AppTheme.grey300,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate(fb.createdAt),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (fb.feedbackText != null)
                                Text(
                                  fb.feedbackText!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.grey700,
                                  ),
                                ),
                              if (fb.feedbackText == null)
                                Text(
                                  'Order #${fb.orderId.substring(0, 8)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.grey600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grey50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.grey600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
