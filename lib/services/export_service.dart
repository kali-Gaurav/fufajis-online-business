import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// Service for exporting analytics and order data to various formats
class ExportService {
  static final ExportService _instance = ExportService._internal();

  factory ExportService() => _instance;

  ExportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Export orders to CSV format
  /// Returns the file path of the exported CSV
  Future<String> exportOrdersToCSV({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint('[ExportService] Exporting orders to CSV from $startDate to $endDate');

      // Fetch orders
      final orders = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      // Prepare CSV header
      const csvHeader =
          'Order ID,Customer Name,Order Date,Total Amount,Status,Payment Method,Delivery Status\n';

      StringBuffer csvContent = StringBuffer(csvHeader);

      // Add order rows
      for (var doc in orders.docs) {
        final data = doc.data();
        final orderId = doc.id;
        final customerName = data['customerName'] as String? ?? 'Unknown';
        final createdAt = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate().toString()
            : 'N/A';
        final totalAmount = data['totalAmount'] as num? ?? 0;
        final status = data['status'] as String? ?? 'unknown';
        final paymentMethod = data['paymentMethod'] as String? ?? 'unknown';
        final deliveryStatus = data['deliveryStatus'] as String? ?? 'N/A';

        csvContent.writeln(
          '$orderId,"$customerName",$createdAt,${totalAmount.toStringAsFixed(2)},$status,$paymentMethod,$deliveryStatus',
        );
      }

      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/orders_export_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());

      debugPrint('[ExportService] Orders exported to CSV: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting orders to CSV: $e');
      rethrow;
    }
  }

  /// Export orders to Excel format (TSV for spreadsheet compatibility)
  Future<String> exportOrdersToExcel({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
          '[ExportService] Exporting orders to Excel format from $startDate to $endDate');

      // Fetch orders
      final orders = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();

      // Prepare TSV header (tab-separated for Excel)
      const tsvHeader =
          'Order ID\tCustomer Name\tOrder Date\tTotal Amount\tStatus\tPayment Method\tDelivery Status\n';

      StringBuffer tsvContent = StringBuffer(tsvHeader);

      // Add order rows
      for (var doc in orders.docs) {
        final data = doc.data();
        final orderId = doc.id;
        final customerName = data['customerName'] as String? ?? 'Unknown';
        final createdAt = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
            : 'N/A';
        final totalAmount = data['totalAmount'] as num? ?? 0;
        final status = data['status'] as String? ?? 'unknown';
        final paymentMethod = data['paymentMethod'] as String? ?? 'unknown';
        final deliveryStatus = data['deliveryStatus'] as String? ?? 'N/A';

        tsvContent.writeln(
          '$orderId\t$customerName\t$createdAt\t${totalAmount.toStringAsFixed(2)}\t$status\t$paymentMethod\t$deliveryStatus',
        );
      }

      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/orders_export_$timestamp.xlsx';
      final file = File(filePath);
      await file.writeAsString(tsvContent.toString());

      debugPrint('[ExportService] Orders exported to Excel format: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting orders to Excel: $e');
      rethrow;
    }
  }

  /// Export analytics report as text (can be enhanced to PDF)
  Future<String> exportAnalyticsReport({
    required String period,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      debugPrint('[ExportService] Exporting analytics report for period: $period');

      StringBuffer report = StringBuffer();

      // Report header
      report.writeln('FUFAJI STORE - ANALYTICS REPORT');
      report.writeln('Period: $period');
      report.writeln('Generated: ${DateTime.now()}');
      report.writeln('=' * 60);
      report.writeln('');

      // Revenue section
      report.writeln('REVENUE METRICS');
      report.writeln('-' * 60);
      report.writeln('Total Revenue: ₹${(metrics['totalRevenue'] as num? ?? 0).toStringAsFixed(2)}');
      report.writeln('Growth: ${(metrics['revenueGrowth'] as num? ?? 0).toStringAsFixed(2)}%');
      report.writeln('');

      // Order section
      report.writeln('ORDER METRICS');
      report.writeln('-' * 60);
      report.writeln('Total Orders: ${metrics['totalOrders'] ?? 0}');
      report.writeln('Delivered: ${metrics['deliveredOrders'] ?? 0}');
      report.writeln('Cancelled: ${metrics['cancelledOrders'] ?? 0}');
      report.writeln('Average Order Value: ₹${(metrics['avgOrderValue'] as num? ?? 0).toStringAsFixed(2)}');
      report.writeln('');

      // Customer section
      report.writeln('CUSTOMER METRICS');
      report.writeln('-' * 60);
      report.writeln('Total Customers: ${metrics['totalCustomers'] ?? 0}');
      report.writeln('New Customers: ${metrics['newCustomers'] ?? 0}');
      report.writeln('Repeat Customers: ${metrics['repeatCustomers'] ?? 0}');
      report.writeln('');

      // Delivery section
      report.writeln('DELIVERY METRICS');
      report.writeln('-' * 60);
      report.writeln('On-Time Delivery Rate: ${(metrics['onTimeDeliveryRate'] as num? ?? 0).toStringAsFixed(2)}%');
      report.writeln('Failed Deliveries: ${metrics['failedDeliveryRate'] as num? ?? 0}%');
      report.writeln('Average Delivery Time: ${(metrics['avgDeliveryTime'] as num? ?? 0).toStringAsFixed(0)} minutes');
      report.writeln('');

      // Profit section
      report.writeln('PROFIT METRICS');
      report.writeln('-' * 60);
      report.writeln('Gross Profit: ₹${(metrics['grossProfit'] as num? ?? 0).toStringAsFixed(2)}');
      report.writeln('Profit Margin: ${(metrics['profitMargin'] as num? ?? 0).toStringAsFixed(2)}%');
      report.writeln('');

      report.writeln('=' * 60);
      report.writeln('End of Report');

      // Write to file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/analytics_report_$timestamp.txt';
      final file = File(filePath);
      await file.writeAsString(report.toString());

      debugPrint('[ExportService] Analytics report exported: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting analytics report: $e');
      rethrow;
    }
  }

  /// Send daily report email to owner
  Future<void> sendDailyReport({required String email}) async {
    try {
      debugPrint('[ExportService] Sending daily report to $email');

      // This would integrate with an email service
      // For now, just log the action
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('[ExportService] Daily report email queued for $email');
    } catch (e) {
      debugPrint('[ExportService] Error sending daily report: $e');
      rethrow;
    }
  }

  /// Schedule weekly report generation
  Future<void> scheduleWeeklyReport() async {
    try {
      debugPrint('[ExportService] Scheduling weekly report');

      // This would be implemented with a background job scheduler
      // For now, just log the action
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('[ExportService] Weekly report scheduled');
    } catch (e) {
      debugPrint('[ExportService] Error scheduling weekly report: $e');
      rethrow;
    }
  }

  /// Export products inventory to CSV
  Future<String> exportInventoryToCSV() async {
    try {
      debugPrint('[ExportService] Exporting inventory to CSV');

      final products = await _firestore.collection('products').get();

      const csvHeader =
          'Product ID,Product Name,Stock,Min Stock,Price,Category,Last Restocked\n';

      StringBuffer csvContent = StringBuffer(csvHeader);

      for (var doc in products.docs) {
        final data = doc.data();
        final productId = doc.id;
        final name = (data['name'] as String? ?? 'Unknown').replaceAll(',', ';');
        final stock = data['stock'] as int? ?? 0;
        final minStock = data['minStock'] as int? ?? 0;
        final price = data['price'] as num? ?? 0;
        final category = data['category'] as String? ?? 'Uncategorized';
        final lastRestocked = data['lastRestocked'] != null
            ? (data['lastRestocked'] as Timestamp).toDate().toString().split(' ')[0]
            : 'Never';

        csvContent.writeln(
          '$productId,"$name",$stock,$minStock,${price.toStringAsFixed(2)},$category,$lastRestocked',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/inventory_export_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());

      debugPrint('[ExportService] Inventory exported to CSV: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting inventory: $e');
      rethrow;
    }
  }

  /// Export employee performance to CSV
  Future<String> exportEmployeePerformanceToCSV() async {
    try {
      debugPrint('[ExportService] Exporting employee performance to CSV');

      final employees = await _firestore.collection('employees').get();

      const csvHeader =
          'Employee ID,Employee Name,Role,Orders Packed,Quality Score,Avg Time Per Order,Rating\n';

      StringBuffer csvContent = StringBuffer(csvHeader);

      for (var doc in employees.docs) {
        final data = doc.data();
        final employeeId = doc.id;
        final name = data['name'] as String? ?? 'Unknown';
        final role = data['role'] as String? ?? 'Employee';
        final ordersPacked = data['ordersPacked'] as int? ?? 0;
        final qualityScore = (data['qualityScore'] as num? ?? 0).toStringAsFixed(2);
        final avgTimePerOrder = (data['avgTimePerOrder'] as num? ?? 0).toStringAsFixed(2);
        final rating = (data['rating'] as num? ?? 0).toStringAsFixed(2);

        csvContent.writeln(
          '$employeeId,"$name",$role,$ordersPacked,$qualityScore,$avgTimePerOrder,$rating',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/employee_performance_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());

      debugPrint(
          '[ExportService] Employee performance exported to CSV: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting employee performance: $e');
      rethrow;
    }
  }

  /// Export all data associated with a user for GDPR/DPDP compliance
  /// Returns the file path of the generated JSON file
  Future<String> exportUserData(String userId) async {
    try {
      debugPrint('[ExportService] Starting GDPR/DPDP data export for user: $userId');
      
      // 1. Fetch user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final profile = userDoc.exists ? userDoc.data() : <String, dynamic>{};
      
      // 2. Fetch orders
      final ordersSnap = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: userId)
          .get();
      final orders = ordersSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      
      // 3. Fetch wallet transactions
      final walletSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wallet_transactions')
          .get();
      final walletTransactions = walletSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      
      // 4. Fetch support tickets
      final ticketsSnap = await _firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: userId)
          .get();
      final supportTickets = ticketsSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // Compile into JSON
      final exportData = {
        'exporter': 'Fufaji Store Privacy Portal',
        'exportTimestamp': DateTime.now().toIso8601String(),
        'userId': userId,
        'profile': profile,
        'orders': orders,
        'walletTransactions': walletTransactions,
        'supportTickets': supportTickets,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/fufaji_user_data_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);
      
      debugPrint('[ExportService] GDPR data export completed: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting user data: $e');
      rethrow;
    }
  }

  /// Export cash settlements and payouts to CSV for a period
  Future<String> exportSettlementsToCSV({required String period}) async {
    try {
      debugPrint('[ExportService] Exporting settlements to CSV for $period');
      
      final settlements = await _firestore.collection('cod_settlements').get();
      
      const csvHeader = 'Settlement ID,Rider Name,Collected Amount,Settled Amount,Status,Date\n';
      StringBuffer csvContent = StringBuffer(csvHeader);
      
      for (var doc in settlements.docs) {
        final data = doc.data();
        final id = doc.id;
        final riderName = data['riderName'] as String? ?? 'Rider';
        final collected = data['collectedAmount'] as num? ?? 0.0;
        final settled = data['settledAmount'] as num? ?? 0.0;
        final status = data['status'] as String? ?? 'Pending';
        final date = data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
            : 'N/A';
            
        csvContent.writeln('$id,"$riderName",${collected.toStringAsFixed(2)},${settled.toStringAsFixed(2)},$status,$date');
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/settlements_export_$timestamp.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());
      
      return filePath;
    } catch (e) {
      debugPrint('[ExportService] Error exporting settlements: $e');
      rethrow;
    }
  }
}
