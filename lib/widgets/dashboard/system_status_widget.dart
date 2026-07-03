import 'package:flutter/material.dart';
import '../../services/remote_config_service.dart';
import '../../utils/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SystemStatusWidget extends StatefulWidget {
  const SystemStatusWidget({super.key});

  @override
  State<SystemStatusWidget> createState() => _SystemStatusWidgetState();
}

class _SystemStatusWidgetState extends State<SystemStatusWidget> {
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  String _currentVersion = 'Loading...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _isLoading = true);
    final packageInfo = await PackageInfo.fromPlatform();
    await _remoteConfig.fetchAndActivate();
    if (mounted) {
      setState(() {
        _currentVersion = packageInfo.version;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'App Status & Deployment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadInfo,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Installed Version', _currentVersion, Icons.install_mobile),
            const Divider(),
            _buildStatusRow('Min. Required', _remoteConfig.minAppVersion, Icons.warning_amber),
            const Divider(),
            _buildStatusRow(
              'Maintenance Mode',
              _remoteConfig.isMaintenanceMode ? 'ACTIVE' : 'Inactive',
              Icons.construction,
              color: _remoteConfig.isMaintenanceMode ? AppTheme.error : AppTheme.success,
            ),
            const SizedBox(height: 12),
            const Text(
              'Manage these values in Firebase Remote Config to force updates or start maintenance.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppTheme.grey900),
          ),
        ],
      ),
    );
  }
}
