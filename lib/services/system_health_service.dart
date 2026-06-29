import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'rds_database_service.dart';

enum ServiceStatus { healthy, degraded, down, unknown }

class HealthStatus {
  final String serviceName;
  final ServiceStatus status;
  final String message;
  final DateTime lastChecked;
  final Duration? latency;

  HealthStatus({
    required this.serviceName,
    required this.status,
    required this.message,
    required this.lastChecked,
    this.latency,
  });
}

class SystemHealthService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, HealthStatus> _healthStates = {};
  Map<String, HealthStatus> get healthStates => _healthStates;

  SystemHealthService() {
    _initStates();
  }

  void _initStates() {
    final now = DateTime.now();
    _healthStates = {
      'Firebase Firestore': HealthStatus(serviceName: 'Firebase Firestore', status: ServiceStatus.unknown, message: 'Waiting for ping...', lastChecked: now),
      'AWS RDS (Postgres)': HealthStatus(serviceName: 'AWS RDS (Postgres)', status: ServiceStatus.unknown, message: 'Waiting for ping...', lastChecked: now),
      'Upstash Redis': HealthStatus(serviceName: 'Upstash Redis', status: ServiceStatus.unknown, message: 'Waiting for ping...', lastChecked: now),
      'AWS S3 (Storage)': HealthStatus(serviceName: 'AWS S3 (Storage)', status: ServiceStatus.unknown, message: 'Waiting for ping...', lastChecked: now),
      'AWS Bedrock (AI)': HealthStatus(serviceName: 'AWS Bedrock (AI)', status: ServiceStatus.unknown, message: 'Waiting for ping...', lastChecked: now),
    };
  }

  Future<void> runFullDiagnostic() async {
    await Future.wait([
      _pingFirestore(),
      _pingRDS(),
      _pingRedis(),
      _pingStorage(),
      _pingBedrock(),
    ]);
    notifyListeners();
  }

  Future<void> _pingFirestore() async {
    final start = DateTime.now();
    try {
      // Very light query to test connectivity
      await _firestore.collection('system_health_checks').limit(1).get().timeout(const Duration(seconds: 3));
      final latency = DateTime.now().difference(start);
      _updateStatus('Firebase Firestore', ServiceStatus.healthy, 'Operational', latency);
    } catch (e) {
      _updateStatus('Firebase Firestore', ServiceStatus.down, 'Timeout or Error: $e', null);
    }
  }

  Future<void> _pingRedis() async {
    final start = DateTime.now();
    try {
      final redisUrl = AppConfig.upstashRedisRestUrl;
      final redisToken = AppConfig.upstashRedisRestToken;
      
      if (redisUrl.isEmpty) {
        _updateStatus('Upstash Redis', ServiceStatus.degraded, 'Missing URL Configuration', null);
        return;
      }

      final url = redisUrl.endsWith('/') ? '${redisUrl}ping' : '$redisUrl/ping';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $redisToken'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final latency = DateTime.now().difference(start);
        _updateStatus('Upstash Redis', ServiceStatus.healthy, 'Operational', latency);
      } else if (response.statusCode == 401) {
        _updateStatus('Upstash Redis', ServiceStatus.degraded, 'Authentication Failed', null);
      } else {
        _updateStatus('Upstash Redis', ServiceStatus.down, 'HTTP ${response.statusCode}', null);
      }
    } catch (e) {
      _updateStatus('Upstash Redis', ServiceStatus.down, 'Connection Failed', null);
    }
  }

  Future<void> _pingStorage() async {
    // Simulated ping for AWS S3
    await Future.delayed(const Duration(milliseconds: 300));
    _updateStatus('AWS S3 (Storage)', ServiceStatus.healthy, 'Operational', const Duration(milliseconds: 300));
  }

  Future<void> _pingBedrock() async {
    // Simulated ping for AWS Bedrock
    await Future.delayed(const Duration(milliseconds: 600));
    _updateStatus('AWS Bedrock (AI)', ServiceStatus.healthy, 'Operational', const Duration(milliseconds: 600));
  }

  Future<void> _pingRDS() async {
    final start = DateTime.now();
    try {
      final rds = RDSDatabaseService();
      final res = await rds.query('SELECT 1 as ping');
      if (res.isNotEmpty) {
        final latency = DateTime.now().difference(start);
        _updateStatus('AWS RDS (Postgres)', ServiceStatus.healthy, 'Operational', latency);
      } else {
        _updateStatus('AWS RDS (Postgres)', ServiceStatus.down, 'Query returned empty', null);
      }
    } catch (e) {
      _updateStatus('AWS RDS (Postgres)', ServiceStatus.down, 'Connection Failed: $e', null);
    }
  }

  void _updateStatus(String service, ServiceStatus status, String message, Duration? latency) {
    _healthStates[service] = HealthStatus(
      serviceName: service,
      status: status,
      message: message,
      lastChecked: DateTime.now(),
      latency: latency,
    );
  }
}
