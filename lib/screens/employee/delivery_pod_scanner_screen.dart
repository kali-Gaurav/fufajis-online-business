import '../../services/logging_service.dart';
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
import '../../utils/app_theme.dart';

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
  State<DeliveryPodScannerScreen> createState() => _DeliveryPodScannerScreenState();
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
  final TextEditingController _otpCtrl = TextEditingController();
  bool _cashCollected = false;
  bool _otpVerified = false;
  String? _otpError;

  // Auto-confirm additions
  int _autoCountdown = 0; // 3→2→1→0 = auto-confirm fires
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
    _otpCtrl.dispose();
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
    final lat =
        (_order!['deliveryAddress']?['latitude'] as num?)?.toDouble() ??
        (_order!['addressLat'] as num?)?.toDouble() ??
        (_order!['gpsLat'] as num?)?.toDouble();
    final lng =
        (_order!['deliveryAddress']?['longitude'] as num?)?.toDouble() ??
        (_order!['addressLng'] as num?)?.toDouble() ??
        (_order!['gpsLng'] as num?)?.toDouble();

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
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_autoConfirmCancelled) {
        t.cancel();
        setState(() => _autoCountdown = 0);
        return;
      }

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
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _gpsPosition = pos);
      // If order already loaded, check auto-confirm now that GPS arrived
      if (_order != null) _checkAutoConfirm();
    } catch (e, stack) {
      LoggingService().error('Silent error caught', e, stack);
    }
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
        _cashCollected = false;
        _otpVerified = false;
        _otpError = null;
        _otpCtrl.clear();
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

      final ref = FirebaseStorage.instance.ref('shops/$shopId/pod_photos/$orderId.jpg');
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
          SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── Confirm delivery ─────────────────────────────────────────────────────────

  Future<void> _confirmDelivery() async {
    if (_order == null) return;

    final bool isCod =
        _order!['paymentMethod'] == 'cod' || _order!['paymentMethod'] == 'PaymentMethod.cod';
    final bool isPendingPayment = _order!['paymentStatus'] == 'pending';
    final String? expectedOtp = _order!['deliveryOtp'] as String?;
    final bool requiresOtp = expectedOtp != null && expectedOtp.isNotEmpty;

    if (requiresOtp && !_otpVerified) {
      if (_otpCtrl.text.trim() != expectedOtp) {
        setState(() => _otpError = 'Invalid OTP');
        return;
      } else {
        setState(() {
          _otpVerified = true;
          _otpError = null;
        });
      }
    }

    if (isCod && isPendingPayment && !_cashCollected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm that you have collected the cash!'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';
      final orderId = _order!['id'] as String;
      final double total = (_order!['totalAmount'] as num?)?.toDouble() ?? 0.0;

      // 1. Geofence Check (50 meters)
      final lat =
          (_order!['deliveryAddress']?['latitude'] as num?)?.toDouble() ??
          (_order!['addressLat'] as num?)?.toDouble() ??
          (_order!['gpsLat'] as num?)?.toDouble();
      final lng =
          (_order!['deliveryAddress']?['longitude'] as num?)?.toDouble() ??
          (_order!['addressLng'] as num?)?.toDouble() ??
          (_order!['gpsLng'] as num?)?.toDouble();

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        if (_gpsPosition == null) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          setState(() => _gpsPosition = pos);
        }

        final distance = Geolocator.distanceBetween(
          _gpsPosition!.latitude,
          _gpsPosition!.longitude,
          lat,
          lng,
        );

        if (distance > 50.0) {
          throw Exception(
            'You must be within 50 meters of the delivery destination to confirm. Current distance: ${distance.toStringAsFixed(0)}m.',
          );
        }
      }

      // 2. Atomic Firestore Transaction
      await _db.runTransaction((transaction) async {
        final orderRef = _db.collection('shops').doc(shopId).collection('orders').doc(orderId);
        final orderSnap = await transaction.get(orderRef);

        if (!orderSnap.exists) {
          throw Exception('Order does not exist.');
        }

        final orderData = orderSnap.data()!;
        if (orderData['status'] == 'delivered') {
          throw Exception('This order is already marked delivered.');
        }

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

        if (isCod && isPendingPayment && _cashCollected) {
          podData['paymentStatus'] = 'paid';
          podData['cashCollectedBy'] = auth.currentUser?.uid ?? '';
          podData['cashCollectedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(orderRef, podData);

        // Write POD log
        final logRef = _db.collection('shops').doc(shopId).collection('pod_logs').doc();
        transaction.set(logRef, {
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
        });

        // Update Rider cash liability & COD settlement log
        if (isCod && isPendingPayment && _cashCollected) {
          final riderId = auth.currentUser?.uid ?? '';
          if (riderId.isNotEmpty) {
            final riderRef = _db.collection('users').doc(riderId);
            transaction.update(riderRef, {
              'currentCashBalance': FieldValue.increment(total),
              'lastDeliveryAt': FieldValue.serverTimestamp(),
            });

            final codRef = _db.collection('cod_settlements').doc('cod_$orderId');
            transaction.set(codRef, {
              'id': 'cod_$orderId',
              'orderId': orderId,
              'riderId': riderId,
              'riderName': auth.currentUser?.name ?? 'Rider',
              'amount': total,
              'status': 'collected',
              'collectedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });

      // Mirror to AWS RDS is deprecated. Status is managed in Firestore.
      debugPrint('[DeliveryPOD] RDS Mirror deprecated for order $orderId');

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

    final parcelId = raw.replaceFirst('PARCEL-', '').replaceFirst('ORDER-', '').trim();

    setState(() => _scanMode = false);
    await _loadOrder(parcelId);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
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
        MobileScanner(controller: _scanner.controller, onDetect: _onBarcodeDetected),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2E7D32), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('GPS Ready', style: TextStyle(color: Colors.white, fontSize: 12)),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
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
    final customerName = _order!['customerName'] as String? ?? 'Customer';
    final orderNumber = _order!['orderNumber'] as String? ?? _order!['id'];
    final total = (_order!['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final address =
        _order!['deliveryAddress']?['fullAddress'] as String? ??
        _order!['address'] as String? ??
        'Address not available';
    final isCod =
        _order!['paymentMethod'] == 'cod' || _order!['paymentMethod'] == 'PaymentMethod.cod';
    final isPendingPayment = _order!['paymentStatus'] == 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order summary card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: AppTheme.success, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Order #$orderNumber',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Customer: $customerName', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
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
            if (_autoCountdown == 0 && _gpsCheckResult != null && !_delivered)
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

            // OTP Verification
            if (_order!['deliveryOtp'] != null && _order!['deliveryOtp'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  border: Border.all(color: AppTheme.info.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OTP Verification Required',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.info),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter OTP from customer',
                        errorText: _otpError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.password),
                        suffixIcon: _otpVerified
                            ? const Icon(Icons.check_circle, color: AppTheme.success)
                            : null,
                      ),
                      onChanged: (val) {
                        if (_otpError != null) setState(() => _otpError = null);
                      },
                    ),
                  ],
                ),
              ),

            // Delivery note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Delivery note (e.g. "Left at door", "Neighbour received")',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.note_outlined),
              ),
            ),

            const SizedBox(height: 16),

            if (isCod && isPendingPayment)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  border: Border.all(color: AppTheme.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.money, color: AppTheme.warning, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Collect Cash: ₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _cashCollected,
                      onChanged: (val) {
                        setState(() => _cashCollected = val ?? false);
                        // If checking the box, cancel auto-confirm to let them do it manually
                        if (val == true) _cancelAutoConfirm();
                      },
                      title: const Text(
                        'I have collected the cash from customer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.warning,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: const Text(
                'Confirm Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _confirmDelivery,
            ),
          ] else ...[
            // Success state
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.success, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Delivered Successfully!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
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
                  _otpCtrl.clear();
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
            ? AppTheme.success.withOpacity(0.08)
            : AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: ready ? AppTheme.success : AppTheme.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ready
                  ? 'GPS acquired (±${position!.accuracy.toStringAsFixed(0)}m)'
                  : 'Acquiring GPS location…',
              style: TextStyle(color: ready ? AppTheme.success : AppTheme.warning, fontSize: 13),
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

  const _PhotoProofTile({required this.photoUrl, required this.uploading, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onCapture,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: photoUrl != null ? AppTheme.success.withOpacity(0.05) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photoUrl != null
                ? AppTheme.success.withOpacity(0.4)
                : Colors.grey.shade300,
          ),
        ),
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    photoUrl != null ? Icons.check_circle : Icons.camera_alt_outlined,
                    color: photoUrl != null ? AppTheme.success : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    photoUrl != null ? 'Photo Proof Captured' : 'Take Photo Proof (optional)',
                    style: TextStyle(
                      color: photoUrl != null ? AppTheme.success : Colors.grey,
                      fontWeight: photoUrl != null ? FontWeight.bold : FontWeight.normal,
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
        color: const Color(0xFF2E7D32).withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          // Countdown circle
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                    fontSize: 14,
                  ),
                ),
                if (distanceMeters != null)
                  Text(
                    'GPS match: ${distanceMeters!.toStringAsFixed(0)}m from address',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? AppTheme.success.withOpacity(0.08)
            : AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? AppTheme.success.withOpacity(0.3)
              : AppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.location_on : Icons.location_searching,
            color: ok ? AppTheme.success : AppTheme.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.reason,
              style: TextStyle(fontSize: 12, color: ok ? AppTheme.success : AppTheme.warning),
            ),
          ),
        ],
      ),
    );
  }
}
