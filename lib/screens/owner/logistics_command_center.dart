import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/app_theme.dart';

class LogisticsCommandCenter extends StatelessWidget {
  const LogisticsCommandCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Logistics Command Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cream,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            _buildAIRecommendationsSection(),
            const SizedBox(height: 24),
            _buildIncidentAlerts(),
            const SizedBox(height: 24),
            _buildMapPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Live Riders', '12', Icons.motorcycle, AppTheme.primary),
        _buildMetricCard('Active Deliveries', '45', Icons.local_shipping, AppTheme.info),
        _buildMetricCard('Late Deliveries', '2', Icons.timer_off, AppTheme.error),
        _buildMetricCard('SLA Compliance', '96.4%', Icons.verified, AppTheme.success),
        _buildMetricCard('Avg Cost/Delivery', '₹28', Icons.currency_rupee, AppTheme.warning),
        _buildMetricCard('Failed Deliveries', '1', Icons.cancel, AppTheme.error),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAIRecommendationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.warning),
              SizedBox(width: 8),
              Text(
                'Logistics Intelligence',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• High dispatch queue volume detected. Recommend activating 2 backup riders.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            '• Entering evening peak hours. Surge pricing is recommended for Central Zone.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Active Incidents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.error),
          ),
          child: ListTile(
            leading: const Icon(Icons.warning, color: AppTheme.error),
            title: const Text(
              'Vehicle Breakdown - Jodhpur Central',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Rider ID: R-849 | 10 mins ago\nTask assigned to backup Rider R-102',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            isThreeLine: true,
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () {},
              child: const Text('Resolve'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppTheme.grey200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(26.9124, 75.7873), // Default city center
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fufaji.app',
            ),
            const MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(26.9150, 75.7900),
                  child: Icon(Icons.motorcycle, color: AppTheme.info, size: 24),
                ),
                Marker(
                  point: LatLng(26.9080, 75.7800),
                  child: Icon(Icons.motorcycle, color: AppTheme.info, size: 24),
                ),
                Marker(
                  point: LatLng(26.9200, 75.7850),
                  child: Icon(Icons.location_city, color: AppTheme.error, size: 28),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
