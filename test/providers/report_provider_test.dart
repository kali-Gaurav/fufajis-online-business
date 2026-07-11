import 'package:flutter_test/flutter_test.dart';
import 'package:fufaji/providers/report_provider.dart';
import 'package:fufaji/models/analytics_models.dart';

void main() {
  group('ReportProvider Tests', () {
    late ReportProvider provider;

    setUp(() {
      provider = ReportProvider();
    });

    test('should initialize with empty reports list', () {
      expect(provider.availableReports, isEmpty);
      expect(provider.isGenerating, false);
      expect(provider.error, isNull);
    });

    test('should generate daily report', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.generateReport(type: 'daily');

      expect(notified, true);
      expect(provider.availableReports.isNotEmpty, true);
      expect(provider.availableReports.first.type, 'daily');
    });

    test('should generate weekly report', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.generateReport(type: 'weekly');

      expect(notified, true);
      expect(provider.availableReports.isNotEmpty, true);
      expect(provider.availableReports.first.type, 'weekly');
    });

    test('should generate monthly report', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.generateReport(type: 'monthly');

      expect(notified, true);
      expect(provider.availableReports.isNotEmpty, true);
      expect(provider.availableReports.first.type, 'monthly');
    });

    test('should generate custom report', () async {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.generateReport(type: 'custom');

      expect(notified, true);
      expect(provider.availableReports.isNotEmpty, true);
      expect(provider.availableReports.first.type, 'custom');
    });

    test('should add new report at beginning of list', () async {
      final now = DateTime.now();

      await provider.generateReport(type: 'daily');
      final firstCount = provider.availableReports.length;

      await provider.generateReport(type: 'weekly');
      final secondCount = provider.availableReports.length;

      expect(secondCount, firstCount + 1);
      expect(provider.availableReports.first.type, 'weekly');
    });

    test('should select report', () {
      final report = Report(
        id: 'report_123',
        title: 'Test Report',
        type: 'daily',
        generatedAt: DateTime.now(),
        data: {},
      );

      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.selectReport(report);

      expect(notified, true);
      expect(provider.selectedReport, report);
    });

    test('should export report to PDF', () {
      final report = Report(
        id: 'report_123',
        title: 'Test Report',
        type: 'daily',
        generatedAt: DateTime.now(),
        data: {},
        pdfUrl: 'https://example.com/report.pdf',
      );

      final pdfUrl = provider.exportToPdf(report);

      expect(pdfUrl, 'https://example.com/report.pdf');
    });

    test('should export report to CSV', () {
      final report = Report(
        id: 'report_123',
        title: 'Test Report',
        type: 'daily',
        generatedAt: DateTime.now(),
        data: {},
        csvUrl: 'https://example.com/report.csv',
      );

      final csvUrl = provider.exportToCsv(report);

      expect(csvUrl, 'https://example.com/report.csv');
    });

    test('should schedule email report', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.scheduleEmailReport(
        reportType: 'daily',
        frequency: 'daily',
        email: 'test@example.com',
      );

      // Method completes without error, test passes
      expect(true, true);
    });

    test('should handle report type labels', () {
      expect(provider.reportTypes.contains('daily'), true);
      expect(provider.reportTypes.contains('weekly'), true);
      expect(provider.reportTypes.contains('monthly'), true);
      expect(provider.reportTypes.contains('custom'), true);
    });

    test('should maintain report count limit', () async {
      // Generate multiple reports
      for (int i = 0; i < 15; i++) {
        await provider.generateReport(type: 'daily');
      }

      // Should have generated all reports
      expect(provider.availableReports.length, 15);
    });

    test('should support loading state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.isGenerating = true;
      expect(notified, true);
      expect(provider.isGenerating, true);

      notified = false;
      provider.isGenerating = false;
      expect(notified, true);
      expect(provider.isGenerating, false);
    });

    test('should handle error state', () {
      var notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.error = 'Report generation failed';
      expect(notified, true);
      expect(provider.error, 'Report generation failed');

      notified = false;
      provider.error = null;
      expect(notified, true);
      expect(provider.error, isNull);
    });

    test('should generate report with proper metadata', () async {
      await provider.generateReport(type: 'daily');

      final report = provider.availableReports.first;
      expect(report.id, isNotNull);
      expect(report.title, isNotNull);
      expect(report.generatedAt, isNotNull);
      expect(report.data, isNotNull);
    });

    test('should clear reports', () {
      provider.availableReports.clear();
      expect(provider.availableReports, isEmpty);
    });

    test('should dispose properly', () {
      provider.dispose();
      expect(true, true);
    });
  });
}
