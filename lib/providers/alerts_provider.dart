import 'package:flutter/material.dart';
import '../models/analytics_models.dart';
import '../services/business_analytics_service.dart';

class AlertsProvider extends ChangeNotifier {
  final BusinessAnalyticsService _analyticsService =
      BusinessAnalyticsService();

  List<Alert> activeAlerts = [];
  List<Alert> dismissedAlerts = [];
  bool isLoading = false;
  String? error;

  Map<String, bool> alertPreferences = {
    'low_stock': true,
    'delivery_issue': true,
    'customer_churn': true,
    'quality_issue': true,
    'revenue_drop': true,
  };

  AlertsProvider() {
    _subscribeToAlerts();
  }

  void _subscribeToAlerts() {
    _analyticsService.streamAlerts().listen(
      (alerts) {
        activeAlerts = alerts;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
  }

  Stream<List<Alert>> watchAlerts() {
    return _analyticsService.streamAlerts();
  }

  Future<void> dismissAlert(String alertId) async {
    try {
      await _analyticsService.dismissAlert(alertId);
      final alert = activeAlerts.firstWhere((a) => a.id == alertId);
      activeAlerts.removeWhere((a) => a.id == alertId);
      dismissedAlerts.add(alert);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> dismissAllAlerts() async {
    try {
      for (final alert in List.from(activeAlerts)) {
        await dismissAlert(alert.id);
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void setAlertPreference(String alertType, bool enabled) {
    alertPreferences[alertType] = enabled;
    notifyListeners();
  }

  List<Alert> getFilteredAlerts() {
    return activeAlerts.where((alert) {
      return alertPreferences[alert.type] ?? true;
    }).toList();
  }

  int get alertCount => activeAlerts.length;

  int get criticalAlertsCount =>
      activeAlerts.where((a) => a.severity == 'critical').length;

  int get highPriorityAlertsCount => activeAlerts
      .where((a) => a.severity == 'critical' || a.severity == 'high')
      .length;

  @override
  void dispose() {
    super.dispose();
  }
}
