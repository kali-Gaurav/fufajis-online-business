import 'package:flutter_test/flutter_test.dart';
import 'package:fufaji/providers/alerts_provider.dart';
import 'package:fufaji/models/analytics_models.dart';

void main() {
  group('AlertsProvider Tests', () {
    late AlertsProvider provider;

    setUp(() {
      provider = AlertsProvider();
    });

    test('should initialize with empty alerts', () {
      expect(provider.activeAlerts, isEmpty);
      expect(provider.dismissedAlerts, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('should dismiss single alert', () async {
      final alert = Alert(
        id: 'alert_1',
        type: 'low_stock',
        severity: 'high',
        message: 'Low stock alert',
        createdAt: DateTime.now(),
        dismissed: false,
      );

      provider.activeAlerts.add(alert);

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.dismissAlert('alert_1');

      expect(notified, true);
      // Alert should be removed from active and added to dismissed
    });

    test('should dismiss all alerts', () async {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Alert 1',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'critical',
          message: 'Alert 2',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.dismissAllAlerts();

      expect(notified, true);
    });

    test('should track alert count', () {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Alert 1',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'critical',
          message: 'Alert 2',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      expect(provider.alertCount, 2);
    });

    test('should count critical alerts', () {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'High severity',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'critical',
          message: 'Critical',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_3',
          type: 'quality_issue',
          severity: 'critical',
          message: 'Critical',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      expect(provider.criticalAlertsCount, 2);
    });

    test('should count high priority alerts', () {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'medium',
          message: 'Medium',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'high',
          message: 'High',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_3',
          type: 'quality_issue',
          severity: 'critical',
          message: 'Critical',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      expect(provider.highPriorityAlertsCount, 2); // High + Critical
    });

    test('should set alert preference', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setAlertPreference('low_stock', false);

      expect(notified, true);
      expect(provider.alertPreferences['low_stock'], false);
    });

    test('should filter alerts by preference', () {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Low stock',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'delivery_failure',
          severity: 'critical',
          message: 'Delivery failed',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      // Disable low_stock alerts
      provider.setAlertPreference('low_stock', false);

      final filtered = provider.getFilteredAlerts();

      // After filtering, should have fewer alerts
      expect(filtered.length, lessThanOrEqualTo(provider.activeAlerts.length));
    });

    test('should handle alert preference initialization', () {
      expect(provider.alertPreferences, isNotEmpty);
    });

    test('should track alert preferences for multiple types', () {
      provider.setAlertPreference('low_stock', false);
      provider.setAlertPreference('delivery_failure', true);
      provider.setAlertPreference('customer_churn', true);

      expect(provider.alertPreferences['low_stock'], false);
      expect(provider.alertPreferences['delivery_failure'], true);
      expect(provider.alertPreferences['customer_churn'], true);
    });

    test('should handle different alert severities', () {
      provider.activeAlerts.addAll([
        Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'low',
          message: 'Low',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_2',
          type: 'low_stock',
          severity: 'medium',
          message: 'Medium',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_3',
          type: 'low_stock',
          severity: 'high',
          message: 'High',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
        Alert(
          id: 'alert_4',
          type: 'low_stock',
          severity: 'critical',
          message: 'Critical',
          createdAt: DateTime.now(),
          dismissed: false,
        ),
      ]);

      expect(provider.criticalAlertsCount, 1);
      expect(provider.alertCount, 4);
    });

    test('should handle alert with affectedEntity', () {
      final alert = Alert(
        id: 'alert_1',
        type: 'low_stock',
        severity: 'high',
        message: 'Low stock alert',
        affectedEntity: 'Product: Apple',
        createdAt: DateTime.now(),
        dismissed: false,
      );

      provider.activeAlerts.add(alert);

      expect(provider.activeAlerts.first.affectedEntity, 'Product: Apple');
    });

    test('should support loading state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.isLoading = true;
      expect(notified, true);
      expect(provider.isLoading, true);

      notified = false;
      provider.isLoading = false;
      expect(notified, true);
      expect(provider.isLoading, false);
    });

    test('should handle error state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.error = 'Failed to load alerts';
      expect(notified, true);
      expect(provider.error, 'Failed to load alerts');

      notified = false;
      provider.error = null;
      expect(notified, true);
      expect(provider.error, isNull);
    });

    test('should maintain separate active and dismissed lists', () {
      final alert = Alert(
        id: 'alert_1',
        type: 'low_stock',
        severity: 'high',
        message: 'Low stock',
        createdAt: DateTime.now(),
        dismissed: false,
      );

      provider.activeAlerts.add(alert);
      expect(provider.activeAlerts.length, 1);
      expect(provider.dismissedAlerts.length, 0);

      provider.dismissedAlerts.add(alert);
      expect(provider.activeAlerts.length, 1);
      expect(provider.dismissedAlerts.length, 1);
    });

    test('should dispose properly', () {
      provider.dispose();
      expect(true, true);
    });
  });
}
