import '../services/logging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Model for inventory audit records
class InventoryAudit {
  final String id;
  final String shopId;
  final String branchId;
  final String productId;
  final String productName;
  final String barcode;
  final int expectedStock;
  final int actualStock;
  final int difference;
  final String employeeId;
  final String employeeName;
  final DateTime auditDate;
  final String? notes;
  final List<String>? photos;
  final String status; // pending, verified, resolved

  InventoryAudit({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.expectedStock,
    required this.actualStock,
    required this.employeeId,
    required this.employeeName,
    required this.auditDate,
    this.notes,
    this.photos,
    this.status = 'pending',
  }) : difference = actualStock - expectedStock;

  factory InventoryAudit.fromMap(Map<String, dynamic> map) {
    return InventoryAudit(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      expectedStock: map['expectedStock'] as int? ?? 0,
      actualStock: map['actualStock'] as int? ?? 0,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      auditDate: _parseDate(map['auditDate']) ?? DateTime.now(),
      notes: map['notes'] as String?,
      photos: List<String>.from(map['photos'] as Iterable? ?? []),
      status: map['status'] as String? ?? 'pending',
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'expectedStock': expectedStock,
      'actualStock': actualStock,
      'difference': difference,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'auditDate': auditDate,
      'notes': notes,
      'photos': photos,
      'status': status,
    };
  }

  String get differenceDisplay {
    if (difference > 0) return '+$difference';
    return difference.toString();
  }

  bool get hasDiscrepancy => difference != 0;
}

/// Model for damage/damaged product reports
class DamageReport {
  final String id;
  final String shopId;
  final String branchId;
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final DamageType damageType;
  final String? reason;
  final String employeeId;
  final String employeeName;
  final DateTime reportDate;
  final String status; // pending, reviewed, resolved
  final double? wasteValue;

  DamageReport({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.damageType,
    this.reason,
    required this.employeeId,
    required this.employeeName,
    required this.reportDate,
    this.status = 'pending',
    this.wasteValue,
  });

  factory DamageReport.fromMap(Map<String, dynamic> map) {
    return DamageReport(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 1,
      damageType: DamageType.values.firstWhere(
        (e) => e.name == map['damageType'] as String?,
        orElse: () => DamageType.other,
      ),
      reason: map['reason'] as String?,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      reportDate: _parseDate(map['reportDate']) ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      wasteValue: (map['wasteValue'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'damageType': damageType.name,
      'reason': reason,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'reportDate': reportDate,
      'status': status,
      'wasteValue': wasteValue,
    };
  }
}

enum DamageType { broken, expired, leaking, damagedPackaging, other }

/// Model for inventory transfers between branches
class InventoryTransfer {
  final String id;
  final String shopId;
  final String sourceBranchId;
  final String sourceBranchName;
  final String destinationBranchId;
  final String destinationBranchName;
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final TransferStatus status;
  final String requestedBy;
  final String requestedByName;
  final DateTime requestedAt;
  final DateTime? shippedAt;
  final DateTime? receivedAt;
  final String? notes;
  final String? trackingNumber;

  InventoryTransfer({
    required this.id,
    required this.shopId,
    required this.sourceBranchId,
    required this.sourceBranchName,
    required this.destinationBranchId,
    required this.destinationBranchName,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    this.status = TransferStatus.pending,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedAt,
    this.shippedAt,
    this.receivedAt,
    this.notes,
    this.trackingNumber,
  });

  factory InventoryTransfer.fromMap(Map<String, dynamic> map) {
    return InventoryTransfer(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      sourceBranchId: map['sourceBranchId'] as String? ?? '',
      sourceBranchName: map['sourceBranchName'] as String? ?? '',
      destinationBranchId: map['destinationBranchId'] as String? ?? '',
      destinationBranchName: map['destinationBranchName'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      status: TransferStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => TransferStatus.pending,
      ),
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedByName: map['requestedByName'] as String? ?? '',
      requestedAt: _parseDate(map['requestedAt']) ?? DateTime.now(),
      shippedAt: _parseDate(map['shippedAt']),
      receivedAt: _parseDate(map['receivedAt']),
      notes: map['notes'] as String?,
      trackingNumber: map['trackingNumber'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'sourceBranchId': sourceBranchId,
      'sourceBranchName': sourceBranchName,
      'destinationBranchId': destinationBranchId,
      'destinationBranchName': destinationBranchName,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'status': status.name,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'requestedAt': requestedAt,
      'shippedAt': shippedAt,
      'receivedAt': receivedAt,
      'notes': notes,
      'trackingNumber': trackingNumber,
    };
  }
}

enum TransferStatus { pending, shipped, inTransit, received, cancelled }

/// Model for employee attendance records
class AttendanceRecord {
  final String id;
  final String shopId;
  final String branchId;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final LocationData? checkInLocation;
  final LocationData? checkOutLocation;
  final String? qrCodeId;
  final AttendanceStatus status;
  final double? workingHours;

  AttendanceRecord({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.qrCodeId,
    this.status = AttendanceStatus.present,
    this.workingHours,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      date: _parseDate(map['date']) ?? DateTime.now(),
      checkInTime: _parseDate(map['checkInTime']),
      checkOutTime: _parseDate(map['checkOutTime']),
      checkInLocation: map['checkInLocation'] != null
          ? LocationData.fromMap(
              Map<String, dynamic>.from(map['checkInLocation'] as Map),
            )
          : null,
      checkOutLocation: map['checkOutLocation'] != null
          ? LocationData.fromMap(
              Map<String, dynamic>.from(map['checkOutLocation'] as Map),
            )
          : null,
      qrCodeId: map['qrCodeId'] as String?,
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == map['status'] as String?,
        orElse: () => AttendanceStatus.present,
      ),
      workingHours: (map['workingHours'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date,
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'checkInLocation': checkInLocation?.toMap(),
      'checkOutLocation': checkOutLocation?.toMap(),
      'qrCodeId': qrCodeId,
      'status': status.name,
      'workingHours': workingHours,
    };
  }

  bool get isCheckedIn => checkInTime != null;
  bool get isCheckedOut => checkOutTime != null;
  bool get isComplete => isCheckedIn && isCheckedOut;
}

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
  });

  factory LocationData.fromPosition(Position position) {
    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (map['longitude'] as num? ?? 0.0).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
    };
  }

  double distanceTo(LocationData other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }
}

enum AttendanceStatus { present, absent, late, halfDay, onLeave }

/// Model for cash collection records
class CashCollection {
  final String id;
  final String shopId;
  final String branchId;
  final String orderId;
  final String deliveryEmployeeId;
  final String deliveryEmployeeName;
  final double amount;
  final DateTime collectionTime;
  final String? notes;
  final String status; // pending, collected, deposited

  CashCollection({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.orderId,
    required this.deliveryEmployeeId,
    required this.deliveryEmployeeName,
    required this.amount,
    required this.collectionTime,
    this.notes,
    this.status = 'pending',
  });

  factory CashCollection.fromMap(Map<String, dynamic> map) {
    return CashCollection(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      deliveryEmployeeId: map['deliveryEmployeeId'] as String? ?? '',
      deliveryEmployeeName: map['deliveryEmployeeName'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      collectionTime: _parseDate(map['collectionTime']) ?? DateTime.now(),
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'pending',
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'orderId': orderId,
      'deliveryEmployeeId': deliveryEmployeeId,
      'deliveryEmployeeName': deliveryEmployeeName,
      'amount': amount,
      'collectionTime': collectionTime,
      'notes': notes,
      'status': status,
    };
  }
}

/// Model for return processing
class ReturnRecord {
  final String id;
  final String shopId;
  final String branchId;
  final String orderId;
  final String productId;
  final String productName;
  final String barcode;
  final int quantity;
  final ReturnCondition condition;
  final String? reason;
  final String employeeId;
  final String employeeName;
  final DateTime returnDate;
  final String status; // pending, processed, refunded
  final double? refundAmount;

  ReturnRecord({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.condition,
    this.reason,
    required this.employeeId,
    required this.employeeName,
    required this.returnDate,
    this.status = 'pending',
    this.refundAmount,
  });

  factory ReturnRecord.fromMap(Map<String, dynamic> map) {
    return ReturnRecord(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 1,
      condition: ReturnCondition.values.firstWhere(
        (e) => e.name == map['condition'] as String?,
        orElse: () => ReturnCondition.opened,
      ),
      reason: map['reason'] as String?,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      returnDate: _parseDate(map['returnDate']) ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      refundAmount: (map['refundAmount'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'orderId': orderId,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'condition': condition.name,
      'reason': reason,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'returnDate': returnDate,
      'status': status,
      'refundAmount': refundAmount,
    };
  }
}

enum ReturnCondition { opened, unopened, damaged }

/// Model for shelf refill alerts
class ShelfRefillAlert {
  final String id;
  final String shopId;
  final String branchId;
  final String shelfId;
  final String shelfName;
  final String productId;
  final String productName;
  final String barcode;
  final int currentShelfQuantity;
  final int minimumQuantity;
  final DateTime alertDate;
  final String status; // pending, acknowledged, completed
  final String? notes;

  ShelfRefillAlert({
    required this.id,
    required this.shopId,
    required this.branchId,
    required this.shelfId,
    required this.shelfName,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.currentShelfQuantity,
    required this.minimumQuantity,
    required this.alertDate,
    this.status = 'pending',
    this.notes,
  });

  factory ShelfRefillAlert.fromMap(Map<String, dynamic> map) {
    return ShelfRefillAlert(
      id: map['id'] as String? ?? '',
      shopId: map['shopId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      shelfId: map['shelfId'] as String? ?? '',
      shelfName: map['shelfName'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      barcode: map['barcode'] as String? ?? '',
      currentShelfQuantity: map['currentShelfQuantity'] as int? ?? 0,
      minimumQuantity: map['minimumQuantity'] as int? ?? 10,
      alertDate: _parseDate(map['alertDate']) ?? DateTime.now(),
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is Timestamp) return val.toDate();
    try {
      return DateTime.tryParse(val.toString());
    } catch (e, stack) { LoggingService().error('Silent error caught', e, stack); }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'branchId': branchId,
      'shelfId': shelfId,
      'shelfName': shelfName,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'currentShelfQuantity': currentShelfQuantity,
      'minimumQuantity': minimumQuantity,
      'alertDate': alertDate,
      'status': status,
      'notes': notes,
    };
  }

  bool get needsRefill => currentShelfQuantity < minimumQuantity;
}
