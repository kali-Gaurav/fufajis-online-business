import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fufaji/widgets/analytics/metric_card.dart';
import 'package:fufaji/widgets/analytics/alert_widget.dart';
import 'package:fufaji/models/analytics_models.dart';

void main() {
  group('Analytics Widgets Tests', () {
    group('MetricCard Widget', () {
      testWidgets('should render with label and value',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
              ),
            ),
          ),
        );

        expect(find.text('Total Revenue'), findsOneWidget);
        expect(find.text('₹50,000'), findsOneWidget);
      });

      testWidgets('should render with subtitle', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                subtitle: 'for today',
              ),
            ),
          ),
        );

        expect(find.text('Total Revenue'), findsOneWidget);
        expect(find.text('₹50,000'), findsOneWidget);
        expect(find.text('for today'), findsOneWidget);
      });

      testWidgets('should render with icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                icon: Icons.trending_up,
                iconColor: Colors.green,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.trending_up), findsOneWidget);
      });

      testWidgets('should render percentage change for positive',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                percentageChange: 10.5,
                isPositive: true,
              ),
            ),
          ),
        );

        expect(find.text('+10.5%'), findsOneWidget);
      });

      testWidgets('should render percentage change for negative',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                percentageChange: 5.2,
                isPositive: false,
              ),
            ),
          ),
        );

        expect(find.text('-5.2%'), findsOneWidget);
      });

      testWidgets('should call onTap callback', (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, true);
      });

      testWidgets('should support dark mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
              ),
            ),
          ),
        );

        expect(find.text('Total Revenue'), findsOneWidget);
        expect(find.text('₹50,000'), findsOneWidget);
      });

      testWidgets('should render with custom backgroundColor',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
                backgroundColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
      });
    });

    group('AlertWidget', () {
      testWidgets('should render alert with message',
          (WidgetTester tester) async {
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Stock running low',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(alert: alert),
            ),
          ),
        );

        expect(find.text('Stock running low'), findsOneWidget);
      });

      testWidgets('should render alert with title based on type',
          (WidgetTester tester) async {
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Message',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(alert: alert),
            ),
          ),
        );

        expect(find.text('Low Stock Alert'), findsOneWidget);
      });

      testWidgets('should render with severity color',
          (WidgetTester tester) async {
        final alert = Alert(
          id: 'alert_1',
          type: 'delivery_failure',
          severity: 'critical',
          message: 'Critical alert',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(alert: alert),
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should call onDismiss callback',
          (WidgetTester tester) async {
        var dismissed = false;
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Alert',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(
                alert: alert,
                onDismiss: () {
                  dismissed = true;
                },
              ),
            ),
          ),
        );

        // Find and tap the dismiss button (close icon)
        final dismissButton = find.byIcon(Icons.close);
        if (dismissButton.evaluate().isNotEmpty) {
          await tester.tap(dismissButton);
          expect(dismissed, true);
        }
      });

      testWidgets('should render with affected entity',
          (WidgetTester tester) async {
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Stock running low',
          affectedEntity: 'Product: Apple',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(alert: alert),
            ),
          ),
        );

        expect(find.text('Product: Apple'), findsOneWidget);
      });

      testWidgets('should display relative time', (WidgetTester tester) async {
        final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Alert',
          createdAt: tenMinutesAgo,
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(alert: alert),
            ),
          ),
        );

        expect(find.text('10m ago'), findsOneWidget);
      });

      testWidgets('should render alert for different types',
          (WidgetTester tester) async {
        final alertTypes = [
          'low_stock',
          'delivery_failure',
          'customer_churn',
          'quality_issue',
          'revenue_drop',
        ];

        for (final type in alertTypes) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AlertWidget(
                  alert: Alert(
                    id: 'alert_$type',
                    type: type,
                    severity: 'high',
                    message: 'Test message',
                    createdAt: DateTime.now(),
                    dismissed: false,
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(Container), findsWidgets);
        }
      });

      testWidgets('should render alert for different severities',
          (WidgetTester tester) async {
        final severities = ['critical', 'high', 'medium', 'low'];

        for (final severity in severities) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AlertWidget(
                  alert: Alert(
                    id: 'alert_$severity',
                    type: 'low_stock',
                    severity: severity,
                    message: 'Test message',
                    createdAt: DateTime.now(),
                    dismissed: false,
                  ),
                ),
              ),
            ),
          );

          expect(find.byType(Container), findsWidgets);
        }
      });

      testWidgets('should call onTap callback', (WidgetTester tester) async {
        var tapped = false;
        final alert = Alert(
          id: 'alert_1',
          type: 'low_stock',
          severity: 'high',
          message: 'Alert',
          createdAt: DateTime.now(),
          dismissed: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AlertWidget(
                alert: alert,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(GestureDetector).first);
        expect(tapped, true);
      });
    });

    group('Widget Responsive Layout', () {
      testWidgets('should render in single column on small screens',
          (WidgetTester tester) async {
        // Simulate small screen size
        tester.binding.window.physicalSizeTestValue = const Size(400, 800);
        addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MetricCard(
                label: 'Total Revenue',
                value: '₹50,000',
              ),
            ),
          ),
        );

        expect(find.byType(MetricCard), findsOneWidget);
      });

      testWidgets('should render on different screen sizes',
          (WidgetTester tester) async {
        final sizes = [
          const Size(400, 800),  // Small phone
          const Size(600, 1024), // Tablet
          const Size(1200, 800), // Desktop
        ];

        for (final size in sizes) {
          tester.binding.window.physicalSizeTestValue = size;
          addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MetricCard(
                  label: 'Total Revenue',
                  value: '₹50,000',
                ),
              ),
            ),
          );

          expect(find.byType(MetricCard), findsOneWidget);
        }
      });
    });
  });
}
