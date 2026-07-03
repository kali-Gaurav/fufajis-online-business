import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../models/invoice_model.dart';
import '../../services/gst_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/fj_card.dart';
import '../../widgets/common/fj_button.dart';
import '../../widgets/common/empty_state.dart';

/// Owner-facing GST compliance screen (Task #54).
///
/// Lets the owner generate a GST report (tax collected, broken down by
/// rate) for a chosen date range from the shop's persisted GST invoices,
/// save it for filing records, and browse the underlying invoice list.
class GSTReportScreen extends StatefulWidget {
  const GSTReportScreen({super.key});

  @override
  State<GSTReportScreen> createState() => _GSTReportScreenState();
}

class _GSTReportScreenState extends State<GSTReportScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  bool _isSaving = false;

  String get _shopId =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? 'shop_001';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    await provider.loadShopInvoices(_shopId, startDate: _startDate, endDate: _endDate);
    await provider.generateGSTReport(_shopId, startDate: _startDate, endDate: _endDate);
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      await _load();
    }
  }

  Future<void> _saveReport() async {
    setState(() => _isSaving = true);
    try {
      await Provider.of<InvoiceProvider>(context, listen: false).saveGSTReport(_shopId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('GST report saved for filing records')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save report: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('GST Tax Report', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Choose date range',
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Consumer<InvoiceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent));
          }
          final report = provider.currentGSTReport;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${dateFmt.format(_startDate)} – ${dateFmt.format(_endDate)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (report == null)
                  const FjEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No GST data',
                    subtitle: 'No invoices were generated in this date range yet.',
                  )
                else ...[
                  FjCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          label: 'Total Sales',
                          value: GSTService.formatCurrency(report.totalSales),
                        ),
                        const Divider(),
                        _SummaryRow(
                          label: 'Total GST Liability',
                          value: GSTService.formatCurrency(report.totalTaxLiability),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tax Breakdown by Rate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...GSTService.getUniqueGSTRates(report.taxByRate.keys.toList()).map((rate) {
                    final tax = report.taxByRate[rate] ?? 0;
                    return FjCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(GSTService.getGSTRateCategory(rate)),
                        subtitle: Text('${rate.toStringAsFixed(0)}% GST'),
                        trailing: Text(
                          GSTService.formatCurrency(tax),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  FjButton(
                    label: _isSaving ? 'Saving...' : 'Save Report for Filing',
                    onPressed: _isSaving ? null : _saveReport,
                    icon: Icons.save_outlined,
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Invoices in Range',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (provider.invoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No invoices found', style: TextStyle(color: Colors.grey[600])),
                    ),
                  )
                else
                  ...provider.invoices.map((inv) => _InvoiceRow(invoice: inv)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _SummaryRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return FjCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(invoice.invoiceNumber),
        subtitle: Text('${dateFmt.format(invoice.issueDate)} • ${invoice.customerName}'),
        trailing: Text(
          GSTService.formatCurrency(invoice.grandTotal.toDouble()),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
