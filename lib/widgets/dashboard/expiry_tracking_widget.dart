import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Expiry Tracking Widget
/// Displays expiry tracking metrics on the owner dashboard
class ExpiryTrackingWidget extends StatefulWidget {
  const ExpiryTrackingWidget({super.key});

  @override
  State<ExpiryTrackingWidget> createState() => _ExpiryTrackingWidgetState();
}

class _ExpiryTrackingWidgetState extends State<ExpiryTrackingWidget> {
  Map<String, dynamic> _expiryData = {};

  @override
  void initState() {
    super.initState();
    _loadExpiryData();
  }

  Future<void> _loadExpiryData() async {
    try {
      // Load expiry data from provider
      const expiringToday = 0;
      const expiringThisWeek = 0;
      const expired = 0;
      const totalLoss = 0.0;

      if (!mounted) return;
      setState(() {
        _expiryData = {
          'expiringToday': expiringToday,
          'expiringThisWeek': expiringThisWeek,
          'expired': expired,
          'totalLoss': totalLoss,
        };
      });
    } catch (e) {
      debugPrint('Error loading expiry data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int expiringToday = (_expiryData['expiringToday'] as num? ?? 0).toInt();
    final int expiringThisWeek = (_expiryData['expiringThisWeek'] as num? ?? 0).toInt();
    final int expired = (_expiryData['expired'] as num? ?? 0).toInt();
    final double totalLoss = (_expiryData['totalLoss'] as num? ?? 0.0).toDouble();

    final hasAlerts = expiringToday > 0 || expiringThisWeek > 0 || expired > 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasAlerts ? AppTheme.error : AppTheme.success).withOpacity(0.1,),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: hasAlerts ? AppTheme.error : AppTheme.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Expiry Tracking',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _loadExpiryData,
                  child: Icon(Icons.refresh, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alert Status
            if (hasAlerts)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppTheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Potential loss: ₹${totalLoss.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'All products are fresh',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Stats Grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildStatTile('Today', expiringToday.toString(), AppTheme.error),
                _buildStatTile('This Week', expiringThisWeek.toString(), AppTheme.warning),
                _buildStatTile('Expired', expired.toString(), Colors.grey),
              ],
            ),
            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/expiry-tracking');
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
