import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../models/scanner_models.dart';
import '../models/product_batch_model.dart';
import 'offline_sync_service.dart';
import 'whatsapp_notification_service.dart';
import '../services/notification_service.dart';
import 'api_client.dart';

/// Service for employee operations - inventory receiving, packing, delivery, etc.
class EmployeeScannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _shopId;
  final String _branchId;
  final String _employeeId;
  final String _employeeName;

  EmployeeScannerService({
    required String shopId,
    required String branchId,
    required String employeeId,
    required String employeeName,
  }) : _shopId = shopId,
       _branchId = branchId,
       _employeeId = employeeId,
       _employeeName = employeeName;

  // ==================== INVENTORY RECEIVING ====================

  /// Receive new inventory
  Future<void> receiveInventory({
    required String productId,
    required String barcode,
    required int quantity,
    String? notes,
    String? batchNumber,
    DateTime? expiryDate,
    String? supplier,
    double? costPrice,
  }) async {
    final String actualBatchId = batchNumber ?? 'BATCH-${const Uuid().v4()}';
    final bool isOffline = !OfflineSyncService().isOnline.value;
    if (isOffline) {
      final newBatch = ProductBatch(
        batchId: actualBatchId,
        productId: productId,
        quantity: quantity,
        expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
        receivedDate: DateTime.now(),
        costPrice: costPrice ?? 0.0,
        branchId: _branchId,
      );
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'receive',
        shopId: _shopId,
        branchId: _branchId,
        documentId: actualBatchId,
        data: {
          ...newBatch.toMap(),
          'barcode': barcode,
          'notes': notes,
          'supplier': supplier,
        },
      );
      return;
    }

    final productRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('products')
        .doc(productId);

    final batch = _firestore.batch();

    // Update product stock
    batch.update(productRef, {
      'stockQuantity': FieldValue.increment(quantity),
      'updatedAt': DateTime.now(),
    });

    // Create audit log
    final auditId = const Uuid().v4();
    final auditRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_audit_logs')
        .doc(auditId);

    batch.set(auditRef, {
      'id': auditId,
      'type': 'receive',
      'productId': productId,
      'barcode': barcode,
      'quantity': quantity,
      'employeeId': _employeeId,
      'employeeName': _employeeName,
      'notes': notes,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'supplier': supplier,
      'costPrice': costPrice,
      'createdAt': DateTime.now(),
    });

    // Create/update product batch document
    final batchRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_batches')
        .doc(actualBatchId);

    final newBatch = ProductBatch(
      batchId: actualBatchId,
      productId: productId,
      quantity: quantity,
      expiryDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      receivedDate: DateTime.now(),
      costPrice: costPrice ?? 0.0,
      branchId: _branchId,
    );

    batch.set(batchRef, newBatch.toMap(), SetOptions(merge: true));

    await batch.commit();
  }

  // ==================== ORDER PACKING ====================

  /// Get pending orders for packing
  Stream<QuerySnapshot> getPendingOrders() {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: _branchId)
        .where('status', whereIn: ['OrderStatus.confirmed', 'OrderStatus.processing', 'OrderStatus.packed'])
        .snapshots();
  }

  /// Start order packing
  Future<void> startPacking(String orderId) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    bool shouldNotify = false;
    String customerId = '';
    String orderNumber = '';

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw Exception('Order not found');

      final orderData = snapshot.data()!;
      String currentPackingStatus = orderData['packingStatus']?.toString() ?? 'not_started';
      String currentStatus = orderData['status']?.toString() ?? 'OrderStatus.pending';

      final updates = <String, dynamic>{};

      if (currentStatus == 'OrderStatus.confirmed') {
        updates['status'] = 'OrderStatus.processing';
        final List<dynamic> statusHistory = orderData['statusHistory'] as List<dynamic>? ?? [];
        updates['statusHistory'] = List<dynamic>.from(statusHistory)
          ..add({
            'status': 'OrderStatus.processing',
            'timestamp': Timestamp.now(),
            'note': 'Order processing started (packing).',
          });

        shouldNotify = true;
        customerId = orderData['customerId']?.toString() ?? '';
        orderNumber = orderData['orderNumber']?.toString() ?? '';
      }

      if (currentPackingStatus != 'packing') {
        final List<dynamic> historyList = orderData['packingHistory'] as List<dynamic>? ?? [];
        final updatedHistory = List<dynamic>.from(historyList)
          ..add({
            'timestamp': Timestamp.now(),
            'status': 'packing',
            'actorId': _employeeId,
            'actorName': _employeeName,
            'note': 'Packing started by employee.',
          });

        updates['packingStatus'] = 'packing';
        updates['packerId'] = _employeeId;
        updates['packerName'] = _employeeName;
        updates['packingStartedAt'] = FieldValue.serverTimestamp();
        updates['packingHistory'] = updatedHistory;
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        transaction.update(orderRef, updates);
      }
    });

    if (shouldNotify && customerId.isNotEmpty) {
      NotificationService().sendNotificationToUser(
        userId: customerId,
        title: 'Order Processing',
        body: 'Your order #$orderNumber is now being packed!',
        data: {'type': 'orderUpdate', 'orderId': orderId},
      );
    }
  }

  /// Verify item during packing
  Future<void> verifyPackingItem({
    required String orderId,
    required String productId,
    required int quantity,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) throw Exception('Order not found');

      final orderData = snapshot.data()!;
      final List<dynamic> itemsList = orderData['items'] as List<dynamic>? ?? [];

      final updatedItems = itemsList.map((itemMap) {
        final map = Map<String, dynamic>.from(itemMap as Map);
        if (map['productId'] == productId) {
          map['isPacked'] = true;
          map['packedBy'] = _employeeId;
          map['packedAt'] = Timestamp.now();
        }
        return map;
      }).toList();

      // Ensure packingStatus is set to 'packing' if not already
      String currentPackingStatus = orderData['packingStatus']?.toString() ?? 'not_started';
      final updates = <String, dynamic>{
        'items': updatedItems,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (currentPackingStatus != 'packing') {
        updates['packingStatus'] = 'packing';
        updates['packerId'] = _employeeId;
        updates['packerName'] = _employeeName;
        updates['packingStartedAt'] = FieldValue.serverTimestamp();

        final List<dynamic> historyList = orderData['packingHistory'] as List<dynamic>? ?? [];
        updates['packingHistory'] = List<dynamic>.from(historyList)
          ..add({
            'timestamp': Timestamp.now(),
            'status': 'packing',
            'actorId': _employeeId,
            'actorName': _employeeName,
            'note': 'Packing started by employee.',
          });
      }

      transaction.update(orderRef, updates);
    });
  }

  /// Complete order packing (Now using Automated Backend Workflow)
  Future<void> completePacking({
    required String orderId,
    required List<String> verifiedItems,
    String? photoUrl,
  }) async {
    // Ported to automated backend operation
    final response = await ApiClient.instance.post('/operations/checkout-order', {
      'orderId': orderId,
      'photoUrl': photoUrl,
      'verifiedItems': verifiedItems,
    });

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Backend checkout failed');
    }
  }

  // ==================== DELIVERY ====================

  /// Assign delivery to employee
  Future<void> assignDelivery({
    required String orderId,
    required String parcelId,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await orderRef.get();
    
    await orderRef.update({
      'status': 'OrderStatus.outForDelivery',
      'deliveryEmployeeId': _employeeId,
      'deliveryEmployeeName': _employeeName,
      'assignedAt': DateTime.now(),
    });

    if (snapshot.exists) {
      final data = snapshot.data()!;
      final customerId = data['customerId']?.toString() ?? '';
      final orderNumber = data['orderNumber']?.toString() ?? orderId;
      final otp = data['otp']?.toString() ?? 'N/A';
      
      if (customerId.isNotEmpty) {
        NotificationService().sendNotificationToUser(
          userId: customerId,
          title: 'Out for Delivery 🚚',
          body: 'Order #$orderNumber is on the way! Your delivery OTP is $otp. Rider: $_employeeName.',
          data: {'type': 'orderUpdate', 'orderId': orderId},
        );
      }
    }
  }

  /// Get assigned deliveries
  Stream<QuerySnapshot> getAssignedDeliveries() {
    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: _branchId)
        .where('deliveryEmployeeId', isEqualTo: _employeeId)
        .where('status', whereIn: ['OrderStatus.outForDelivery'])
        .snapshots();
  }

  /// Verify delivery with OTP
  Future<void> verifyDelivery({
    required String orderId,
    required String parcelId,
    required String customerOtp,
    LocationData? location,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final snapshot = await orderRef.get();

    await orderRef.update({
      'status': 'OrderStatus.delivered',
      'deliveredAt': DateTime.now(),
      'deliveryVerification': {
        'otp': customerOtp,
        'verifiedBy': _employeeId,
        'location': location?.toMap(),
      },
    });

    if (snapshot.exists) {
      final data = snapshot.data()!;
      final customerId = data['customerId']?.toString() ?? '';
      final orderNumber = data['orderNumber']?.toString() ?? orderId;
      
      if (customerId.isNotEmpty) {
        NotificationService().sendNotificationToUser(
          userId: customerId,
          title: 'Order Delivered 🎉',
          body: 'Order #$orderNumber has been delivered. Thank you for shopping with us!',
          data: {'type': 'orderUpdate', 'orderId': orderId},
        );
      }
    }
  }

  // ==================== INVENTORY AUDIT ====================

  /// Create inventory audit record
  Future<String> createAuditRecord({
    required String productId,
    required String productName,
    required String barcode,
    required int expectedStock,
    required int actualStock,
    String? notes,
  }) async {
    final auditId = const Uuid().v4();
    final bool isOffline = !OfflineSyncService().isOnline.value;
    if (isOffline) {
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'audit',
        shopId: _shopId,
        branchId: _branchId,
        documentId: auditId,
        data: {
          'id': auditId,
          'shopId': _shopId,
          'branchId': _branchId,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'expectedStock': expectedStock,
          'actualStock': actualStock,
          'difference': actualStock - expectedStock,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'auditDate': DateTime.now(),
          'notes': notes,
          'status': 'pending',
        },
      );
      return auditId;
    }

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_audits')
        .doc(auditId)
        .set({
          'id': auditId,
          'shopId': _shopId,
          'branchId': _branchId,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'expectedStock': expectedStock,
          'actualStock': actualStock,
          'difference': actualStock - expectedStock,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'auditDate': DateTime.now(),
          'notes': notes,
          'status': 'pending',
        });

    return auditId;
  }

  /// Get audit history
  Stream<QuerySnapshot> getAuditHistory() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_audits')
        .orderBy('auditDate', descending: true)
        .snapshots();
  }

  // ==================== DAMAGE REPORTING ====================

  /// Report damaged product
  Future<void> reportDamage({
    required String productId,
    required String productName,
    required String barcode,
    required int quantity,
    required DamageType damageType,
    String? reason,
  }) async {
    final reportId = const Uuid().v4();
    final bool isOffline = !OfflineSyncService().isOnline.value;
    if (isOffline) {
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'damage',
        shopId: _shopId,
        branchId: _branchId,
        documentId: reportId,
        data: {
          'id': reportId,
          'shopId': _shopId,
          'branchId': _branchId,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'quantity': quantity,
          'damageType': damageType.name,
          'reason': reason,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'reportDate': DateTime.now(),
          'status': 'pending',
        },
      );
      return;
    }

    final batch = _firestore.batch();

    // Create damage report
    final reportRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('damage_reports')
        .doc(reportId);

    batch.set(reportRef, {
      'id': reportId,
      'shopId': _shopId,
      'branchId': _branchId,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'quantity': quantity,
      'damageType': damageType.name,
      'reason': reason,
      'employeeId': _employeeId,
      'employeeName': _employeeName,
      'reportDate': DateTime.now(),
      'status': 'pending',
    });

    // Reduce stock
    final productRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('products')
        .doc(productId);

    batch.update(productRef, {
      'stockQuantity': FieldValue.increment(-quantity),
      'updatedAt': DateTime.now(),
    });

    await batch.commit();

    // Option A: Check for auto-generating supplier return request (within 7 days return window)
    try {
      final recentLogs = await _firestore
          .collection('shops')
          .doc(_shopId)
          .collection('branches')
          .doc(_branchId)
          .collection('inventory_audit_logs')
          .where('type', isEqualTo: 'receive')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (recentLogs.docs.isNotEmpty) {
        final logDoc = recentLogs.docs.first;
        final logData = logDoc.data();
        final timestamp = logData['createdAt'] != null
            ? (logData['createdAt'] is Timestamp
                  ? (logData['createdAt'] as Timestamp).toDate()
                  : DateTime.tryParse(logData['createdAt'].toString()))
            : null;

        if (timestamp != null) {
          final difference = DateTime.now().difference(timestamp);
          if (difference.inDays <= 7) {
            final supplier = logData['supplier'] as String?;
            if (supplier != null && supplier.isNotEmpty) {
              final returnId = const Uuid().v4();
              await _firestore
                  .collection('shops')
                  .doc(_shopId)
                  .collection('branches')
                  .doc(_branchId)
                  .collection('supplier_returns')
                  .doc(returnId)
                  .set({
                    'id': returnId,
                    'shopId': _shopId,
                    'branchId': _branchId,
                    'productId': productId,
                    'productName': productName,
                    'barcode': barcode,
                    'quantity': quantity,
                    'supplier': supplier,
                    'damageReportId': reportId,
                    'damageType': damageType.name,
                    'status': 'pending_credit',
                    'createdAt': DateTime.now(),
                  });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error auto-generating supplier return request: $e');
    }
  }

  // ==================== ATTENDANCE ====================

  /// Check in for work
  Future<String> checkIn({
    required String qrCodeId,
    LocationData? location,
  }) async {
    final today = DateTime.now();
    final attendanceId = const Uuid().v4();
    final bool isOffline = !OfflineSyncService().isOnline.value;

    double distance = 0.0;
    bool isHighGpsVariance = false;
    double? accuracy = location?.accuracy;

    try {
      final branchDoc = await _firestore
          .collection('shops')
          .doc(_shopId)
          .collection('branches')
          .doc(_branchId)
          .get();
      if (branchDoc.exists && location != null) {
        final branchLat = ((branchDoc.data()?['latitude'] as num?) ?? 0.0).toDouble();
        final branchLng = ((branchDoc.data()?['longitude'] as num?) ?? 0.0).toDouble();
        if (branchLat != 0.0 && branchLng != 0.0) {
          distance = Geolocator.distanceBetween(
            location.latitude,
            location.longitude,
            branchLat,
            branchLng,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching branch coordinates for check-in: $e');
    }

    if (accuracy != null && accuracy > 100.0) {
      isHighGpsVariance = true;
    }

    if (isOffline) {
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'attendance',
        shopId: _shopId,
        branchId: _branchId,
        documentId: attendanceId,
        data: {
          'id': attendanceId,
          'shopId': _shopId,
          'branchId': _branchId,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'date': today,
          'checkInTime': DateTime.now(),
          'checkInLocation': location?.toMap(),
          'qrCodeId': qrCodeId,
          'status': 'present',
          'isHighGpsVariance': isHighGpsVariance,
          'gpsAccuracy': accuracy,
          'gpsDistanceMeters': distance,
        },
      );
      if (isHighGpsVariance) {
        _notifyManagerGpsVariance(accuracy ?? 0.0, distance);
      }
      return attendanceId;
    }

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('attendance')
        .doc(attendanceId)
        .set({
          'id': attendanceId,
          'shopId': _shopId,
          'branchId': _branchId,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'date': today,
          'checkInTime': DateTime.now(),
          'checkInLocation': location?.toMap(),
          'qrCodeId': qrCodeId,
          'status': 'present',
          'isHighGpsVariance': isHighGpsVariance,
          'gpsAccuracy': accuracy,
          'gpsDistanceMeters': distance,
        });

    if (isHighGpsVariance) {
      await _notifyManagerGpsVariance(accuracy ?? 0.0, distance);
    }

    return attendanceId;
  }

  Future<void> _notifyManagerGpsVariance(
    double accuracy,
    double distance,
  ) async {
    try {
      final branchSnapshot = await _firestore
          .collection('shops')
          .doc(_shopId)
          .collection('branches')
          .doc(_branchId)
          .get();

      String targetPhone = '';
      String targetName = '';

      if (branchSnapshot.exists) {
        final branchData = branchSnapshot.data();
        if (branchData != null) {
          final managerId = branchData['managerId'] as String?;
          final assistantManagerId =
              branchData['assistantManagerId'] as String?;
          final contactPhone = branchData['contactPhone'] as String?;
          final escalationPhone = branchData['escalationPhone'] as String?;

          // 1. Fetch Manager
          if (managerId != null && managerId.isNotEmpty) {
            final managerDoc = await _firestore
                .collection('users')
                .doc(managerId)
                .get();
            if (managerDoc.exists) {
              targetPhone = managerDoc.data()?['phoneNumber'] as String? ?? '';
              targetName = managerDoc.data()?['name'] as String? ?? 'Manager';
            }
          }

          // 2. Fetch Assistant Manager
          if (targetPhone.isEmpty &&
              assistantManagerId != null &&
              assistantManagerId.isNotEmpty) {
            final assistantDoc = await _firestore
                .collection('users')
                .doc(assistantManagerId)
                .get();
            if (assistantDoc.exists) {
              targetPhone = assistantDoc.data()?['phoneNumber'] as String? ?? '';
              targetName = assistantDoc.data()?['name'] as String? ?? 'Assistant Manager';
            }
          }

          // 3. Fallback to Branch Contact Phone
          if (targetPhone.isEmpty &&
              contactPhone != null &&
              contactPhone.isNotEmpty) {
            targetPhone = contactPhone;
            targetName = branchData['branchName'] as String? ?? 'Branch Manager';
          }

          // 4. Fallback to Escalation Phone
          if (targetPhone.isEmpty &&
              escalationPhone != null &&
              escalationPhone.isNotEmpty) {
            targetPhone = escalationPhone;
            targetName = 'Operations Escalation Desk';
          }
        }
      }

      if (targetPhone.isEmpty) {
        targetPhone = const String.fromEnvironment(
          'WHATSAPP_OPERATIONS_PHONE',
          defaultValue: '919876543210',
        );
        targetName = 'Global Operations Support';
      }

      if (targetPhone.isNotEmpty) {
        await WhatsAppNotificationService.sendGpsVarianceAlert(
          phoneNumber: targetPhone,
          managerName: targetName,
          employeeName: _employeeName,
          accuracy: accuracy,
          distance: distance,
        );
      }
    } catch (e) {
      debugPrint('Failed to send GPS variance manager alert: $e');
    }
  }

  /// Check out from work
  Future<void> checkOut({
    required String attendanceId,
    LocationData? location,
  }) async {
    final attendanceRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('attendance')
        .doc(attendanceId);

    final doc = await attendanceRef.get();
    final data = doc.data()!;

    final checkInTime = data['checkInTime'] as DateTime;
    final checkOutTime = DateTime.now();
    final workingHours = checkOutTime.difference(checkInTime).inMinutes / 60.0;

    await attendanceRef.update({
      'checkOutTime': checkOutTime,
      'checkOutLocation': location?.toMap(),
      'workingHours': workingHours,
    });
  }

  /// Get today's attendance
  Future<DocumentSnapshot?> getTodayAttendance() async {
    final today = DateTime.now();

    final snapshot = await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('attendance')
        .where('employeeId', isEqualTo: _employeeId)
        .where(
          'date',
          isGreaterThanOrEqualTo: DateTime(today.year, today.month, today.day),
        )
        .limit(1)
        .get();

    return snapshot.docs.firstOrNull?.reference.get();
  }

  // ==================== CASH COLLECTION ====================

  /// Record cash collection
  Future<void> recordCashCollection({
    required String orderId,
    required double amount, String? notes,
  }) async {
    final collectionId = const Uuid().v4();

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('cash_collections')
        .doc(collectionId)
        .set({
          'id': collectionId,
          'shopId': _shopId,
          'branchId': _branchId,
          'orderId': orderId,
          'deliveryEmployeeId': _employeeId,
          'deliveryEmployeeName': _employeeName,
          'amount': amount,
          'collectionTime': DateTime.now(),
          'notes': notes,
          'status': 'collected',
        });

    // Update order
    await _firestore
        .collection('orders')
        .doc(orderId)
        .update({
          'paymentStatus': 'cod_collected',
          'codCollectedBy': _employeeId,
          'codCollectedAt': DateTime.now(),
        });
  }

  // ==================== RETURNS ====================

  /// Process return (Now using Automated Backend Workflow)
  Future<void> processReturn({
    required String orderId,
    required String productId,
    required String productName,
    required String barcode,
    required int quantity,
    required ReturnCondition condition,
    String? reason,
  }) async {
    // Ported to automated backend operation
    final response = await ApiClient.instance.post('/operations/checkin-order', {
      'orderId': orderId,
      'productId': productId,
      'quantity': quantity,
      'reason': reason ?? 'Item returned: ${condition.name}',
      'condition': condition.name,
      'barcode': barcode,
    });

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Backend check-in failed');
    }
  }

  // ==================== INVENTORY TRANSFER ====================

  /// Request inventory transfer
  Future<String> requestTransfer({
    required String productId,
    required String productName,
    required String barcode,
    required int quantity,
    required String destinationBranchId,
    required String destinationBranchName,
    String? notes,
  }) async {
    final transferId = const Uuid().v4();
    final bool isOffline = !OfflineSyncService().isOnline.value;
    if (isOffline) {
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'transfer',
        shopId: _shopId,
        branchId: _branchId,
        documentId: transferId,
        data: {
          'id': transferId,
          'shopId': _shopId,
          'sourceBranchId': _branchId,
          'sourceBranchName': '',
          'destinationBranchId': destinationBranchId,
          'destinationBranchName': destinationBranchName,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'quantity': quantity,
          'status': 'pending',
          'requestedBy': _employeeId,
          'requestedByName': _employeeName,
          'requestedAt': DateTime.now(),
          'notes': notes,
        },
      );
      return transferId;
    }

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_transfers')
        .doc(transferId)
        .set({
          'id': transferId,
          'shopId': _shopId,
          'sourceBranchId': _branchId,
          'sourceBranchName': '', // Will be filled by backend
          'destinationBranchId': destinationBranchId,
          'destinationBranchName': destinationBranchName,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'quantity': quantity,
          'status': 'pending',
          'requestedBy': _employeeId,
          'requestedByName': _employeeName,
          'requestedAt': DateTime.now(),
          'notes': notes,
        });

    return transferId;
  }

  /// Receive inventory transfer
  Future<void> receiveTransfer({
    required String transferId,
    required String trackingNumber,
  }) async {
    // Authorization Check: Only Managers, Assistant Managers, Shop Owners, or Admins can receive transfers
    final userDoc = await _firestore.collection('users').doc(_employeeId).get();
    final branchDoc = await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .get();

    bool isAuthorized = false;
    if (userDoc.exists) {
      final userRoleStr = userDoc.data()?['role'] ?? '';
      if (userRoleStr == 'UserRole.owner' ||
          userRoleStr == 'UserRole.superAdmin') {
        isAuthorized = true;
      }
    }

    if (!isAuthorized && branchDoc.exists) {
      final managerId = branchDoc.data()?['managerId'] as String?;
      final assistantManagerId =
          branchDoc.data()?['assistantManagerId'] as String?;
      if (_employeeId == managerId || _employeeId == assistantManagerId) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      throw Exception(
        'Unauthorized: Only branch managers or assistant managers can sign off stock transfers.',
      );
    }

    final transferRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('inventory_transfers')
        .doc(transferId);

    final doc = await transferRef.get();
    final data = doc.data()!;

    final batch = _firestore.batch();

    // Update transfer status
    batch.update(transferRef, {
      'status': 'received',
      'receivedAt': DateTime.now(),
      'trackingNumber': trackingNumber,
    });

    // Add to stock
    final productRef = _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('products')
        .doc(data['productId'] as String);

    batch.update(productRef, {
      'stockQuantity': FieldValue.increment(data['quantity'] as num),
      'updatedAt': DateTime.now(),
    });

    await batch.commit();
  }

  // ==================== SHELF REFILL ====================

  /// Report shelf refill needed
  Future<void> reportShelfRefill({
    required String shelfId,
    required String shelfName,
    required String productId,
    required String productName,
    required String barcode,
    required int currentShelfQuantity,
    required int minimumQuantity,
    String? notes,
  }) async {
    final alertId = const Uuid().v4();

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('shelf_refill_alerts')
        .doc(alertId)
        .set({
          'id': alertId,
          'shopId': _shopId,
          'branchId': _branchId,
          'shelfId': shelfId,
          'shelfName': shelfName,
          'productId': productId,
          'productName': productName,
          'barcode': barcode,
          'currentShelfQuantity': currentShelfQuantity,
          'minimumQuantity': minimumQuantity,
          'alertDate': DateTime.now(),
          'status': 'pending',
          'notes': notes,
        });
  }

  /// Refill shelf from godown stock
  Future<void> refillShelf({
    required String productId,
    required String barcode,
    required int quantity,
    String? notes,
  }) async {
    final refillId = const Uuid().v4();
    final bool isOffline = !OfflineSyncService().isOnline.value;

    if (isOffline) {
      await OfflineSyncService().enqueueEmployeeAction(
        actionType: 'shelf_refill',
        shopId: _shopId,
        branchId: _branchId,
        documentId: refillId,
        data: {
          'id': refillId,
          'shopId': _shopId,
          'branchId': _branchId,
          'productId': productId,
          'barcode': barcode,
          'quantity': quantity,
          'employeeId': _employeeId,
          'employeeName': _employeeName,
          'timestamp': DateTime.now(),
          'notes': notes,
        },
      );
      return;
    }

    await _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('shelf_refills')
        .doc(refillId)
        .set({
      'id': refillId,
      'shopId': _shopId,
      'branchId': _branchId,
      'productId': productId,
      'barcode': barcode,
      'quantity': quantity,
      'employeeId': _employeeId,
      'employeeName': _employeeName,
      'timestamp': FieldValue.serverTimestamp(),
      'notes': notes,
    });
  }

  /// Get shelf refill alerts
  Stream<QuerySnapshot> getShelfRefillAlerts() {
    return _firestore
        .collection('shops')
        .doc(_shopId)
        .collection('branches')
        .doc(_branchId)
        .collection('shelf_refill_alerts')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }
}
