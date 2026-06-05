import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/scanner_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DispatchScannerScreen
//
// Employee scans a packed order QR (DISPATCH-{orderId}) to:
//   1. Verify the order is in "packed" status
//   2. Assign a rider / mark dispatched
//   3. Record dispatch timestamp + employee
//
// Can be opened with a pre-scanned orderId (from UnifiedScannerHub) or
// started fresh for sequential dispatch of multiple orders.
// ─────────────────────────────────────────────────────────────────────────────

class DispatchScannerScreen extends StatefulWidget {
  final String? orderId;

  const DispatchScannerScreen({super.key, this.orderId});

  @override
  State<DispatchScannerScreen> createState() => _DispatchScannerScreenState();
}

class _DispatchScannerScreenState extends State<DispatchScannerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScannerService _scanner = ScannerService();

  Map<String, dynamic>? _order;
  bool _loading = false;
  bool _dispatched = false;
  String? _errorMsg;
  bool _scanMode = false;
  String _lastCode = '';

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _loadOrder(widget.orderId!);
    } else {
      _scanMode = true;
      _scanner.startScanning();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadOrder(String orderId) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _order = null;
      _dispatched = false;
    });
    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';

      final snap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId)
          .get();

      if (!snap.exists) {
        setState(() {
          _loading = false;
          _errorMsg = 'Order #$orderId not found';
        });
        return;
      }

      final data = snap.data()!;
      setState(() {
        _order = {'id': snap.id, ...data};
        _loading = false;
        _scanMode = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to load order: $e';
      });
    }
  }

  Future<void> _dispatchOrder() async {
    if (_order == null) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';
      final orderId = _order!['id'] as String;

      final batch = _db.batch();

      // Update order status
      final orderRef = _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(orderId);

      batch.update(orderRef, {
        'status': 'dispatched',
        'dispatchedAt': FieldValue.serverTimestamp(),
        'dispatchedBy': auth.currentUser?.uid ?? '',
        'dispatchedByName': auth.currentUser?.name ?? 'Employee',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write dispatch log
      final logRef = _db
          .collection('shops')
          .doc(shopId)
          .collection('dispatch_logs')
          .doc();

      batch.set(logRef, {
        'orderId': orderId,
        'orderNumber': _order!['orderNumber'] ?? orderId,
        'status': 'dispatched',
        'dispatchedBy': auth.currentUser?.uid ?? '',
        'dispatchedByName': auth.currentUser?.name ?? 'Employee',
        'branchId': auth.currentBranch?.id ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': _order!['customerName'] ?? '',
        'totalAmount': _order!['totalAmount'] ?? 0,
      });

      await batch.commit();

      HapticFeedback.heavyImpact();
      setState(() {
        _dispatched = true;
        _loading = false;
        _order!['status'] = 'dispatched';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Dispatch failed: $e';
      });
    }
  }

  // ── Scanner handler ─────────────────────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty || raw == _lastCode) return;

    _lastCode = raw;
    HapticFeedback.mediumImpact();
    await _scanner.stopScanning();

    // Accept ORDER-xxx, DISPATCH-xxx, or bare UUID
    final orderId = raw
        .replaceFirst('ORDER-', '')
        .replaceFirst('DISPATCH-', '')
        .trim();

    setState(() => _scanMode = false);
    await _loadOrder(orderId);
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch Scanner'),
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        actions: [
          if (!_scanMode)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan Another Order',
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _order = null;
                  _dispatched = false;
                  _errorMsg = null;
                  _lastCode = '';
                });
                _scanner.startScanning();
              },
            ),
        ],
      ),
      body: _scanMode ? _buildScanner() : _buildOrderDetails(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner.controller,
          onDetect: _onBarcodeDetected,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFE65100), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Scan DISPATCH-{OrderID} QR',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMsg!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Again'),
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _errorMsg = null;
                  _lastCode = '';
                });
                _scanner.startScanning();
              },
            ),
          ],
        ),
      );
    }

    if (_order == null) return const SizedBox.shrink();

    final status = _order!['status'] as String? ?? '';
    final isPacked =
        status == 'packed' || status == 'ready_to_dispatch';
    final isAlreadyDispatched = status == 'dispatched' || _dispatched;

    final items = (_order!['items'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final total =
        (_order!['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final customerName =
        _order!['customerName'] as String? ?? 'Customer';
    final orderNumber =
        _order!['orderNumber'] as String? ?? _order!['id'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          _StatusBanner(
            status: isAlreadyDispatched ? 'dispatched' : status,
          ),

          const SizedBox(height: 16),

          // Order card
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #$orderNumber',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customerName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Divider(height: 20),
                  // Items
                  ...items.map((item) => _ItemRow(item: item)),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action button
          if (isAlreadyDispatched)
            _SuccessButton(
              label: 'Dispatched ✓',
              onScanNext: () {
                setState(() {
                  _scanMode = true;
                  _order = null;
                  _dispatched = false;
                  _lastCode = '';
                });
                _scanner.startScanning();
              },
            )
          else if (!isPacked)
            _WarningCard(
              message:
                  'This order is not packed yet (status: $status).\nPack it before dispatching.',
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.local_shipping),
              label: const Text(
                'Mark as Dispatched',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _dispatchOrder,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'packed': (Colors.blue, Icons.inventory_outlined, 'Ready to Dispatch'),
      'ready_to_dispatch': (
        Colors.blue,
        Icons.inventory_outlined,
        'Ready to Dispatch'
      ),
      'dispatched': (
        Colors.green,
        Icons.local_shipping,
        'Dispatched Successfully'
      ),
      'pending': (Colors.orange, Icons.pending_outlined, 'Pending'),
    };

    final (color, icon, label) = colors[status] ??
        (Colors.grey, Icons.info_outlined, status.toUpperCase());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${item['name'] ?? 'Item'} × ${item['quantity'] ?? 1}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '₹${((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SuccessButton extends StatelessWidget {
  final String label;
  final VoidCallback onScanNext;
  const _SuccessButton({required this.label, required this.onScanNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan Next Order'),
          onPressed: onScanNext,
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String message;
  const _WarningCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
