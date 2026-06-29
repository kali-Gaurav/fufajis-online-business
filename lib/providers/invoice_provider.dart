import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../services/invoice_service.dart';
import '../services/gst_service.dart';
import 'dart:typed_data';

/// Provider for managing invoices and GST reports
class InvoiceProvider extends ChangeNotifier {
  // State
  List<InvoiceModel> _invoices = [];
  List<InvoiceModel> _filteredInvoices = [];
  InvoiceModel? _currentInvoice;
  bool _isLoading = false;
  String? _error;
  GSTReport? _currentGSTReport;

  // Getters
  List<InvoiceModel> get invoices => _invoices;
  List<InvoiceModel> get filteredInvoices => _filteredInvoices;
  InvoiceModel? get currentInvoice => _currentInvoice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  GSTReport? get currentGSTReport => _currentGSTReport;

  // Statistics
  int get invoiceCount => _invoices.length;
  double get totalTaxCollected =>
      _invoices.fold(0.0, (sum, inv) => sum + inv.totalTax.toDouble());
  double get totalRevenue => _invoices.fold(0.0, (sum, inv) => sum + inv.grandTotal.toDouble());
  int get paidInvoices =>
      _invoices.where((inv) => inv.paymentStatus == PaymentStatus.paid).length;
  int get unpaidInvoices =>
      _invoices.where((inv) => inv.paymentStatus == PaymentStatus.unpaid).length;

  // Load all invoices for a customer
  Future<void> loadCustomerInvoices(String customerId) async {
    _setLoading(true);
    _clearError();

    try {
      _invoices = await InvoiceService().getCustomerInvoices(customerId);
      _filteredInvoices = List.from(_invoices);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load invoices: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load all invoices for a shop with filters
  Future<void> loadShopInvoices(
    String shopId, {
    DateTime? startDate,
    DateTime? endDate,
    PaymentStatus? paymentStatus,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _invoices = await InvoiceService().getShopInvoices(
        shopId,
        startDate: startDate,
        endDate: endDate,
        paymentStatus: paymentStatus,
      );
      _filteredInvoices = List.from(_invoices);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load shop invoices: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load a single invoice by ID
  Future<void> loadInvoice(String invoiceId) async {
    _setLoading(true);
    _clearError();

    try {
      _currentInvoice = await InvoiceService().getInvoice(invoiceId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load invoice: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Filter invoices by date range
  void filterByDateRange(DateTime startDate, DateTime endDate) {
    _filteredInvoices = _invoices
        .where((inv) =>
            inv.issueDate.isAfter(startDate) && inv.issueDate.isBefore(endDate))
        .toList();
    notifyListeners();
  }

  // Filter invoices by payment status
  void filterByPaymentStatus(PaymentStatus status) {
    _filteredInvoices =
        _invoices.where((inv) => inv.paymentStatus == status).toList();
    notifyListeners();
  }

  // Filter invoices by customer
  void filterByCustomer(String customerName) {
    _filteredInvoices = _invoices
        .where((inv) =>
            inv.customerName.toLowerCase().contains(customerName.toLowerCase()))
        .toList();
    notifyListeners();
  }

  // Search invoices
  void searchInvoices(String query) {
    if (query.isEmpty) {
      _filteredInvoices = List.from(_invoices);
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredInvoices = _invoices
          .where((inv) =>
              inv.invoiceNumber.toLowerCase().contains(lowerQuery) ||
              inv.customerName.toLowerCase().contains(lowerQuery) ||
              inv.orderId.toLowerCase().contains(lowerQuery))
          .toList();
    }
    notifyListeners();
  }

  // Reset filters
  void resetFilters() {
    _filteredInvoices = List.from(_invoices);
    notifyListeners();
  }

  // Download invoice PDF
  Future<Uint8List> downloadInvoicePDF(String invoiceId) async {
    _setLoading(true);
    _clearError();

    try {
      final invoice = await InvoiceService().getInvoice(invoiceId);
      if (invoice == null) throw Exception('Invoice not found');

      final pdfBytes = await InvoiceService().generateInvoicePDF(invoice);
      return pdfBytes;
    } catch (e) {
      _setError('Failed to generate PDF: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Email invoice
  Future<void> emailInvoice(
    String invoiceId,
    String email,
    Uint8List pdfBytes,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      await InvoiceService().sendInvoiceEmail(invoiceId, email, pdfBytes);
    } catch (e) {
      _setError('Failed to send email: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update payment status
  Future<void> updatePaymentStatus(
    String invoiceId,
    PaymentStatus status,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      await InvoiceService().updatePaymentStatus(invoiceId, status);

      // Update local cache
      final index = _invoices.indexWhere((inv) => inv.invoiceId == invoiceId);
      if (index != -1) {
        final updatedInvoice = _invoices[index];
        _invoices[index] = InvoiceModel(
          invoiceId: updatedInvoice.invoiceId,
          invoiceNumber: updatedInvoice.invoiceNumber,
          orderId: updatedInvoice.orderId,
          customerId: updatedInvoice.customerId,
          customerName: updatedInvoice.customerName,
          shopId: updatedInvoice.shopId,
          shopName: updatedInvoice.shopName,
          items: updatedInvoice.items,
          subtotal: updatedInvoice.subtotal,
          totalTax: updatedInvoice.totalTax,
          discount: updatedInvoice.discount,
          grandTotal: updatedInvoice.grandTotal,
          billingAddress: updatedInvoice.billingAddress,
          shippingAddress: updatedInvoice.shippingAddress,
          customerEmail: updatedInvoice.customerEmail,
          customerPhone: updatedInvoice.customerPhone,
          issueDate: updatedInvoice.issueDate,
          dueDate: updatedInvoice.dueDate,
          paymentMethod: updatedInvoice.paymentMethod,
          paymentStatus: status,
          notes: updatedInvoice.notes,
          pdfUrl: updatedInvoice.pdfUrl,
          createdAt: updatedInvoice.createdAt,
          updatedAt: DateTime.now(),
          isImmutable: updatedInvoice.isImmutable,
          gstNumber: updatedInvoice.gstNumber,
        );
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to update payment status: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Generate GST report for a date range
  Future<void> generateGSTReport(
    String shopId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentGSTReport = await InvoiceService().generateGSTReport(
        shopId: shopId,
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to generate GST report: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Save GST report to Firestore
  Future<void> saveGSTReport(String shopId) async {
    if (_currentGSTReport == null) {
      _setError('No GST report generated');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      await InvoiceService().saveGSTReport(shopId, _currentGSTReport!);
    } catch (e) {
      _setError('Failed to save GST report: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get summary statistics for dashboard
  Map<String, dynamic> getSummaryStats() {
    return {
      'totalInvoices': invoiceCount,
      'totalRevenue': totalRevenue,
      'totalTax': totalTaxCollected,
      'paidInvoices': paidInvoices,
      'unpaidInvoices': unpaidInvoices,
      'partialInvoices': invoiceCount - paidInvoices - unpaidInvoices,
      'averageInvoiceValue':
          invoiceCount > 0 ? totalRevenue / invoiceCount : 0,
    };
  }

  // Get tax breakdown summary
  Map<double, double> getTaxBreakdownSummary() {
    final breakdown = <double, double>{};
    for (var invoice in _invoices) {
      final invoiceBreakdown = invoice.getTaxBreakdown();
      for (final entry in invoiceBreakdown.entries) {
        breakdown[entry.key] = (breakdown[entry.key] ?? 0) + entry.value;
      }
    }
    return breakdown;
  }

  // Export invoices as CSV (basic implementation)
  String exportAsCSV() {
    final buffer = StringBuffer();
    buffer.writeln(
        'Invoice #,Date,Customer,Email,Amount,Tax,Discount,Total,Payment Status');

    for (var invoice in _filteredInvoices) {
      buffer.writeln(
        '${invoice.invoiceNumber},'
        '${DateFormat('yyyy-MM-dd').format(invoice.issueDate)},'
        '${invoice.customerName},'
        '${invoice.customerEmail},'
        '${invoice.subtotal},'
        '${invoice.totalTax},'
        '${invoice.discount},'
        '${invoice.grandTotal},'
        '${invoice.paymentStatus.displayName}',
      );
    }

    return buffer.toString();
  }

  // Private helper methods
  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _setError(String message) {
    _error = message;
  }

  void _clearError() {
    _error = null;
  }

  void clearCurrentInvoice() {
    _currentInvoice = null;
    notifyListeners();
  }

  void clearCurrentGSTReport() {
    _currentGSTReport = null;
    notifyListeners();
  }
}
