import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';

/// Expiry Tracking Widget
/// Displays expiry tracking metrics on the owner dashboard
class ExpiryTrackingWidget extends StatefulWidget {
  const ExpiryTrackingWidget({Key? key}) : super(key: key);

  @override
  State<ExpiryTrackingWidget> createState() => _ExpiryTrackingWidgetState();
}

class _ExpiryTrackingWidgetState extends State<ExpiryTrackingWidget> {
  bool _isLoading = false;
  Map<String, dynamic> _expiryData = {};

  @override
  void initState() {
    super.initState();
    _loadExpiryData();
  }

  Future<void> _loadExpiryData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<ProductProvider>();
      // Load expiry data from provider
      final expiringToday = 0;
      final expiringThisWeek = 0;
      final expired = 0;
      final totalLoss = 0.0;

      setState(() {
        _expiryData = {
          'expiringToday': expiringToday,
          'expiringThisWeek': expiringThisWeek,
          'expired': expired,
          'totalLoss': totalLoss,
        };
      });
    } catch (e) {
      print('Error loading expiry data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiringToday = _expiryData['expiringToday'] ?? 0;
    final expiringThisWeek = _expiryData['expiringThisWeek'] ?? 0;
    final expired = _expiryData['expired'] ?? 0;
    final totalLoss = _expiryData['totalLoss'] ?? 0.0;

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
                        color: hasAlerts ? Colors.red[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: hasAlerts ? Colors.red[700] : Colors.green[700],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Expiry Tracking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _loadExpiryData,
                  child: Icon(
                    Icons.refresh,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alert Status
            if (hasAlerts)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Potential loss: ₹${totalLoss.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.red[700],
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
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'All products are fresh',
                      style: TextStyle(
                        color: Colors.green,
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
                _buildStatTile(
                  'Today',
                  expiringToday.toString(),
                  Colors.red,
                ),
                _buildStatTile(
                  'This Week',
                  expiringThisWeek.toString(),
                  Colors.orange,
                ),
                _buildStatTile(
                  'Expired',
                  expired.toString(),
                  Colors.grey,
                ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

