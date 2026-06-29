import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/invoice_model.dart';
import '../utils/monetary_value.dart';
import '../services/gst_service.dart';
import 'dart:typed_data';

/// Invoice PDF Generation Service
/// Creates professional invoices for delivery completion
/// Stores invoices in Firebase Storage for retrieval
class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate invoice PDF for order
  /// Returns PDF bytes and stores reference in Firestore
  Future<InvoiceModel> generateInvoice(OrderModel order) async {
    try {
      debugPrint('[Invoice] Generating invoice for order: ${order.id}');

      // Create PDF document
      final pdf = pw.Document();

      // Format items for display
      final itemsTable = order.items
          .map((item) => [
                item.name,
                item.quantity.toString(),
                '₹${item.price.toStringAsFixed(2)}',
                '₹${(item.price * item.quantity).toStringAsFixed(2)}',
              ])
          .toList();

      // Build PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'FUFAJI STORE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Order details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Order #: ${order.orderNumber}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'Date: ${_formatDate(order.createdAt)}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'Time: ${_formatTime(order.createdAt)}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Customer: ${order.customerName}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.Text(
                          'Phone: ${order.customerPhone}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Items table
                pw.TableHelper.fromTextArray(
                  headers: ['Item', 'Qty', 'Price', 'Total'],
                  data: itemsTable,
                  border: pw.TableBorder.all(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellHeight: 30,
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 20),

                // Totals
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:'),
                          pw.Text('₹${order.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Delivery Fee:'),
                          pw.Text('₹${order.deliveryCharge.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tax (5%):'),
                          pw.Text('₹${order.tax.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (order.discount > MonetaryValue(0))
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount:'),
                            pw.Text('-₹${order.discount.toStringAsFixed(2)}'),
                          ],
                        ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            '₹${order.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Footer
                pw.Text(
                  'Payment Method: ${order.paymentMethod.toString().split('.').last}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Thank you for shopping with Fufaji Store!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            );
          },
        ),
      );

      // Get PDF bytes
      final pdfBytes = await pdf.save();

      // Store invoice reference in Firestore
      final invoiceId = 'inv_${order.id}_${DateTime.now().millisecondsSinceEpoch}';
      final invoiceNumber = _generateInvoiceNumber(order.orderNumber);

      // Create InvoiceItem list from order items
      final invoiceItems = order.items
          .map((item) => InvoiceItem(
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.price.toDouble(),
            taxRate: 5.0, // Default 5% GST
            amount: item.totalPrice,
            tax: MonetaryValue(item.totalPrice.toDouble() * 0.05),
          ))
          .toList();

      final invoice = InvoiceModel(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        orderId: order.id,
        customerId: order.customerId,
        customerName: order.customerName,
        shopId: order.shopId ?? '',
        shopName: order.shopName ?? '',
        items: invoiceItems,
        subtotal: order.subtotal,
        totalTax: MonetaryValue(order.subtotal.toDouble() * 0.05),
        discount: order.discount,
        grandTotal: order.totalAmount,
        billingAddress: '${order.deliveryAddress.street}, ${order.deliveryAddress.city}',
        shippingAddress: '${order.deliveryAddress.street}, ${order.deliveryAddress.city}',
        customerEmail: order.customerEmail,
        customerPhone: order.customerPhone,
        issueDate: DateTime.now(),
        paymentMethod: order.paymentMethod.toString(),
        paymentStatus: order.paymentStatus == 'completed' ? PaymentStatus.paid : PaymentStatus.unpaid,
        pdfUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save invoice record to Firestore
      await _firestore.collection('invoices').doc(invoiceId).set({
        ...invoice.toMap(),
        'pdfSize': pdfBytes.length,
        'status': 'generated',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[Invoice] ✅ Invoice generated: $invoiceId (${pdfBytes.length} bytes)');
      return invoice;
    } catch (e) {
      debugPrint('[Invoice] ❌ Error generating invoice: $e');
      rethrow;
    }
  }

  /// Get invoice by ID
  Future<InvoiceModel?> getInvoice(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();
      if (!doc.exists) return null;

      return InvoiceModel.fromDocSnapshot(doc);
    } catch (e) {
      debugPrint('[Invoice] Error fetching invoice: $e');
      return null;
    }
  }

  /// Get all invoices for a customer
  Future<List<InvoiceModel>> getCustomerInvoices(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('invoices')
          .where('customerId', isEqualTo: customerId)
          .orderBy('issueDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => InvoiceModel.fromDocSnapshot(doc))
          .toList();
    } catch (e) {
      debugPrint('[Invoice] Error fetching customer invoices: $e');
      return [];
    }
  }

  /// Get all invoices for a shop
  Future<List<InvoiceModel>> getShopInvoices(
    String shopId, {
    DateTime? startDate,
    DateTime? endDate,
    PaymentStatus? paymentStatus,
  }) async {
    try {
      var query = _firestore
          .collection('invoices')
          .where('shopId', isEqualTo: shopId) as Query;

      if (startDate != null) {
        query = query.where('issueDate', isGreaterThanOrEqualTo: startDate) as Query;
      }

      if (endDate != null) {
        query = query.where('issueDate', isLessThanOrEqualTo: endDate) as Query;
      }

      final snapshot = await query.orderBy('issueDate', descending: true).get();

      var invoices = snapshot.docs
          .map((doc) => InvoiceModel.fromDocSnapshot(doc))
          .toList();

      if (paymentStatus != null) {
        invoices = invoices
            .where((inv) => inv.paymentStatus == paymentStatus)
            .toList();
      }

      return invoices;
    } catch (e) {
      debugPrint('[Invoice] Error fetching shop invoices: $e');
      return [];
    }
  }

  /// Generate PDF bytes for an invoice
  Future<Uint8List> generateInvoicePDF(InvoiceModel invoice) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Invoice ${invoice.invoiceNumber}',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Shop: ${invoice.shopName}'),
              pw.Text('Customer: ${invoice.customerName}'),
              pw.Text('Date: ${invoice.issueDate}'),
              pw.SizedBox(height: 20),
              // Add items table, totals, etc.
              pw.Text('Total: ₹${invoice.grandTotal.toStringAsFixed(2)}'),
            ],
          ),
        ),
      );

      return Uint8List.fromList(await pdf.save());
    } catch (e) {
      debugPrint('[Invoice] Error generating PDF: $e');
      rethrow;
    }
  }

  /// Send invoice via email
  Future<void> sendInvoiceEmail(String invoiceId, String email, Uint8List pdfBytes) async {
    try {
      // Implementation would send email through email service
      debugPrint('[Invoice] Sending invoice $invoiceId to $email');
      // Email sending logic here
    } catch (e) {
      debugPrint('[Invoice] Error sending invoice email: $e');
      rethrow;
    }
  }

  /// Update payment status of an invoice
  Future<void> updatePaymentStatus(String invoiceId, PaymentStatus status) async {
    try {
      await _firestore
          .collection('invoices')
          .doc(invoiceId)
          .update({'paymentStatus': status.json});
      debugPrint('[Invoice] Updated invoice $invoiceId to $status');
    } catch (e) {
      debugPrint('[Invoice] Error updating payment status: $e');
      rethrow;
    }
  }

  /// Generate GST report
  Future<GSTReport> generateGSTReport({
    required DateTime startDate,
    required DateTime endDate,
    String? shopId,
  }) async {
    try {
      var query = _firestore
          .collection('invoices')
          .where('issueDate', isGreaterThanOrEqualTo: startDate)
          .where('issueDate', isLessThanOrEqualTo: endDate) as Query;

      if (shopId != null) {
        query = query.where('shopId', isEqualTo: shopId) as Query;
      }

      final snapshot = await query.get();
      final invoices = snapshot.docs
          .map((doc) => InvoiceModel.fromDocSnapshot(doc))
          .toList();

      double totalTax = 0;
      double totalRevenue = 0;
      final taxBreakdown = <double, double>{};

      for (var invoice in invoices) {
        totalTax += invoice.totalTax.toDouble();
        totalRevenue += invoice.grandTotal.toDouble();

        for (var item in invoice.items) {
          final rate = item.taxRate;
          taxBreakdown[rate] = (taxBreakdown[rate] ?? 0) + item.tax.toDouble();
        }
      }

      return GSTReport(
        period: '${startDate.year}-${startDate.month}-${startDate.day} to ${endDate.year}-${endDate.month}-${endDate.day}',
        generatedAt: DateTime.now(),
        totalSales: totalRevenue,
        taxByRate: taxBreakdown,
        remarks: 'Invoices: ${invoices.length}, Total Tax: $totalTax',
      );
    } catch (e) {
      debugPrint('[Invoice] Error generating GST report: $e');
      rethrow;
    }
  }

  /// Save GST report to Firestore
  Future<void> saveGSTReport(String reportId, GSTReport report) async {
    try {
      await _firestore.collection('gst_reports').doc(reportId).set({
        ...report.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[Invoice] GST report saved: $reportId');
    } catch (e) {
      debugPrint('[Invoice] Error saving GST report: $e');
      rethrow;
    }
  }

  /// Finalize an invoice (mark as immutable)
  Future<void> finalizeInvoice(String invoiceId) async {
    try {
      await _firestore
          .collection('invoices')
          .doc(invoiceId)
          .update({'isImmutable': true});
      debugPrint('[Invoice] Invoice finalized: $invoiceId');
    } catch (e) {
      debugPrint('[Invoice] Error finalizing invoice: $e');
      rethrow;
    }
  }

  /// Generate and print invoice
  Future<void> generateAndPrintInvoice(OrderModel order) async {
    try {
      final invoice = await generateInvoice(order);
      final pdfBytes = await generateInvoicePDF(invoice);
      debugPrint('[Invoice] Invoice ready for printing: ${invoice.invoiceNumber} (${pdfBytes.length} bytes)');
      // Print implementation would go here
    } catch (e) {
      debugPrint('[Invoice] Error generating and printing invoice: $e');
      rethrow;
    }
  }

  // Static methods removed to avoid conflict with instance methods

  // Helpers
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Unknown';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _generateInvoiceNumber(String orderNumber) {
    return 'INV-${orderNumber.toUpperCase()}';
  }
}
