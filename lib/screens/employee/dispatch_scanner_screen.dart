import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/scanner_service.dart';
import '../../services/fleet_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';

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
  final FleetService _fleetService = FleetService();
  final UserService _userService = UserService();

  Map<String, dynamic>? _order;
  bool _loading = false;
  bool _dispatched = false;
  String? _errorMsg;
  bool _scanMode = false;
  bool _scanRiderMode = false;
  String _lastCode = '';
  
  String? _selectedRiderId;
  String? _selectedRiderName;
  double _selectedRiderCash = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      _loadOrder(widget.orderId!);
    } else {
      _scanMode = true;
      _scanRiderMode = false;
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
      final snap = await _db.collection('orders').doc(orderId).get();

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
    if (_order == null || _selectedRiderId == null) return;
    setState(() => _loading = true);

    try {
      await _fleetService.assignOrderToRider(_order!['id'] as String, _selectedRiderId!);

      HapticFeedback.heavyImpact();
      setState(() {
        _dispatched = true;
        _loading = false;
        _order!['status'] = 'dispatched';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = e.toString();
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

    if (_scanRiderMode) {
      if (raw.startsWith('RIDER-')) {
        final riderPhone = raw.replaceFirst('RIDER-', '').trim();
        setState(() {
          _selectedRiderId = riderPhone;
          _selectedRiderName = 'Scanned Rider ($riderPhone)';
          _scanMode = false;
          _scanRiderMode = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Invalid Rider QR. Must start with RIDER-';
          _scanMode = false;
          _scanRiderMode = false;
        });
      }
      return;
    }

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
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Dispatch Scanner', style: TextStyle(fontWeight: FontWeight.w700)),
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
                  _scanRiderMode = false;
                  _order = null;
                  _dispatched = false;
                  _errorMsg = null;
                  _lastCode = '';
                  _selectedRiderId = null;
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
                child: Text(
                  _scanRiderMode ? 'Scan RIDER-{Phone} QR' : 'Scan DISPATCH-{OrderID} QR',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_errorMsg!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 32),
              FjButton(
                label: 'Scan Again',
                onPressed: () {
                  setState(() {
                    _scanMode = true;
                    _scanRiderMode = false;
                    _errorMsg = null;
                    _lastCode = '';
                  });
                  _scanner.startScanning();
                },
                icon: Icons.qr_code_scanner,
              ),
          ],
        ),
      );
    }

    if (_order == null) return const SizedBox.shrink();

    final status = _order!['status'] as String? ?? '';
    final isPacked = status.contains('packed');
    final isAlreadyDispatched = status.contains('dispatched') || status.contains('outForDelivery') || _dispatched;

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
      padding: AppTheme.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          _StatusBanner(
            status: isAlreadyDispatched ? 'dispatched' : (isPacked ? 'packed' : 'pending'),
          ),

          const SizedBox(height: 24),

          // Order card
          FjCard(
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
                          color: AppTheme.success),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  customerName,
                  style: const TextStyle(color: AppTheme.grey600),
                ),
                const Divider(height: 32),
                // Items
                ...items.map((item) => _ItemRow(item: item)),
                const Divider(height: 32),
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

          const SizedBox(height: 24),

          // Rider Selection
          if (!isAlreadyDispatched && isPacked) ...[
            const Text('Assign Delivery Rider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            FjCard(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _userService.getAuthorizedRidersStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                  final riders = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Available Rider', border: OutlineInputBorder()),
                    initialValue: riders.any((r) => r['phoneNumber'] == _selectedRiderId) ? _selectedRiderId : null,
                    items: riders.map((r) => DropdownMenuItem(
                      value: r['phoneNumber'] as String,
                      child: Text('${r['name']} (Cash: ₹${(r['currentCashBalance'] ?? 0).round()})'),
                    )).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        final rider = riders.firstWhere((r) => r['phoneNumber'] == val);
                        setState(() {
                          _selectedRiderId = val;
                          _selectedRiderName = rider['name'] as String?;
                          _selectedRiderCash = (rider['currentCashBalance'] as num? ?? 0.0).toDouble();
                        });
                      }
                    },
                  );
                }
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Rider QR'),
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _scanRiderMode = true;
                  _lastCode = '';
                });
                _scanner.startScanning();
              },
            ),
            if (_selectedRiderId != null && _selectedRiderName != null && !_selectedRiderName!.contains('('))
               Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Selected Rider: $_selectedRiderName', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
               ),
            if (_selectedRiderCash > 5000)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                    SizedBox(width: 4),
                    Expanded(child: Text('Rider has exceeded ₹5,000 cash limit. Settle cash first.', style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],

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
                  _selectedRiderId = null;
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
            FjButton(
              label: 'Mark as Dispatched',
              onPressed: (_loading || _selectedRiderId == null || _selectedRiderCash > 5000) ? null : _dispatchOrder,
              icon: Icons.local_shipping,
              isLoading: _loading,
              width: double.infinity,
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
      'packed': (AppTheme.info, Icons.inventory_outlined, 'Ready to Dispatch'),
      'dispatched': (
        AppTheme.success,
        Icons.local_shipping,
        'Dispatched Successfully'
      ),
      'pending': (AppTheme.warning, Icons.pending_outlined, 'Awaiting Packing'),
    };

    final (color, icon, label) = colors[status] ??
        (AppTheme.grey500, Icons.info_outlined, status.toUpperCase());

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
              '${item['productName'] ?? item['name'] ?? 'Item'} × ${item['quantity'] ?? 1}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '₹${((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.grey500),
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
        FjCard(
          color: AppTheme.success.withValues(alpha: 0.1),
          border: Border.all(color: AppTheme.success),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FjButton(
          label: 'Scan Next Order',
          onPressed: onScanNext,
          icon: Icons.qr_code_scanner,
          type: FjButtonType.outline,
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
    return FjCard(
      color: AppTheme.primaryLight,
      border: Border.all(color: AppTheme.warning),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.warning, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }
}
