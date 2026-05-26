import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';

class InvoiceService {
  static Future<void> generateAndPrintInvoice(OrderModel order) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

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
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TAX INVOICE', style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blue900)),
                      pw.Text('Fufaji Online Business', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                      pw.Text('Jaipur, Rajasthan, India', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('GSTIN: 08AAACF1234A1Z1', style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                  pw.Container(
                    height: 60,
                    width: 60,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://fufajionline.com/track/${order.orderNumber}',
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Bill To & Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.Text(order.customerName, style: pw.TextStyle(font: boldFont, fontSize: 12)),
                      pw.Text(order.customerPhone, style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Container(
                        width: 200,
                        child: pw.Text(order.deliveryAddress.fullAddress, style: pw.TextStyle(font: font, fontSize: 10)),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Order #: ${order.orderNumber}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Payment: ${order.paymentMethod.toString().split('.').last.toUpperCase()}', style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Item Description', style: pw.TextStyle(font: boldFont, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Qty', style: pw.TextStyle(font: boldFont, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Price', style: pw.TextStyle(font: boldFont, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total', style: pw.TextStyle(font: boldFont, fontSize: 10))),
                    ],
                  ),
                  // Table Items
                  ...order.items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item.productName, style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${item.quantity}', style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs ${item.price.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs ${item.totalPrice.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 9, fontBold: boldFont))),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildSummaryRow('Subtotal', order.subtotal, font),
                      _buildSummaryRow('Delivery Charge', order.deliveryCharge, font),
                      if (order.discount > 0) _buildSummaryRow('Discount', -order.discount, font),
                      pw.Divider(color: PdfColors.grey400),
                      pw.Row(
                        children: [
                          pw.Text('GRAND TOTAL: ', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                          pw.Text('Rs ${order.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blue900)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Inclusive of GST (5%)', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Center(
                child: pw.Text('Thank you for shopping with Fufaji Online!', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
              ),
              pw.Center(
                child: pw.Text('This is a computer generated invoice and does not require a signature.', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey400)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildSummaryRow(String label, double value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text('Rs ${value.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }
}
