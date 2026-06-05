import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScannerService — camera control + all 9 scan-action types
// Every scan is written to Firestore scan_logs for owner audit trail.
// ─────────────────────────────────────────────────────────────────────────────

class ScannerService {
  final MobileScannerController _controller = MobileScannerController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Barcode> _scannedCodes = [];
  final ValueNotifier<Barcode?> _latestScan = ValueNotifier<Barcode?>(null);
  final ValueNotifier<bool> _isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<ScanResult?> _lastResult =
      ValueNotifier<ScanResult?>(null);

  // Getters
  MobileScannerController get controller => _controller;
  ValueNotifier<Barcode?> get latestScan => _latestScan;
  ValueNotifier<bool> get isScanning => _isScanning;
  ValueNotifier<ScanResult?> get lastResult => _lastResult;
  List<Barcode> get scannedCodes => List.unmodifiable(_scannedCodes);

  // ── Camera control ──────────────────────────────────────────────────────────

  Future<void> startScanning() async {
    await _controller.start();
    _isScanning.value = true;
  }

  Future<void> stopScanning() async {
    await _controller.stop();
    _isScanning.value = false;
  }

  Future<void> toggleFlashlight() async {
    await _controller.toggleTorch();
  }

  Future<void> switchCamera() async {
    await _controller.switchCamera();
  }

  // ── Barcode processing ──────────────────────────────────────────────────────

  void processBarcode(Barcode barcode) {
    _latestScan.value = barcode;
    _scannedCodes.add(barcode);

    final rawValue = barcode.rawValue;
    if (rawValue != null) {
      _lastResult.value = ScanResult(
        code: rawValue,
        format: barcode.format.name,
        type: barcode.type.name,
        timestamp: DateTime.now(),
      );
    }
  }

  void clearScannedCodes() {
    _scannedCodes.clear();
    _latestScan.value = null;
    _lastResult.value = null;
  }

  // ── Action parsing — all 9 scan types ──────────────────────────────────────
  //
  // QR prefixes used throughout the app:
  //   ORDER-{id}       → Packing
  //   DISPATCH-{id}    → Dispatch verification
  //   PARCEL-{id}      → Proof of Delivery
  //   TRANSFER-{id}    → Inventory transfer
  //   AUDIT-{id}       → Stock audit
  //   ATTENDANCE-{id}  → Attendance QR
  //   SHELF-{id}       → Shelf audit / refill
  //   MEMBER-{id}      → Customer membership QR
  //   upi:{url}        → Payment QR
  //   (anything else)  → Product barcode

  ScanAction parseScanAction(String code) {
    if (code.startsWith('ORDER-')) {
      return ScanAction.orderPacking(code);
    } else if (code.startsWith('DISPATCH-')) {
      return ScanAction.dispatchVerification(code);
    } else if (code.startsWith('PARCEL-')) {
      return ScanAction.proofOfDelivery(code);
    } else if (code.startsWith('TRANSFER-')) {
      return ScanAction.inventoryTransfer(code);
    } else if (code.startsWith('AUDIT-')) {
      return ScanAction.stockAudit(code);
    } else if (code.startsWith('ATTENDANCE-')) {
      return ScanAction.attendance(code);
    } else if (code.startsWith('SHELF-')) {
      return ScanAction.shelfCheck(code);
    } else if (code.startsWith('MEMBER-')) {
      return ScanAction.membershipLookup(code);
    } else if (code.toLowerCase().startsWith('upi:')) {
      return ScanAction.paymentQr(code);
    } else {
      return ScanAction.productScan(code);
    }
  }

  // ── Firestore scan_log audit trail ─────────────────────────────────────────
  //
  // shops/{shopId}/scan_logs/{logId}
  // Security: authenticated users write only their own logs.
  // Owners can read all; employees read only their own.

  Future<void> writeScanLog({
    required String shopId,
    required String branchId,
    required String employeeId,
    required String employeeName,
    required String employeeRole, // owner | employee | delivery
    required ScanAction action,
    String? extra,
  }) async {
    try {
      final logId = const Uuid().v4();
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('scan_logs')
          .doc(logId)
          .set({
        'id': logId,
        'shopId': shopId,
        'branchId': branchId,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'employeeRole': employeeRole,
        'scanCode': action.code,
        'actionType': action.actionType,
        'actionLabel': action.displayLabel,
        'metadata': action.metadata,
        'extra': extra,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let audit log failure break the primary workflow.
    }
  }

  // ── Owner: real-time scan activity stream ───────────────────────────────────

  Stream<QuerySnapshot> scanLogsStream({
    required String shopId,
    String? branchId,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('scan_logs')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (branchId != null && branchId.isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId);
    }

    return query.snapshots();
  }

  void dispose() {
    _controller.dispose();
    _latestScan.dispose();
    _isScanning.dispose();
    _lastResult.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanResult — raw barcode capture
// ─────────────────────────────────────────────────────────────────────────────

class ScanResult {
  final String code;
  final String format;
  final String type;
  final DateTime timestamp;

  const ScanResult({
    required this.code,
    required this.format,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'code': code,
        'format': format,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ScanResult.fromMap(Map<String, dynamic> map) => ScanResult(
        code: map['code'] ?? '',
        format: map['format'] ?? 'unknown',
        type: map['type'] ?? 'unknown',
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanAction — parsed intent
// ─────────────────────────────────────────────────────────────────────────────

class ScanAction {
  final String code;
  final String actionType;
  final String displayLabel;
  final Map<String, dynamic> metadata;

  const ScanAction._({
    required this.code,
    required this.actionType,
    required this.displayLabel,
    required this.metadata,
  });

  factory ScanAction.productScan(String barcode) => ScanAction._(
        code: barcode,
        actionType: ScanMode.productSearch,
        displayLabel: 'Product Search',
        metadata: {'barcode': barcode},
      );

  factory ScanAction.orderPacking(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.orderPacking,
        displayLabel: 'Order Packing',
        metadata: {'orderId': raw.replaceFirst('ORDER-', '')},
      );

  factory ScanAction.dispatchVerification(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.dispatch,
        displayLabel: 'Dispatch Verification',
        metadata: {'orderId': raw.replaceFirst('DISPATCH-', '')},
      );

  factory ScanAction.proofOfDelivery(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.deliveryPOD,
        displayLabel: 'Proof of Delivery',
        metadata: {'parcelId': raw.replaceFirst('PARCEL-', '')},
      );

  factory ScanAction.inventoryTransfer(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.inventoryReceiving,
        displayLabel: 'Inventory Transfer',
        metadata: {'transferId': raw.replaceFirst('TRANSFER-', '')},
      );

  factory ScanAction.stockAudit(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.inventoryAudit,
        displayLabel: 'Stock Audit',
        metadata: {'auditId': raw.replaceFirst('AUDIT-', '')},
      );

  factory ScanAction.attendance(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.attendance,
        displayLabel: 'Attendance',
        metadata: {'attendanceId': raw.replaceFirst('ATTENDANCE-', '')},
      );

  factory ScanAction.shelfCheck(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.shelfAudit,
        displayLabel: 'Shelf Audit',
        metadata: {'shelfId': raw.replaceFirst('SHELF-', '')},
      );

  factory ScanAction.membershipLookup(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.customerMembership,
        displayLabel: 'Customer Membership',
        metadata: {'customerId': raw.replaceFirst('MEMBER-', '')},
      );

  factory ScanAction.paymentQr(String raw) => ScanAction._(
        code: raw,
        actionType: ScanMode.paymentQr,
        displayLabel: 'Payment QR',
        metadata: {'upiUrl': raw},
      );

  String get displayCode => code.replaceAll(RegExp(r'^[A-Z]+-'), '');

  Map<String, dynamic> toMap() => {
        'code': code,
        'actionType': actionType,
        'displayLabel': displayLabel,
        'metadata': metadata,
      };

  factory ScanAction.fromMap(Map<String, dynamic> map) => ScanAction._(
        code: map['code'] ?? '',
        actionType: map['actionType'] ?? ScanMode.productSearch,
        displayLabel: map['displayLabel'] ?? '',
        metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ScanMode — single source of truth for all 9+1 modes
// ─────────────────────────────────────────────────────────────────────────────

class ScanMode {
  ScanMode._();

  static const String productSearch = 'product_search';
  static const String orderPacking = 'order_packing';
  static const String dispatch = 'dispatch';
  static const String deliveryPOD = 'delivery_pod';
  static const String inventoryReceiving = 'inventory_receiving';
  static const String inventoryAudit = 'inventory_audit';
  static const String shelfAudit = 'shelf_audit';
  static const String customerMembership = 'customer_membership';
  static const String paymentQr = 'payment_qr';
  static const String attendance = 'attendance';

  static const List<ScanModeConfig> all = [
    ScanModeConfig(
      id: productSearch,
      label: 'Product Search',
      labelHi: 'उत्पाद खोज',
      description: 'Look up price, stock & details',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF1565C0),
      roles: ['owner', 'employee', 'delivery'],
    ),
    ScanModeConfig(
      id: orderPacking,
      label: 'Order Packing',
      labelHi: 'ऑर्डर पैकिंग',
      description: 'Verify items before sealing',
      icon: Icons.inventory_outlined,
      color: Color(0xFF6A1B9A),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: dispatch,
      label: 'Dispatch',
      labelHi: 'डिस्पैच',
      description: 'Verify packed order before dispatch',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFFE65100),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: deliveryPOD,
      label: 'Proof of Delivery',
      labelHi: 'डिलीवरी प्रमाण',
      description: 'Confirm delivery at customer door',
      icon: Icons.check_circle_outline,
      color: Color(0xFF2E7D32),
      roles: ['delivery'],
    ),
    ScanModeConfig(
      id: inventoryReceiving,
      label: 'Receive Stock',
      labelHi: 'स्टॉक प्राप्ति',
      description: 'Add incoming supplier stock',
      icon: Icons.move_to_inbox_outlined,
      color: Color(0xFF00695C),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: inventoryAudit,
      label: 'Stock Audit',
      labelHi: 'स्टॉक ऑडिट',
      description: 'Count and verify physical stock',
      icon: Icons.assignment_outlined,
      color: Color(0xFF558B2F),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: shelfAudit,
      label: 'Shelf Audit',
      labelHi: 'शेल्फ ऑडिट',
      description: 'Check shelf stock, trigger refills',
      icon: Icons.shelves,
      color: Color(0xFFF57F17),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: customerMembership,
      label: 'Member Lookup',
      labelHi: 'सदस्य जानकारी',
      description: 'View customer profile & orders',
      icon: Icons.card_membership_outlined,
      color: Color(0xFFAD1457),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: paymentQr,
      label: 'Payment QR',
      labelHi: 'भुगतान QR',
      description: 'Verify or initiate UPI payment',
      icon: Icons.qr_code_scanner,
      color: Color(0xFF4527A0),
      roles: ['owner', 'employee'],
    ),
    ScanModeConfig(
      id: attendance,
      label: 'Attendance',
      labelHi: 'उपस्थिति',
      description: 'Check in / out via QR',
      icon: Icons.fingerprint,
      color: Color(0xFF37474F),
      roles: ['owner', 'employee'],
    ),
  ];

  /// Return only modes accessible to a given role
  static List<ScanModeConfig> forRole(String role) =>
      all.where((m) => m.roles.contains(role)).toList();

  static ScanModeConfig? find(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}

class ScanModeConfig {
  final String id;
  final String label;
  final String labelHi;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> roles; // which roles can see this mode

  const ScanModeConfig({
    required this.id,
    required this.label,
    required this.labelHi,
    required this.description,
    required this.icon,
    required this.color,
    required this.roles,
  });
}
