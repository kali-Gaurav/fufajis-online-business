import '../../services/logging_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import 'order_packing_screen.dart';
import 'inventory_receiving_screen.dart';
import 'inventory_audit_screen.dart';
import 'shelf_refill_screen.dart';
import 'attendance_screen.dart';
import 'dispatch_scanner_screen.dart';
import 'delivery_pod_scanner_screen.dart';
import 'customer_membership_scanner_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UnifiedScannerHub
//
// One screen for all 9 scan modes. Employee picks mode → camera opens →
// result auto-routes to the correct workflow screen.
// Mode can also be forced by the caller (e.g. from dispatch workflow).
// ─────────────────────────────────────────────────────────────────────────────

class UnifiedScannerHub extends StatefulWidget {
  /// If supplied, scanner opens directly in this mode (skips mode picker).
  final String? initialMode;

  const UnifiedScannerHub({super.key, this.initialMode});

  @override
  State<UnifiedScannerHub> createState() => _UnifiedScannerHubState();
}

class _UnifiedScannerHubState extends State<UnifiedScannerHub> with SingleTickerProviderStateMixin {
  final ScannerService _scanner = ScannerService();

  String? _activeMode; // null = mode-picker visible
  String _lastCode = '';
  bool _processing = false;
  bool _flashOn = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (widget.initialMode != null) {
      _activeMode = widget.initialMode;
      _scanner.startScanning();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Mode selection ──────────────────────────────────────────────────────────

  void _selectMode(String modeId) {
    setState(() => _activeMode = modeId);
    _scanner.startScanning();
  }

  void _backToModes() {
    _scanner.stopScanning();
    setState(() {
      _activeMode = null;
      _lastCode = '';
      _processing = false;
    });
  }

  // ── Barcode detection ───────────────────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null || raw == _lastCode) return;

    _lastCode = raw;
    setState(() => _processing = true);
    HapticFeedback.mediumImpact();

    _scanner.processBarcode(barcode);

    // Write audit log
    final auth = context.read<AuthProvider>();
    await _scanner.writeScanLog(
      shopId: auth.currentShop?.id ?? 'shop_001',
      branchId: auth.currentBranch?.id ?? '',
      employeeId: auth.currentUser?.uid ?? '',
      employeeName: auth.currentUser?.name ?? 'Employee',
      employeeRole: auth.currentUser?.role.name ?? 'employee',
      action: _activeMode != null ? _scanner.parseScanAction(raw) : ScanAction.productScan(raw),
    );

    await _scanner.stopScanning();

    if (!mounted) return;

    // If mode is locked, route directly. Otherwise auto-detect.
    final action = _activeMode != null
        ? _buildForcedAction(_activeMode!, raw)
        : _scanner.parseScanAction(raw);

    await _routeAction(action);

    if (mounted) {
      setState(() {
        _processing = false;
        _lastCode = '';
      });
      await _scanner.startScanning();
    }
  }

  ScanAction _buildForcedAction(String mode, String code) {
    switch (mode) {
      case ScanMode.productSearch:
        return ScanAction.productScan(code);
      case ScanMode.orderPacking:
        return code.startsWith('ORDER-')
            ? ScanAction.orderPacking(code)
            : ScanAction.orderPacking('ORDER-$code');
      case ScanMode.dispatch:
        return code.startsWith('DISPATCH-')
            ? ScanAction.dispatchVerification(code)
            : ScanAction.dispatchVerification('DISPATCH-$code');
      case ScanMode.deliveryPOD:
        return code.startsWith('PARCEL-')
            ? ScanAction.proofOfDelivery(code)
            : ScanAction.proofOfDelivery('PARCEL-$code');
      case ScanMode.inventoryReceiving:
        return ScanAction.productScan(code); // barcode of product being received
      case ScanMode.inventoryAudit:
        return ScanAction.productScan(code);
      case ScanMode.shelfAudit:
        return code.startsWith('SHELF-')
            ? ScanAction.shelfCheck(code)
            : ScanAction.productScan(code);
      case ScanMode.customerMembership:
        return code.startsWith('MEMBER-')
            ? ScanAction.membershipLookup(code)
            : ScanAction.membershipLookup('MEMBER-$code');
      case ScanMode.paymentQr:
        return ScanAction.paymentQr(code);
      case ScanMode.attendance:
        return code.startsWith('ATTENDANCE-')
            ? ScanAction.attendance(code)
            : ScanAction.attendance('ATTENDANCE-$code');
      default:
        return _scanner.parseScanAction(code);
    }
  }

  Future<void> _routeAction(ScanAction action) async {
    if (!mounted) return;

    switch (action.actionType) {
      case ScanMode.productSearch:
        await _showProductSheet(action.metadata['barcode'] as String? ?? action.code);
        break;

      case ScanMode.orderPacking:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderPackingScreen(orderId: action.metadata['orderId'] as String?),
          ),
        );
        break;

      case ScanMode.dispatch:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DispatchScannerScreen(orderId: action.metadata['orderId'] as String?),
          ),
        );
        break;

      case ScanMode.deliveryPOD:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DeliveryPodScannerScreen(parcelId: action.metadata['parcelId'] as String?),
          ),
        );
        break;

      case ScanMode.inventoryReceiving:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                InventoryReceivingScreen(barcode: action.metadata['barcode'] as String?),
          ),
        );
        break;

      case ScanMode.inventoryAudit:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InventoryAuditScreen()),
        );
        break;

      case ScanMode.shelfAudit:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShelfRefillScreen()));
        break;

      case ScanMode.customerMembership:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerMembershipScannerScreen(
              customerId: action.metadata['customerId'] as String?,
            ),
          ),
        );
        break;

      case ScanMode.paymentQr:
        _showPaymentSheet(action.metadata['upiUrl'] as String? ?? action.code);
        break;

      case ScanMode.attendance:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(qrCodeId: action.metadata['attendanceId'] as String?),
          ),
        );
        break;

      case ScanMode.returnItem:
        // FIX 4: Route return items to Return/Damage Hub (now fixed)
        context.go('/employee/return-hub');
        break;

      case ScanMode.damageItem:
        // FIX 4: Route damage items to Return/Damage Hub (now fixed)
        context.go('/employee/return-hub');
        break;

      case ScanMode.riderScan:
        // Route rider scans (if implemented)
        _showUnknownCodeSheet(action.code);
        break;

      default:
        _showUnknownCodeSheet(action.code);
    }
  }

  // ── Product lookup sheet ────────────────────────────────────────────────────

  Future<void> _showProductSheet(String barcode) async {
    final productProvider = context.read<ProductProvider>();
    final product = productProvider.getProductByBarcode(barcode);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductResultSheet(
        barcode: barcode,
        product: product,
        onReceive: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InventoryReceivingScreen(barcode: barcode)),
          );
        },
        onAudit: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InventoryAuditScreen(barcode: barcode)),
          );
        },
      ),
    );
  }

  void _showPaymentSheet(String upiUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PaymentQrSheet(upiUrl: upiUrl),
    );
  }

  void _showUnknownCodeSheet(String code) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, size: 48, color: AppTheme.warning),
            const SizedBox(height: 12),
            const Text('Unknown Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(code, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role.name ?? 'employee';

    return Scaffold(
      backgroundColor: Colors.black,
      body: _activeMode == null ? _buildModePicker(role) : _buildScannerView(),
    );
  }

  // ── Mode picker ─────────────────────────────────────────────────────────────

  Widget _buildModePicker(String role) {
    final modes = ScanMode.forRole(role);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scanner Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Select scan mode', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemCount: modes.length,
              itemBuilder: (_, i) =>
                  _ModeTile(config: modes[i], onTap: () => _selectMode(modes[i].id)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live camera scanner ─────────────────────────────────────────────────────

  Widget _buildScannerView() {
    final modeConfig = ScanMode.find(_activeMode!);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera
        MobileScanner(controller: _scanner.controller, onDetect: _onBarcodeDetected),

        // Dark vignette
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.85,
              colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
            ),
          ),
        ),

        // Scan frame
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Transform.scale(scale: _processing ? 1.08 : _pulseAnim.value, child: child),
            child: _ScanFrame(color: modeConfig?.color ?? AppTheme.warning, size: 240),
          ),
        ),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back to modes
                GestureDetector(
                  onTap: _backToModes,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),

                const SizedBox(width: 12),

                // Mode label
                if (modeConfig != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: modeConfig.color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(modeConfig.icon, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          modeConfig.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Flash toggle
                GestureDetector(
                  onTap: () async {
                    await _scanner.toggleFlashlight();
                    setState(() => _flashOn = !_flashOn);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _flashOn ? AppTheme.warning.withOpacity(0.85) : Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom hint
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_processing)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  else
                    Text(
                      modeConfig?.description ?? 'Point camera at code',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode tile widget
// ─────────────────────────────────────────────────────────────────────────────

class _ModeTile extends StatelessWidget {
  final ScanModeConfig config;
  final VoidCallback onTap;

  const _ModeTile({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: config.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: config.color.withOpacity(0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icon, color: config.color, size: 22),
            ),
            const Spacer(),
            Text(
              config.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              config.labelHi,
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated scan-frame corners
// ─────────────────────────────────────────────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  final Color color;
  final double size;

  const _ScanFrame({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CornerPainter(color: color)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 10.0;

    void corner(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x + dx * len, y)
        ..lineTo(x + dx * r, y)
        ..arcToPoint(
          Offset(x, y + dy * r),
          radius: const Radius.circular(r),
          clockwise: dx * dy < 0,
        )
        ..lineTo(x, y + dy * len);
      canvas.drawPath(path, paint);
    }

    corner(0, 0, 1, 1);
    corner(size.width, 0, -1, 1);
    corner(0, size.height, 1, -1);
    corner(size.width, size.height, -1, -1);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Product result bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ProductResultSheet extends StatelessWidget {
  final String barcode;
  final ProductModel? product;
  final VoidCallback onReceive;
  final VoidCallback onAudit;

  const _ProductResultSheet({
    required this.barcode,
    required this.product,
    required this.onReceive,
    required this.onAudit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (product == null) ...[
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
                SizedBox(width: 10),
                Text(
                  'Product Not Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Barcode: $barcode',
              style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add as New Product'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2, color: AppTheme.info, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product!.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(product!.name, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _Stat(
                  label: 'Price',
                  value: '₹${product!.price.toDouble().toStringAsFixed(0)}',
                  color: AppTheme.success,
                ),
                const SizedBox(width: 12),
                _Stat(
                  label: 'Stock',
                  value: '${product!.stockQuantity}',
                  color: product!.stockQuantity < 10 ? AppTheme.error : AppTheme.info,
                ),
                const SizedBox(width: 12),
                _Stat(label: 'Category', value: product!.category, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.move_to_inbox),
                    label: const Text('Receive'),
                    onPressed: onReceive,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.assignment),
                    label: const Text('Audit'),
                    onPressed: onAudit,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment QR sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentQrSheet extends StatelessWidget {
  final String upiUrl;
  const _PaymentQrSheet({required this.upiUrl});

  @override
  Widget build(BuildContext context) {
    // Parse UPI URL: upi://pay?pa=...&pn=...&am=...
    Uri? uri;
    try {
      uri = Uri.parse(upiUrl.replaceFirst('upi:', 'https:'));
    } catch (e, stack) {
      LoggingService().error('Silent error caught', e, stack);
    }

    final pa = uri?.queryParameters['pa'] ?? '—';
    final pn = uri?.queryParameters['pn'] ?? '—';
    final am = uri?.queryParameters['am'] ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.qr_code_scanner, size: 48, color: Colors.deepPurple),
          const SizedBox(height: 12),
          const Text('UPI Payment QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _Row(label: 'UPI ID', value: pa),
          _Row(label: 'Name', value: pn),
          if (am.isNotEmpty) _Row(label: 'Amount', value: '₹$am'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Payment Verified'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
