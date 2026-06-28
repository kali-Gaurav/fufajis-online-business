import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/invoice_model.dart';
import '../config/app_config.dart';
import 'package:intl/intl.dart';
import 'gst_service.dart';
import '../utils/pdf_theme.dart';

class InvoiceService {
  /// Generates a professional Invoice ID and updates Firestore
  static Future<String> finalizeInvoice(String orderId) async {
    final year = DateTime.now().year;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final invoiceId = "INV-$year-$timestamp";
    
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'invoiceId': invoiceId,
      'invoiceGeneratedAt': FieldValue.serverTimestamp(),
    });
    
    return invoiceId;
  }

  /// Generate and print/share an invoice for [order].
  ///
  /// Supports thermal (58 mm / 80 mm) and A4 page formats.
  /// Pass [pageFormat] to override – defaults to A4.
  static Future<void> generateAndPrintInvoice(
    OrderModel order, {
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    // Thermal widths (58 mm ≈ 164 pt, 80 mm ≈ 227 pt)
    final isThermal = pageFormat.width < 300;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: isThermal
            ? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8)
            : const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: isThermal ? 14 : 22,
                          color: PdfAppTheme.info900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Fufaji's Online Business",
                        style: pw.TextStyle(
                            font: boldFont, fontSize: isThermal ? 10 : 14),
                      ),
                      pw.Text(
                        'Routemaster Intelligent Systems Pvt. Ltd.',
                        style: pw.TextStyle(
                            font: font, fontSize: isThermal ? 8 : 10),
                      ),
                      pw.Text(
                        AppConfig.shopAddress,
                        style: pw.TextStyle(
                            font: font, fontSize: isThermal ? 7 : 9),
                      ),
                      pw.Text(
                        'Ph: ${AppConfig.shopPhone}',
                        style: pw.TextStyle(
                            font: font, fontSize: isThermal ? 7 : 9),
                      ),
                      pw.Text(
                        'GSTIN: 08AAACF1234A1Z1',
                        style: pw.TextStyle(
                            font: font, fontSize: isThermal ? 7 : 9),
                      ),
                    ],
                  ),
                  if (!isThermal)
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data:
                            'https://fufajionline.com/track/${order.orderNumber}',
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: isThermal ? 8 : 20),

              // ── QR / Order ID section ────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Order Reference: ${order.orderNumber}',
                      style: pw.TextStyle(
                          font: boldFont, fontSize: isThermal ? 8 : 10),
                    ),
                    pw.Text(
                      'Order ID: ${order.id}',
                      style: pw.TextStyle(
                          font: font, fontSize: isThermal ? 7 : 8),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: isThermal ? 6 : 16),

              // ── Bill To & Order Info ─────────────────────────────────
              if (!isThermal)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO:',
                            style: pw.TextStyle(
                                font: boldFont, fontSize: 10)),
                        pw.Text(order.customerName,
                            style: pw.TextStyle(
                                font: boldFont, fontSize: 12)),
                        pw.Text(order.customerPhone,
                            style:
                                pw.TextStyle(font: font, fontSize: 10)),
                        pw.Container(
                          width: 200,
                          child: pw.Text(
                            order.deliveryAddress.fullAddress,
                            style:
                                pw.TextStyle(font: font, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          'Payment: ${order.paymentMethod.toString().split('.').last.toUpperCase()}',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                )
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(order.customerName,
                        style:
                            pw.TextStyle(font: boldFont, fontSize: 9)),
                    pw.Text(order.customerPhone,
                        style: pw.TextStyle(font: font, fontSize: 8)),
                    pw.Text(
                        DateFormat('dd MMM yyyy')
                            .format(order.createdAt),
                        style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),
              pw.SizedBox(height: isThermal ? 6 : 20),

              // ── Items Table ──────────────────────────────────────────
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Item', boldFont, 9),
                      _cell('Qty', boldFont, 9),
                      _cell('Rate', boldFont, 9),
                      _cell('Amt', boldFont, 9),
                    ],
                  ),
                  ...order.items.map((item) => pw.TableRow(
                        children: [
                          _cell(item.productName, font, 8),
                          _cell('${item.quantity}', font, 8),
                          _cell(
                              'Rs ${item.price.toStringAsFixed(2)}',
                              font,
                              8),
                          _cell(
                              'Rs ${item.totalPrice.toStringAsFixed(2)}',
                              boldFont,
                              8),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: isThermal ? 6 : 16),

              // ── Totals ───────────────────────────────────────────────
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _summaryRow('Subtotal',
                          order.subtotal.toDouble(), font, isThermal),
                      _summaryRow('Delivery',
                          order.deliveryCharge.toDouble(), font, isThermal),
                      if (order.discount.toDouble() > 0)
                        _summaryRow(
                            'Discount', -order.discount.toDouble(), font, isThermal),
                      // GST – configurable; currently 0% as per shop setup
                      _summaryRow(
                          'GST (0%)', 0.0, font, isThermal,
                          note: true),
                      pw.Divider(color: PdfColors.grey400),
                      pw.Row(
                        children: [
                          pw.Text('GRAND TOTAL: ',
                              style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: isThermal ? 10 : 14)),
                          pw.Text(
                            'Rs ${order.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: isThermal ? 10 : 14,
                              color: PdfAppTheme.info900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Center(
                child: pw.Text(
                  'Thank you for shopping with Fufaji\'s Online!',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: isThermal ? 8 : 10,
                      color: PdfColors.grey600),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Computer generated invoice. No signature required.',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: isThermal ? 7 : 8,
                      color: PdfColors.grey400),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<List<InvoiceModel>> getCustomerInvoices(String customerId) async {
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('customerId', isEqualTo: customerId)
        .orderBy('issueDate', descending: true)
        .get();
    return snap.docs.map((doc) => InvoiceModel.fromDocSnapshot(doc)).toList();
  }

  static Future<List<InvoiceModel>> getShopInvoices(
    String shopId, {
    DateTime? startDate,
    DateTime? endDate,
    PaymentStatus? paymentStatus,
  }) async {
    Query query = FirebaseFirestore.instance
        .collection('invoices')
        .where('shopId', isEqualTo: shopId);

    if (startDate != null) {
      query = query.where('issueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('issueDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    if (paymentStatus != null) {
      query = query.where('paymentStatus', isEqualTo: paymentStatus.json);
    }

    final snap = await query.get();
    return snap.docs.map((doc) => InvoiceModel.fromDocSnapshot(doc)).toList();
  }

  static Future<InvoiceModel?> getInvoice(String invoiceId) async {
    final doc = await FirebaseFirestore.instance
        .collection('invoices')
        .doc(invoiceId)
        .get();
    if (!doc.exists) return null;
    return InvoiceModel.fromDocSnapshot(doc);
  }

  static Future<Uint8List> generateInvoicePDF(InvoiceModel invoice) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TAX INVOICE', style: pw.TextStyle(font: boldFont, fontSize: 22)),
              pw.SizedBox(height: 10),
              pw.Text('Invoice #: ${invoice.invoiceNumber}', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.Text('Date: ${DateFormat('dd MMM yyyy').format(invoice.issueDate)}', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 20),
              pw.Text('BILL TO:', style: pw.TextStyle(font: boldFont, fontSize: 10)),
              pw.Text(invoice.customerName, style: pw.TextStyle(font: boldFont, fontSize: 12)),
              if (invoice.billingAddress != null) pw.Text(invoice.billingAddress!, style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Item', boldFont, 9),
                      _cell('Qty', boldFont, 9),
                      _cell('Rate', boldFont, 9),
                      _cell('Amt', boldFont, 9),
                    ],
                  ),
                  ...invoice.items.map((item) => pw.TableRow(
                        children: [
                          _cell(item.productName, font, 8),
                          _cell('${item.quantity}', font, 8),
                          _cell('Rs ${item.unitPrice.toStringAsFixed(2)}', font, 8),
                          _cell('Rs ${item.amount.toStringAsFixed(2)}', boldFont, 8),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: Rs ${invoice.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Tax: Rs ${invoice.totalTax.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 10)),
                      if (invoice.discount.toDouble() > 0) pw.Text('Discount: -Rs ${invoice.discount.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Divider(),
                      pw.Text('GRAND TOTAL: Rs ${invoice.grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<void> sendInvoiceEmail(String invoiceId, String email, Uint8List pdfBytes) async {
    debugPrint('[InvoiceService] Sending invoice $invoiceId to $email');
  }

  static Future<void> updatePaymentStatus(String invoiceId, PaymentStatus status) async {
    await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).update({
      'paymentStatus': status.json,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<GSTReport> generateGSTReport(
    String shopId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final invoices = await getShopInvoices(shopId, startDate: startDate, endDate: endDate);
    
    double totalSales = 0;
    Map<double, double> taxByRate = {};

    for (var inv in invoices) {
      totalSales += inv.subtotal.toDouble();
      final breakdown = inv.getTaxBreakdown();
      for (var entry in breakdown.entries) {
        taxByRate[entry.key] = (taxByRate[entry.key] ?? 0) + entry.value;
      }
    }

    return GSTReport(
      period: "${DateFormat('MMM yyyy').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}",
      generatedAt: DateTime.now(),
      totalSales: totalSales,
      taxByRate: taxByRate,
    );
  }

  static Future<void> saveGSTReport(String shopId, GSTReport report) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('gst_reports')
        .add(report.toMap());
  }

  static pw.Widget _cell(String text, pw.Font font, double size) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: size)),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    double value,
    pw.Font font,
    bool compact, {
    bool note = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  font: font,
                  fontSize: compact ? 8 : 10,
                  color: note ? PdfColors.grey500 : PdfColors.black)),
          pw.Text(
            note ? 'Included' : 'Rs ${value.toStringAsFixed(2)}',
            style: pw.TextStyle(
                font: font,
                fontSize: compact ? 8 : 10,
                color: note ? PdfColors.grey500 : PdfColors.black),
          ),
        ],
      ),
    );
  }
}
