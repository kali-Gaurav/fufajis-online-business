import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../services/scanner_service.dart';
import '../../services/smart_scan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeliveryPodScannerScreen — Proof of Delivery
//
// Delivery agent scans PARCEL-{orderId} at customer's door.
// Captures: GPS coordinates, photo proof (optional), timestamp, signature note.
// Updates order status → "delivered".
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryPodScannerScreen extends StatefulWidget {
  final String? parcelId;

  const DeliveryPodScannerScreen({super.key, this.parcelId});

  @override
  State<DeliveryPodScannerScreen> createState() =>
      _DeliveryPodScannerScreenState();
}

class _DeliveryPodScannerScreenState extends State<DeliveryPodScannerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScannerService _scanner = ScannerService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _order;
  bool _loading = false;
  bool _delivered = false;
  String? _errorMsg;
  bool _scanMode = false;
  String _lastCode = '';

  Position? _gpsPosition;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  final TextEditingController _noteCtrl = TextEditingController();

  // Auto-confirm additions
  final SmartScanService _smartScan = SmartScanService();
  int _autoCountdown = 0;       // 3→2→1→0 = auto-confirm fires
  Timer? _countdownTimer;
  PodAutoConfirmResult? _gpsCheckResult;
  bool _autoConfirmCancelled = false;

  @override
  void initState() {
    super.initState();
    _acquireGps();
    if (widget.parcelId != null && widget.parcelId!.isNotEmpty) {
      _loadOrder(widget.parcelId!);
    } else {
      _scanMode = true;
      _scanner.startScanning();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scanner.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Auto-confirm logic ───────────────────────────────────────────────────────

  /// Called after order loads + GPS is available.
  /// If rider is within 150m of delivery address → starts 3-second countdown.
  void _checkAutoConfirm() {
    if (_order == null || _gpsPosition == null) return;
    if (_delivered || _autoConfirmCancelled) return;

    // Build a minimal OrderModel-like struct for GPS check
    // We pass lat/lng directly from the order map
    final lat = (_order!['deliveryAddress']?['latitude'] as num?)?.toDouble()
        ?? (_order!['addressLat'] as num?)?.toDouble()
        ?? (_order!['gpsLat'] as num?)?.toDouble();
    final lng = (_order!['deliveryAddress']?['longitude'] as num?)?.toDouble()
        ?? (_order!['addressLng'] as num?)?.toDouble()
        ?? (_order!['gpsLng'] as num?)?.toDouble();

    if (lat == null || lng == null || lat == 0 || lng == 0) return;

    final distance = Geolocator.distanceBetween(
      _gpsPosition!.latitude,
      _gpsPosition!.longitude,
      lat,
      lng,
    );

    final canAuto = distance <= 150.0;
    setState(() {
      _gpsCheckResult = PodAutoConfirmResult(
        canAutoConfirm: canAuto,
        distanceMeters: distance,
        reason: canAuto
            ? 'Within ${distance.toStringAsFixed(0)}m of address'
            : '${distance.toStringAsFixed(0)}m away (need ≤150m)',
      );
    });

    if (canAuto) {
      _startAutoConfirmCountdown();
    }
  }

  void _startAutoConfirmCountdown() {
    _countdownTimer?.cancel();
    setState(() => _autoCountdown = 3);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_autoConfirmCancelled) { t.cancel(); setState(() => _autoCountdown = 0); return; }

      setState(() => _autoCountdown--);
      if (_autoCountdown <= 0) {
        t.cancel();
        _confirmDelivery(); // auto-fires
      }
    });
  }

  void _cancelAutoConfirm() {
    _countdownTimer?.cancel();
    setState(() {
      _autoConfirmCancelled = true;
      _autoCountdown = 0;
    });
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _acquireGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _gpsPosition = pos);
      // If order already loaded, check auto-confirm now that GPS arrived
      if (_order != null) _checkAutoConfirm();
    } catch (_) {}
  }

  // ── Load order ──────────────────────────────────────────────────────────────

  Future<void> _loadOrder(String parcelId) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _order = null;
      _delivered = false;
    });
    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';

      final snap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .doc(parcelId)
          .get();

      if (!snap.exists) {
        setState(() {
          _loading = false;
          _errorMsg = 'Parcel #$parcelId not found';
        });
        return;
      }

      setState(() {
        _order = {'id': snap.id, ...snap.data()!};
        _loading = false;
        _scanMode = false;
        _autoConfirmCancelled = false; // reset for new order
        _gpsCheckResult = null;
      });
      // Attempt auto-confirm if GPS already acquired
      _checkAutoConfirm();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Error: $e';
      });
    }
  }

  // ── Photo proof ─────────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1080,
      );
      if (file == null) return;

      setState(() => _uploadingPhoto = true);

      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';
      final orderId = _order!['id'] as String;

      final ref = FirebaseStorage.instance
          .ref('shops/$shopId/pod_photos/$orderId.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Photo upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Confirm delivery ─────────────────────────────────────────────────────────

  Future<void> _confirmDelivery() async {
    if (_order == null) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';
      final orderId = _order!['id'] as String;

      final podData = {
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveredBy': auth.currentUser?.uid ?? '',
        'deliveredByName': auth.currentUser?.name ?? 'Rider',
        'podPhotoUrl': _photoUrl,
        'podGpsLat': _gpsPosition?.latitude,
        'podGpsLng': _gpsPosition?.longitude,
        'podGpsAccuracy': _gpsPosition?.accuracy,
        'podNote': _noteCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _db.batch();

      // Update order
      batch.update(
        _db.collection('shops').doc(shopId).collection('orders').doc(orderId),
        podData,
      );

      // Write POD log
      batch.set(
        _db.collection('shops').doc(shopId).collection('pod_logs').doc(),
        {
          'orderId': orderId,
          'orderNumber': _order!['orderNumber'] ?? orderId,
          'customerName': _order!['customerName'] ?? '',
          'customerPhone': _order!['customerPhone'] ?? '',
          'deliveredBy': auth.currentUser?.uid ?? '',
          'deliveredByName': auth.currentUser?.name ?? 'Rider',
          'branchId': auth.currentBranch?.id ?? '',
          'podPhotoUrl': _photoUrl,
          'gpsLat': _gpsPosition?.latitude,
          'gpsLng': _gpsPosition?.longitude,
          'note': _noteCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      HapticFeedback.heavyImpact();
      setState(() {
        _delivered = true;
        _loading = false;
        _order!['status'] = 'delivered';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to confirm: $e';
      });
    }
  }

  // ── Scanner ──────────────────────────────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty || raw == _lastCode) return;

    _lastCode = raw;
    HapticFeedback.mediumImpact();
    await _scanner.stopScanning();

    final parcelId = raw
        .replaceFirst('PARCEL-', '')
        .replaceFirst('ORDER-', '')
        .trim();

    setState(() => _scanMode = false);
    await _loadOrder(parcelId);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (!_scanMode)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _order = null;
                  _delivered = false;
                  _errorMsg = null;
                  _lastCode = '';
                  _photoUrl = null;
                  _noteCtrl.clear();
                });
                _scanner.startScanning();
              },
            ),
        ],
      ),
      body: _scanMode ? _buildScanner() : _buildPodForm(),
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
                      color: const Color(0xFF2E7D32), width: 3),
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
                  'Scan PARCEL-{OrderID} QR',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              if (_gpsPosition != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('GPS Ready',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodForm() {
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
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
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
    final alreadyDelivered = status == 'delivered' || _delivered;
    final customerName =
        _order!['customerName'] as String? ?? 'Customer';
    final orderNumber =
        _order!['orderNumber'] as String? ?? _order!['id'];
    final total =
        (_order!['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final address = _order!['deliveryAddress'] as String? ??
        _order!['address'] as String? ??
        'Address not available';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order summary card
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long,
                          color: Colors.green, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Order #$orderNumber',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Customer: $customerName',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (!alreadyDelivered) ...[
            // ── Auto-confirm countdown banner ────────────────────────────────
            if (_autoCountdown > 0)
              _AutoConfirmBanner(
                countdown: _autoCountdown,
                distanceMeters: _gpsCheckResult?.distanceMeters,
                onCancel: _cancelAutoConfirm,
              ),

            // GPS distance result (after auto-confirm dismissed)
            if (_autoCountdown == 0 &&
                _gpsCheckResult != null &&
                !_delivered)
              _GpsDistanceTile(result: _gpsCheckResult!),

            // GPS accuracy tile
            _GpsStatusTile(position: _gpsPosition),

            const SizedBox(height: 12),

            // Photo proof
            _PhotoProofTile(
              photoUrl: _photoUrl,
              uploading: _uploadingPhoto,
              onCapture: _capturePhoto,
            ),

            const SizedBox(height: 12),

            // Delivery note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Delivery note (e.g. "Left at door", "Neighbour received")',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note_outlined),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: const Text(
                'Confirm Delivery',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _confirmDelivery,
            ),
          ] else ...[
            // Success state
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Delivered Successfully!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Order #$orderNumber marked as delivered.',
                    style: const TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Next Delivery'),
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _order = null;
                  _delivered = false;
                  _photoUrl = null;
                  _lastCode = '';
                  _noteCtrl.clear();
                });
                _scanner.startScanning();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GpsStatusTile extends StatelessWidget {
  final Position? position;
  const _GpsStatusTile({required this.position});

  @override
  Widget build(BuildContext context) {
    final ready = position != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on,
              color: ready ? Colors.green : Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ready
                  ? 'GPS acquired (±${position!.accuracy.toStringAsFixed(0)}m)'
                  : 'Acquiring GPS location…',
              style: TextStyle(
                  color: ready ? Colors.green : Colors.orange,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoProofTile extends StatelessWidget {
  final String? photoUrl;
  final bool uploading;
  final VoidCallback onCapture;

  const _PhotoProofTile({
    required this.photoUrl,
    required this.uploading,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onCapture,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: photoUrl != null
              ? Colors.green.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photoUrl != null
                ? Colors.green.withValues(alpha: 0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    photoUrl != null
                        ? Icons.check_circle
                        : Icons.camera_alt_outlined,
                    color: photoUrl != null ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    photoUrl != null
                        ? 'Photo Proof Captured'
                        : 'Take Photo Proof (optional)',
                    style: TextStyle(
                      color: photoUrl != null ? Colors.green : Colors.grey,
                      fontWeight: photoUrl != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AutoConfirmBanner
// Shows a 3→0 countdown with a prominent Cancel button.
// ─────────────────────────────────────────────────────────────────────────────

class _AutoConfirmBanner extends StatelessWidget {
  final int countdown;
  final double? distanceMeters;
  final VoidCallback onCancel;

  const _AutoConfirmBanner({
    required this.countdown,
    required this.distanceMeters,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
            width: 2),
      ),
      child: Row(
        children: [
          // Countdown circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$countdown',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-confirming delivery…',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 14),
                ),
                if (distanceMeters != null)
                  Text(
                    'GPS match: ${distanceMeters!.toStringAsFixed(0)}m from address',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
            ),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GpsDistanceTile — shows GPS check result after countdown dismissed
// ─────────────────────────────────────────────────────────────────────────────

class _GpsDistanceTile extends StatelessWidget {
  final PodAutoConfirmResult result;
  const _GpsDistanceTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.canAutoConfirm;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.location_on : Icons.location_searching,
            color: ok ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.reason,
              style: TextStyle(
                  fontSize: 12,
                  color: ok ? Colors.green : Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}
