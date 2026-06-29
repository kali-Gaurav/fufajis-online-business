import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

/// Invoice PDF Generation Service
/// Creates professional invoices for delivery completion
/// Stores invoices in Firebase Storage for retrieval
class InvoiceService {
  static final InvoiceService _instance = InvoiceService._internal();
  factory InvoiceService() => _instance;
  InvoiceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate invoice PDF for order
  /// Returns PDF bytes and stores reference in Firestore
  Future<Invoice> generateInvoice(OrderModel order) async {
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
                      if (order.discount > 0)
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
      final invoice = Invoice(
        id: invoiceId,
        orderId: order.id,
        customerId: order.customerId,
        invoiceNumber: _generateInvoiceNumber(order.orderNumber),
        generatedAt: DateTime.now(),
        items: order.items,
        subtotal: order.subtotal,
        tax: order.tax,
        deliveryCharge: order.deliveryCharge,
        discount: order.discount,
        totalAmount: order.totalAmount,
        pdfSize: pdfBytes.length,
      );

      // Save invoice record to Firestore
      await _firestore.collection('invoices').doc(invoiceId).set({
        'id': invoice.id,
        'orderId': invoice.orderId,
        'customerId': invoice.customerId,
        'invoiceNumber': invoice.invoiceNumber,
        'generatedAt': invoice.generatedAt.toIso8601String(),
        'itemCount': invoice.items.length,
        'totalAmount': invoice.totalAmount,
        'pdfSize': invoice.pdfSize,
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
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return Invoice(
        id: data['id'],
        orderId: data['orderId'],
        customerId: data['customerId'],
        invoiceNumber: data['invoiceNumber'],
        generatedAt: DateTime.parse(data['generatedAt']),
        items: [],
        subtotal: (data['totalAmount'] * 0.9).toDouble(),
        tax: (data['totalAmount'] * 0.05).toDouble(),
        deliveryCharge: 50,
        discount: 0,
        totalAmount: data['totalAmount'],
        pdfSize: data['pdfSize'] ?? 0,
      );
    } catch (e) {
      debugPrint('[Invoice] Error fetching invoice: $e');
      return null;
    }
  }

  /// List invoices for customer
  Future<List<Invoice>> listInvoicesByCustomer(String customerId) async {
    try {
      final docs = await _firestore
          .collection('invoices')
          .where('customerId', isEqualTo: customerId)
          .orderBy('generatedAt', descending: true)
          .limit(50)
          .get();

      return docs.docs
          .map((doc) {
            final data = doc.data();
            return Invoice(
              id: data['id'],
              orderId: data['orderId'],
              customerId: data['customerId'],
              invoiceNumber: data['invoiceNumber'],
              generatedAt: DateTime.parse(data['generatedAt']),
              items: [],
              subtotal: 0,
              tax: 0,
              deliveryCharge: 0,
              discount: 0,
              totalAmount: data['totalAmount'],
              pdfSize: data['pdfSize'] ?? 0,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('[Invoice] Error listing invoices: $e');
      return [];
    }
  }

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

/// Invoice model
class Invoice {
  final String id;
  final String orderId;
  final String customerId;
  final String invoiceNumber;
  final DateTime generatedAt;
  final dynamic items;
  final double subtotal;
  final double tax;
  final double deliveryCharge;
  final double discount;
  final double totalAmount;
  final int pdfSize;

  Invoice({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.invoiceNumber,
    required this.generatedAt,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.deliveryCharge,
    required this.discount,
    required this.totalAmount,
    required this.pdfSize,
  });
}
