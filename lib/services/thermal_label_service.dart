import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order_model.dart';
import '../models/product_model.dart';

/// Generates price labels and order labels, and provides PDF output
/// for standard printers. Bluetooth thermal printing is handled via
/// a platform channel stub so the rest of the app compiles without
/// the optional BlueThermalPrinter plugin being present.
class ThermalLabelService {
  static const _channel = MethodChannel('fufaji/thermal_printer');

  // ── Price label ──────────────────────────────────────────────────────────

  /// Generates a single price-label PDF page (58 mm × 40 mm) for [product].
  Future<Uint8List> generatePriceLabel(ProductModel product) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          58 * PdfPageFormat.mm,
          40 * PdfPageFormat.mm,
          marginAll: 3 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                product.name,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 2,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                product.unit,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '₹${product.price.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (product.originalPrice != null &&
                      product.originalPrice! > product.price)
                    pw.Text(
                      'MRP ₹${product.originalPrice!.toStringAsFixed(0)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        decoration: pw.TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 2),
              // Barcode representation using product barcode/id
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: product.barcode.isNotEmpty
                    ? product.barcode
                    : product.id,
                height: 20,
                width: double.infinity,
                drawText: true,
                textStyle: const pw.TextStyle(fontSize: 6),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ── Order label ──────────────────────────────────────────────────────────

  /// Generates an order shipping label (80 mm × 50 mm) for [order].
  Future<Uint8List> generateOrderLabel(OrderModel order) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          50 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) {
          final addr = order.deliveryAddress;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Fufaji\'s Online',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Order #${order.orderNumber}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 2),
              // To address
              pw.Text(
                'TO: ${order.customerName}',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                addr.fullAddress,
                style: const pw.TextStyle(fontSize: 8),
                maxLines: 2,
              ),
              if (addr.landmark.isNotEmpty)
                pw.Text(
                  'Near: ${addr.landmark}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              pw.Text(
                addr.village.isNotEmpty ? addr.village : addr.pincode,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Ph: ${order.customerPhone}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${order.totalItemCount} items | ₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    order.paymentMethod.toString().split('.').last.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: order.id,
                width: 36,
                height: 36,
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  // ── Multi-product price label sheet ──────────────────────────────────────

  /// Generates an A4 sheet of price labels (3 columns × N rows).
  Future<Uint8List> generatePriceLabelPDF(List<ProductModel> products) async {
    final doc = pw.Document();

    const cols = 3;
    const labelW = 60.0 * PdfPageFormat.mm;
    const labelH = 35.0 * PdfPageFormat.mm;

    // Chunk products into A4 pages
    const labelsPerPage = cols * 8; // ~8 rows on A4
    for (int pageStart = 0;
        pageStart < products.length;
        pageStart += labelsPerPage) {
      final pageProducts = products.skip(pageStart).take(labelsPerPage).toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Wrap(
              children: pageProducts.map((p) {
                return pw.Container(
                  width: labelW,
                  height: labelH,
                  padding: const pw.EdgeInsets.all(3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        p.name,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold),
                        maxLines: 2,
                      ),
                      pw.Text(p.unit,
                          style: const pw.TextStyle(fontSize: 7)),
                      pw.Spacer(),
                      pw.Text(
                        '₹${p.price.toStringAsFixed(0)}',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: p.barcode.isNotEmpty ? p.barcode : p.id,
                        height: 14,
                        width: double.infinity,
                        drawText: false,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  // ── Bluetooth thermal printing ────────────────────────────────────────────

  /// Sends [labelData] (raw ESC/POS bytes or PDF bytes) to a paired
  /// bluetooth thermal printer via a platform-channel method.
  /// Returns true on success.
  ///
  /// On platforms where the channel is unavailable or no printer is paired,
  /// returns false gracefully.
  Future<bool> printLabel(Uint8List labelData) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'printBytes',
        {'data': labelData},
      );
      return result ?? false;
    } on MissingPluginException {
      // Thermal printer plugin not installed — silently fail
      return false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
