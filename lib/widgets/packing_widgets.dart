import 'package:flutter/material.dart';
import '../models/fulfillment_model.dart';
import '../utils/app_theme.dart';

/// Widget to display an order item during packing
class OrderItemCard extends StatelessWidget {
  final FulfillmentItem item;
  final VoidCallback onTap;
  final VoidCallback? onVerify;
  final bool isSelected;

  const OrderItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onVerify,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isComplete = item.isPacked;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isSelected
            ? AppTheme.info.withValues(alpha: 0.1)
            : isDark
                ? Colors.grey[800]
                : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Product image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? Colors.grey[700] : Colors.grey[200],
                    ),
                    child: item.productImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.productImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.image_not_supported,
                                      color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.inventory_2,
                            color: Colors.grey[400], size: 40),
                  ),
                  const SizedBox(width: 16),
                  // Product details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.requiredQuantity.toStringAsFixed(2)} ${item.unit} required',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        // Progress indicator
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: item.progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isComplete ? AppTheme.success : AppTheme.info,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.packedQuantity.toStringAsFixed(2),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status icons
                  Column(
                    children: [
                      if (isComplete)
                        Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        )
                      else
                        Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.warning,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child:
                              const Icon(Icons.schedule, color: Colors.white, size: 16),
                        ),
                      const SizedBox(height: 8),
                      if (item.verified)
                        const Icon(Icons.verified, color: AppTheme.success, size: 20)
                      else if (isComplete)
                        const Icon(Icons.pending_actions, color: AppTheme.warning, size: 20),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress indicator showing x of y items packed
class PackingProgressIndicator extends StatelessWidget {
  final int packedCount;
  final int totalCount;
  final double itemsPacked;
  final double efficiency;

  const PackingProgressIndicator({
    super.key,
    required this.packedCount,
    required this.totalCount,
    this.itemsPacked = 0,
    this.efficiency = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = totalCount > 0 ? packedCount / totalCount : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      color: isDark ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main progress bar
            Row(
              children: [
                Text(
                  '$packedCount / $totalCount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress < 0.5
                      ? AppTheme.warning
                      : progress < 0.9
                          ? AppTheme.info
                          : AppTheme.success,
                ),
              ),
            ),
            if (efficiency > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items/min: ${efficiency.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Display special instructions/notes for an order
class SpecialNotesAlert extends StatelessWidget {
  final String notes;
  final Color? backgroundColor;

  const SpecialNotesAlert({
    super.key,
    required this.notes,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.warning,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: AppTheme.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.warning,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to print shipping label
class LabelPrinter extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String address;
  final VoidCallback? onPrintSuccess;
  final VoidCallback? onPrintError;

  const LabelPrinter({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    this.onPrintSuccess,
    this.onPrintError,
  });

  @override
  State<LabelPrinter> createState() => _LabelPrinterState();
}

class _LabelPrinterState extends State<LabelPrinter> {
  bool _isPrinting = false;

  Future<void> _printLabel() async {
    setState(() => _isPrinting = true);

    try {
      // Integration with printer service would go here
      // await PrinterService().printShippingLabel(
      //   orderId: widget.orderId,
      //   customerName: widget.customerName,
      //   address: widget.address,
      // );

      widget.onPrintSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label printed successfully')),
      );
    } catch (e) {
      widget.onPrintError?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isPrinting ? null : _printLabel,
      icon: _isPrinting
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            )
          : const Icon(Icons.print),
      label: Text(_isPrinting ? 'Printing...' : 'Print Label'),
    );
  }
}

/// Barcode scanner widget
class BarcodeScanner extends StatefulWidget {
  final Function(String) onScan;
  final String? hintText;
  final bool showCameraButton;

  const BarcodeScanner({
    super.key,
    required this.onScan,
    this.hintText,
    this.showCameraButton = true,
  });

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScan() {
    final barcode = _controller.text.trim();
    if (barcode.isNotEmpty) {
      widget.onScan(barcode);
      _controller.clear();
      FocusScope.of(context).requestFocus();
    }
  }

  Future<void> _openCameraScanner() async {
    // Integration with camera barcode scanner would go here
    // final result = await BarcodeScanner.scan();
    // if (result.isValid) {
    //   _controller.text = result.rawContent;
    //   _handleScan();
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _handleScan(),
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Scan barcode',
            prefixIcon: const Icon(Icons.barcode_reader),
            suffixIcon: widget.showCameraButton
                ? IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _openCameraScanner,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _handleScan,
          icon: const Icon(Icons.check),
          label: const Text('Verify'),
        ),
      ],
    );
  }
}

/// Order header card showing basic order info
class OrderHeaderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String? customerPhone;
  final String? address;
  final DateTime? createdAt;
  final Color? backgroundColor;

  const OrderHeaderCard({
    super.key,
    required this.orderId,
    required this.customerName,
    this.customerPhone,
    this.address,
    this.createdAt,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.all(16),
      color: backgroundColor ?? (isDark ? Colors.grey[800] : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #$orderId',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Customer',
              value: customerName,
              icon: Icons.person,
            ),
            if (customerPhone != null)
              _InfoRow(
                label: 'Phone',
                value: customerPhone!,
                icon: Icons.phone,
              ),
            if (address != null)
              _InfoRow(
                label: 'Address',
                value: address!,
                icon: Icons.location_on,
              ),
            if (createdAt != null)
              _InfoRow(
                label: 'Created',
                value: _formatDate(createdAt!),
                icon: Icons.schedule,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats card for employee dashboard
class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? backgroundColor;
  final IconData? icon;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: backgroundColor ?? (isDark ? Colors.grey[800] : AppTheme.info),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (icon != null)
              Icon(icon, size: 32, color: AppTheme.info)
            else
              const SizedBox(height: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (unit != null) ...[
              const SizedBox(height: 4),
              Text(
                unit!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quality check item card
class QualityCheckItemCard extends StatefulWidget {
  final FulfillmentItem item;
  final VoidCallback onVerify;
  final bool isChecked;

  const QualityCheckItemCard({
    super.key,
    required this.item,
    required this.onVerify,
    this.isChecked = false,
  });

  @override
  State<QualityCheckItemCard> createState() => _QualityCheckItemCardState();
}

class _QualityCheckItemCardState extends State<QualityCheckItemCard> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.isChecked;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _checked
          ? AppTheme.success.withValues(alpha: 0.1)
          : isDark
              ? Colors.grey[800]
              : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: _checked,
              onChanged: (value) {
                setState(() => _checked = value ?? false);
                if (_checked) widget.onVerify();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.productName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.item.packedQuantity.toStringAsFixed(2)} / ${widget.item.requiredQuantity.toStringAsFixed(2)} ${widget.item.unit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (_checked)
              const Icon(Icons.verified, color: AppTheme.success, size: 24)
            else
              Icon(Icons.circle_outlined, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }
}
