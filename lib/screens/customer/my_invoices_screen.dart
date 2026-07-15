import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/empty_state.dart' show FjEmptyState;

/// Customer-facing GST tax invoice list (Task #54).
///
/// Shows every persisted, immutable GST invoice generated for the signed-in
/// customer's orders (created automatically once an order is marked
/// `delivered` — see OrderWorkflowEngine._generateInvoiceForDeliveredOrder).
/// Customers can view a quick summary and download/share the invoice PDF.
class MyInvoicesScreen extends StatefulWidget {
  const MyInvoicesScreen({super.key});

  @override
  State<MyInvoicesScreen> createState() => _MyInvoicesScreenState();
}

class _MyInvoicesScreenState extends State<MyInvoicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        Provider.of<InvoiceProvider>(context, listen: false).loadCustomerInvoices(uid);
      }
    });
  }

  Future<void> _downloadInvoice(InvoiceModel invoice) async {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    try {
      final bytes = await provider.downloadInvoicePDF(invoice.invoiceId);
      await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open invoice: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Invoices')),
      body: Consumer<InvoiceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (provider.invoices.isEmpty) {
            return const FjEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No invoices yet',
              subtitle: 'GST tax invoices appear here once your orders are delivered.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) await provider.loadCustomerInvoices(uid);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invoice = provider.invoices[index];
                return _InvoiceCard(invoice: invoice, onDownload: () => _downloadInvoice(invoice));
              },
            ),
          );
        },
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onDownload;

  const _InvoiceCard({required this.invoice, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(invoice.issueDate);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download / Share invoice',
                  onPressed: onDownload,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(invoice.shopName, style: const TextStyle(fontWeight: FontWeight.w500)),
                _StatusChip(status: invoice.paymentStatus),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal: ${GstFormat.currency(invoice.subtotal.toDouble())}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                Text(
                  'GST: ${GstFormat.currency(invoice.totalTax.toDouble())}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${GstFormat.currency(invoice.grandTotal.toDouble())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (invoice.gstNumber != null && invoice.gstNumber!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'GSTIN: ${invoice.gstNumber}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PaymentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case PaymentStatus.paid:
        color = AppTheme.success;
        break;
      case PaymentStatus.unpaid:
        color = AppTheme.warning;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Small currency formatting helper local to this screen to avoid pulling in
/// the full GSTService just for display formatting.
class GstFormat {
  static String currency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(amount);
  }
}
