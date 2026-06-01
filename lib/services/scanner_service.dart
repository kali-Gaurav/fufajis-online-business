import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' hide Barcode;

/// Service for handling barcode/QR code scanning operations
class ScannerService {
  final MobileScannerController _controller = MobileScannerController();
  final List<Barcode> _scannedCodes = [];
  final ValueNotifier<Barcode?> _latestScan = ValueNotifier<Barcode?>(null);
  final ValueNotifier<bool> _isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<ScanResult?> _lastResult = ValueNotifier<ScanResult?>(null);

  // Getters
  MobileScannerController get controller => _controller;
  ValueNotifier<Barcode?> get latestScan => _latestScan;
  ValueNotifier<bool> get isScanning => _isScanning;
  ValueNotifier<ScanResult?> get lastResult => _lastResult;
  List<Barcode> get scannedCodes => List.unmodifiable(_scannedCodes);

  /// Start scanning
  Future<void> startScanning() async {
    await _controller.start();
    _isScanning.value = true;
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    await _controller.stop();
    _isScanning.value = false;
  }

  /// Toggle flashlight
  Future<void> toggleFlashlight() async {
    await _controller.toggleTorch();
  }

  /// Switch camera
  Future<void> switchCamera() async {
    await _controller.switchCamera();
  }

  /// Process a detected barcode
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

  /// Clear scanned codes
  void clearScannedCodes() {
    _scannedCodes.clear();
    _latestScan.value = null;
    _lastResult.value = null;
  }

  /// Parse scanned code and return appropriate action
  ScanAction parseScanAction(String code) {
    if (code.startsWith('ORDER-')) {
      return ScanAction.orderPacking(code);
    } else if (code.startsWith('TRANSFER-')) {
      return ScanAction.inventoryTransfer(code);
    } else if (code.startsWith('AUDIT-')) {
      return ScanAction.stockAudit(code);
    } else if (code.startsWith('ATTENDANCE-')) {
      return ScanAction.attendance(code);
    } else if (code.startsWith('PARCEL-')) {
      return ScanAction.deliveryVerification(code);
    } else if (code.startsWith('SHELF-')) {
      return ScanAction.shelfCheck(code);
    } else {
      // Assume it's a product barcode
      return ScanAction.productScan(code);
    }
  }

  /// Dispose resources
  void dispose() {
    _controller.dispose();
    _latestScan.dispose();
    _isScanning.dispose();
    _lastResult.dispose();
  }
}

/// Result of a scan operation
class ScanResult {
  final String code;
  final String format;
  final String type;
  final DateTime timestamp;

  ScanResult({
    required this.code,
    required this.format,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'format': format,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) {
    return ScanResult(
      code: map['code'] ?? '',
      format: map['format'] ?? 'unknown',
      type: map['type'] ?? 'unknown',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Types of scan actions
class ScanAction {
  final String code;
  final String actionType;
  final Map<String, dynamic> metadata;

  ScanAction._(this.code, this.actionType, this.metadata);

  factory ScanAction.productScan(String barcode) {
    return ScanAction._(
      barcode,
      'product_scan',
      {'barcode': barcode},
    );
  }

  factory ScanAction.orderPacking(String orderId) {
    return ScanAction._(
      orderId,
      'order_packing',
      {'orderId': orderId.replaceFirst('ORDER-', '')},
    );
  }

  factory ScanAction.inventoryTransfer(String transferId) {
    return ScanAction._(
      transferId,
      'inventory_transfer',
      {'transferId': transferId.replaceFirst('TRANSFER-', '')},
    );
  }

  factory ScanAction.stockAudit(String auditId) {
    return ScanAction._(
      auditId,
      'stock_audit',
      {'auditId': auditId.replaceFirst('AUDIT-', '')},
    );
  }

  factory ScanAction.attendance(String attendanceId) {
    return ScanAction._(
      attendanceId,
      'attendance',
      {'attendanceId': attendanceId.replaceFirst('ATTENDANCE-', '')},
    );
  }

  factory ScanAction.deliveryVerification(String parcelId) {
    return ScanAction._(
      parcelId,
      'delivery_verification',
      {'parcelId': parcelId.replaceFirst('PARCEL-', '')},
    );
  }

  factory ScanAction.shelfCheck(String shelfId) {
    return ScanAction._(
      shelfId,
      'shelf_check',
      {'shelfId': shelfId.replaceFirst('SHELF-', '')},
    );
  }

  String get displayCode => code.replaceAll(RegExp(r'^[A-Z]+-'), '');

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'actionType': actionType,
      'metadata': metadata,
    };
  }

  factory ScanAction.fromMap(Map<String, dynamic> map) {
    return ScanAction._(
      map['code'] ?? '',
      map['actionType'] ?? 'unknown',
      Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}