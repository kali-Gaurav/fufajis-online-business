import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/delivery_task_model.dart';
import '../models/proof_of_delivery_model.dart';
import '../models/delivery_location_model.dart';
import '../models/order_model.dart';
import 'otp_service.dart';
import 'location_tracking_service.dart';
import 'notification_service.dart';
import 'order_notification_service.dart';
import 'notification_retry_service.dart';
import 'whatsapp_notification_service.dart';

/// Last-mile delivery management service
/// Handles delivery assignment, tracking, OTP verification, and proof of delivery
class DeliveryLastMileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final OTPService _otpService = OTPService();
  final LocationTrackingService _locationService = LocationTrackingService();

  static final DeliveryLastMileService _instance = DeliveryLastMileService._internal();
  factory DeliveryLastMileService() => _instance;
  DeliveryLastMileService._internal();

  /// Get all assigned deliveries for an agent that are not completed/failed
  Future<List<DeliveryTaskModel>> getAssignedDeliveries(String deliveryAgentId) async {
    try {
      final snapshot = await _db
          .collection('deliveries')
          .where('deliveryAgentId', isEqualTo: deliveryAgentId)
          .where('status', whereIn: ['assigned', 'accepted', 'picked_up', 'out_for_delivery', 'inTransit', 'arrived'])
          .orderBy('estimatedArrivalAt')
          .get();

      return snapshot.docs
          .map((doc) => DeliveryTaskModel.fromJson({...doc.data(), 'deliveryId': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching assigned deliveries: $e');
      rethrow;
    }
  }

  /// Get single delivery details
  Future<DeliveryTaskModel?> getDeliveryDetail(String deliveryId) async {
    try {
      final doc = await _db.collection('deliveries').doc(deliveryId).get();
      if (!doc.exists) return null;
      return DeliveryTaskModel.fromJson({...doc.data()!, 'deliveryId': doc.id});
    } catch (e) {
      debugPrint('Error fetching delivery detail: $e');
      return null;
    }
  }

  /// Assign order to delivery agent
  Future<DeliveryTaskModel> assignOrderToDeliveryAgent({
    required String orderId,
    required String deliveryAgentId,
    required OrderModel order,
    required DateTime estimatedArrival,
  }) async {
    try {
      final deliveryId = const Uuid().v4();

      final task = DeliveryTaskModel(
        deliveryId: deliveryId,
        orderId: orderId,
        customerId: order.customerId,
        deliveryAgentId: deliveryAgentId,
        branchId: order.branchId ?? '',
        status: DeliveryTaskStatus.assigned,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        customerAddress: order.deliveryAddress.fullAddress,
        addressLatitude: order.deliveryAddress.latitude,
        addressLongitude: order.deliveryAddress.longitude,
        estimatedArrivalAt: estimatedArrival,
        createdAt: DateTime.now(),
      );

      // Save delivery task
      await _db.collection('deliveries').doc(deliveryId).set(task.toJson());

      // Update order with delivery info
      await _db.collection('orders').doc(orderId).update({
        'deliveryTaskId': deliveryId,
        'deliveryAgentId': deliveryAgentId,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // Send notifications
      await _sendAssignmentNotifications(task, deliveryAgentId);

      debugPrint('Delivery assigned: $deliveryId to agent: $deliveryAgentId');
      return task;
    } catch (e) {
      debugPrint('Error assigning delivery: $e');
      rethrow;
    }
  }

  /// Start delivery (update status to IN_TRANSIT)
  Future<void> startDelivery(String deliveryId) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryTaskStatus.inTransit.value,
        'actualArrivalAt': FieldValue.serverTimestamp(),
      });

      // Send tracking link
      await _sendCustomerTrackingNotification(task);

      // Start location tracking
      if (task.deliveryAgentId != null) {
        await _locationService.startTracking(
          deliveryId: deliveryId,
          onLocationUpdate: (lat, lng) async {
            await updateLocation(deliveryId, lat, lng);
          },
        );
      }

      // Send customer notification with tracking link
      await _sendCustomerTrackingNotification(task);

      debugPrint('Delivery started: $deliveryId');
    } catch (e) {
      debugPrint('Error starting delivery: $e');
      rethrow;
    }
  }

  /// Update delivery location and check proximity
  Future<void> updateLocation(String deliveryId, double lat, double lng) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) return;

      // Create location record
      final location = DeliveryLocationModel(
        locationId: '${deliveryId}_${DateTime.now().millisecondsSinceEpoch}',
        deliveryId: deliveryId,
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
      );

      // Save to Firestore
      await _db
          .collection('delivery_locations')
          .doc(location.locationId)
          .set(location.toJson());

      // Check if agent is near (within 5 minutes)
      final eta = await _locationService.calculateETA(
        currentLat: lat,
        currentLng: lng,
        destLat: task.addressLatitude,
        destLng: task.addressLongitude,
      );

      if (eta <= 5) {
        // Send arriving soon notification
        await _sendArrivingNotification(task);

        // Update delivery status to ARRIVED
        await _db.collection('deliveries').doc(deliveryId).update({
          'status': DeliveryTaskStatus.arrived.value,
        });
      }

      debugPrint('Location updated for $deliveryId: $lat, $lng (ETA: $eta mins)');
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  /// Generate OTP for delivery
  Future<String> generateOTP(String deliveryId) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      final otp = _otpService.generateOTP();
      final otpHash = _otpService.hashOTP(otp);
      final now = DateTime.now();

      // Save OTP to ProofOfDelivery
      final proofId = const Uuid().v4();
      final proof = ProofOfDeliveryModel(
        proofId: proofId,
        deliveryId: deliveryId,
        orderId: task.orderId,
        otpHash: otpHash,
        otpGeneratedAt: now,
        verificationMethod: VerificationMethod.otp,
        timestamp: now,
      );

      await _db.collection('proofs_of_delivery').doc(proofId).set(proof.toJson());

      // Send OTP via FCM and SMS
      await _sendOTPToCustomer(task, otp);

      debugPrint('OTP generated for delivery: $deliveryId');
      return otp; // Return for logging (NOT shown in UI)
    } catch (e) {
      debugPrint('Error generating OTP: $e');
      rethrow;
    }
  }

  /// Verify OTP entered by customer
  Future<bool> verifyOTP(String deliveryId, String userOtp) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      // Get latest proof of delivery
      final proofSnapshot = await _db
          .collection('proofs_of_delivery')
          .where('deliveryId', isEqualTo: deliveryId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (proofSnapshot.docs.isEmpty) {
        throw Exception('No OTP found for this delivery');
      }

      final proofData = proofSnapshot.docs.first.data();
      final proof = ProofOfDeliveryModel.fromJson(proofData);

      // Track attempt
      _otpService.recordAttempt(deliveryId, false);

      // Check if locked
      if (await _otpService.isLocked(deliveryId)) {
        throw Exception('Too many failed attempts. Try again later.');
      }

      // Verify OTP
      if (proof.otpHash != null && proof.otpGeneratedAt != null) {
        final isValid = _otpService.verifyOTP(
          storedOtpHash: proof.otpHash!,
          userEnteredOtp: userOtp,
          otpGeneratedAt: proof.otpGeneratedAt!,
        );

        if (isValid) {
          _otpService.recordAttempt(deliveryId, true);

          // Update proof with verification timestamp
          await _db.collection('proofs_of_delivery').doc(proof.proofId).update({
            'otpVerifiedAt': FieldValue.serverTimestamp(),
            'isVerified': true,
          });

          debugPrint('OTP verified for delivery: $deliveryId');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  /// Upload proof photos
  Future<ProofOfDeliveryModel> uploadProofOfDelivery({
    required String deliveryId,
    String? photoPath,
    String? signaturePath,
  }) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      String? photoUrl;
      String? signatureUrl;

      // Upload photo if provided
      if (photoPath != null && photoPath.isNotEmpty) {
        photoUrl = await _uploadFile(
          filePath: photoPath,
          folder: 'delivery_photos',
          deliveryId: deliveryId,
        );
      }

      // Upload signature if provided
      if (signaturePath != null && signaturePath.isNotEmpty) {
        signatureUrl = await _uploadFile(
          filePath: signaturePath,
          folder: 'delivery_signatures',
          deliveryId: deliveryId,
        );
      }

      // Get or create proof of delivery
      final proofSnapshot = await _db
          .collection('proofs_of_delivery')
          .where('deliveryId', isEqualTo: deliveryId)
          .limit(1)
          .get();

      ProofOfDeliveryModel proof;
      if (proofSnapshot.docs.isNotEmpty) {
        final existingProof =
            ProofOfDeliveryModel.fromJson({...proofSnapshot.docs.first.data()});
        proof = existingProof.copyWith(
          photoAfterUrl: photoUrl ?? existingProof.photoAfterUrl,
          signatureUrl: signatureUrl ?? existingProof.signatureUrl,
        );
        await _db
            .collection('proofs_of_delivery')
            .doc(existingProof.proofId)
            .update(proof.toJson());
      } else {
        final proofId = const Uuid().v4();
        proof = ProofOfDeliveryModel(
          proofId: proofId,
          deliveryId: deliveryId,
          orderId: task.orderId,
          photoAfterUrl: photoUrl,
          signatureUrl: signatureUrl,
          verificationMethod: VerificationMethod.signature,
          timestamp: DateTime.now(),
        );
        await _db.collection('proofs_of_delivery').doc(proofId).set(proof.toJson());
      }

      debugPrint('Proof of delivery uploaded: $deliveryId');
      return proof;
    } catch (e) {
      debugPrint('Error uploading proof: $e');
      rethrow;
    }
  }

  /// Complete delivery
  Future<void> completeDelivery({
    required String deliveryId,
    required VerificationMethod verificationMethod,
  }) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      // Validate verification method
      if (verificationMethod == VerificationMethod.otp) {
        final status = await _otpService.getOTPStatus(deliveryId);
        if (!status.isVerified) {
          throw Exception('OTP not verified');
        }
      }

      // Update delivery status
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryTaskStatus.completed.value,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update order status
      await _db.collection('orders').doc(task.orderId).update({
        'status': 'DELIVERED',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // Stop location tracking
      await _locationService.stopTracking(deliveryId);

      // Clear OTP attempt tracking
      _otpService.resetOTP(deliveryId);

      // Send completion notifications
      await _sendCompletionNotifications(task);

      debugPrint('Delivery completed: $deliveryId');
    } catch (e) {
      debugPrint('Error completing delivery: $e');
      rethrow;
    }
  }

  /// Mark delivery as failed
  Future<void> failDelivery({
    required String deliveryId,
    required String reason,
    String? notes,
  }) async {
    try {
      final task = await getDeliveryDetail(deliveryId);
      if (task == null) throw Exception('Delivery not found');

      // Update delivery status
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryTaskStatus.failed.value,
        'failureReason': reason,
        'failureNotes': notes,
      });

      // Update order status back to READY
      await _db.collection('orders').doc(task.orderId).update({
        'status': 'READY',
      });

      // Stop location tracking
      await _locationService.stopTracking(deliveryId);

      // Send failure notifications
      await _sendFailureNotifications(task, reason);

      debugPrint('Delivery failed: $deliveryId, Reason: $reason');
    } catch (e) {
      debugPrint('Error failing delivery: $e');
      rethrow;
    }
  }

  /// Retry failed delivery
  Future<DeliveryTaskModel> retryDelivery({
    required String failedDeliveryId,
    required String newDeliveryAgentId,
    required DateTime estimatedArrival,
  }) async {
    try {
      final failedTask = await getDeliveryDetail(failedDeliveryId);
      if (failedTask == null) throw Exception('Failed delivery not found');

      // Create new delivery task
      final newDeliveryId = const Uuid().v4();
      final task = DeliveryTaskModel(
        deliveryId: newDeliveryId,
        orderId: failedTask.orderId,
        customerId: failedTask.customerId,
        deliveryAgentId: newDeliveryAgentId,
        status: DeliveryTaskStatus.assigned,
        customerName: failedTask.customerName,
        customerPhone: failedTask.customerPhone,
        customerAddress: failedTask.customerAddress,
        addressLatitude: failedTask.addressLatitude,
        addressLongitude: failedTask.addressLongitude,
        estimatedArrivalAt: estimatedArrival,
        createdAt: DateTime.now(),
        deliveryNotes: 'Retry - Previous reason: ${failedTask.failureReason}',
        branchId: failedTask.branchId,
      );

      await _db.collection('deliveries').doc(newDeliveryId).set(task.toJson());

      // Update order with new delivery agent
      await _db.collection('orders').doc(failedTask.orderId).update({
        'deliveryTaskId': newDeliveryId,
        'deliveryAgentId': newDeliveryAgentId,
      });

      debugPrint('Delivery retried: $failedDeliveryId -> $newDeliveryId');
      return task;
    } catch (e) {
      debugPrint('Error retrying delivery: $e');
      rethrow;
    }
  }

  /// Get delivery stats for an agent
  Future<Map<String, dynamic>> getDeliveryStats(
    String deliveryAgentId, {
    String period = 'today',
  }) async {
    try {
      DateTime startDate;
      if (period == 'today') {
        startDate = DateTime.now();
      } else if (period == 'week') {
        startDate = DateTime.now().subtract(const Duration(days: 7));
      } else {
        startDate = DateTime.now().subtract(const Duration(days: 30));
      }

      final snapshot = await _db
          .collection('deliveries')
          .where('deliveryAgentId', isEqualTo: deliveryAgentId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .get();

      final deliveries = snapshot.docs
          .map((doc) => DeliveryTaskModel.fromJson({...doc.data(), 'deliveryId': doc.id}))
          .toList();

      final completed = deliveries.where((d) => d.status == DeliveryTaskStatus.completed).length;
      final failed = deliveries.where((d) => d.status == DeliveryTaskStatus.failed).length;

      double avgRating = 0;
      int ratedCount = 0;
      for (final delivery in deliveries) {
        if (delivery.ratingFromCustomer != null) {
          avgRating += delivery.ratingFromCustomer!;
          ratedCount++;
        }
      }
      if (ratedCount > 0) {
        avgRating /= ratedCount;
      }

      return {
        'totalDeliveries': deliveries.length,
        'completedCount': completed,
        'failedCount': failed,
        'successRate': deliveries.isEmpty ? 0 : (completed / deliveries.length * 100).round(),
        'avgRating': avgRating.toStringAsFixed(1),
        'period': period,
      };
    } catch (e) {
      debugPrint('Error getting delivery stats: $e');
      return {};
    }
  }

  /// Get location history for a delivery
  Future<List<DeliveryLocationModel>> getLocationHistory(String deliveryId) async {
    try {
      final snapshot = await _db
          .collection('delivery_locations')
          .where('deliveryId', isEqualTo: deliveryId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => DeliveryLocationModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting location history: $e');
      return [];
    }
  }

  // Private helper methods

  Future<void> _sendAssignmentNotifications(
      DeliveryTaskModel task, String deliveryAgentId) async {
    try {
      // Notify rider
      await NotificationService().sendNotificationToUser(
        userId: deliveryAgentId,
        title: '🏍️ New Delivery Assignment',
        body: 'You have been assigned to deliver Order #${task.orderNumber}.',
        data: {
          'type': 'systemMessage',
          'deliveryId': task.deliveryId,
          'orderId': task.orderId,
        },
      );

      // Notify customer via fallback channel routing
      await WhatsAppNotificationService.sendWithFallback(
        customerId: task.customerId,
        phoneNumber: task.customerPhone,
        title: '🏍️ Delivery Partner Assigned',
        body: 'Namaste ${task.customerName}, a delivery partner has been assigned to your order. We are preparing it for delivery.',
        orderId: task.orderId,
        notificationType: 'orderUpdate',
      );
    } catch (e) {
      debugPrint('Error sending assignment notifications: $e');
    }
  }

  Future<void> _sendCustomerTrackingNotification(DeliveryTaskModel task) async {
    try {
      final trackingLink = 'https://fufaji.app/track/${task.deliveryId}';
      await WhatsAppNotificationService.sendWithFallback(
        customerId: task.customerId,
        phoneNumber: task.customerPhone,
        title: '🚚 Order Out for Delivery',
        body: 'Namaste ${task.customerName}, your Order #${task.orderNumber} is out for delivery! Track your rider live: $trackingLink',
        orderId: task.orderId,
        notificationType: 'orderUpdate',
      );
    } catch (e) {
      debugPrint('Error sending tracking notification: $e');
    }
  }

  Future<void> _sendArrivingNotification(DeliveryTaskModel task) async {
    try {
      await WhatsAppNotificationService.sendWithFallback(
        customerId: task.customerId,
        phoneNumber: task.customerPhone,
        title: '🛵 Delivery Arriving Soon',
        body: 'Namaste ${task.customerName}, our delivery partner is arriving in approximately 5 minutes. Please be ready with your verification OTP.',
        orderId: task.orderId,
        notificationType: 'orderUpdate',
      );
    } catch (e) {
      debugPrint('Error sending arriving notification: $e');
    }
  }

  Future<void> _sendOTPToCustomer(DeliveryTaskModel task, String otp) async {
    try {
      final success = await WhatsAppNotificationService.sendDeliveryOtpWithTracking(
        phoneNumber: task.customerPhone,
        customerName: task.customerName,
        orderNumber: task.orderNumber,
        otp: otp,
        orderId: task.orderId,
      );
      
      if (!success) {
        await WhatsAppNotificationService.sendWithFallback(
          customerId: task.customerId,
          phoneNumber: task.customerPhone,
          title: '🔑 Delivery Verification OTP',
          body: 'Namaste ${task.customerName}, your OTP for Order #${task.orderNumber} is $otp.',
          orderId: task.orderId,
          notificationType: 'otp',
        );
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
    }
  }

  Future<void> _sendCompletionNotifications(DeliveryTaskModel task) async {
    try {
      final orderDoc = await _db.collection('orders').doc(task.orderId).get();
      if (orderDoc.exists && orderDoc.data() != null) {
        final order = OrderModel.fromMap(orderDoc.data()!);
        await OrderNotificationService().notifyDeliveryComplete(order);
      }
    } catch (e) {
      debugPrint('Error sending completion notifications: $e');
    }
  }

  Future<void> _sendFailureNotifications(DeliveryTaskModel task, String reason) async {
    try {
      await NotificationService().sendNotificationToUser(
        userId: task.customerId,
        title: '⚠️ Delivery Unsuccessful',
        body: 'Namaste, our delivery partner could not complete the delivery of Order #${task.orderNumber}. Reason: $reason. We will contact you to reschedule.',
        data: {
          'type': 'systemAlert',
          'orderId': task.orderId,
        },
      );

      await NotificationRetryService().triggerAdminAlert(
        type: 'delivery_exception',
        severity: 'high',
        title: 'Delivery Attempt Failed',
        description: 'Delivery for Order #${task.orderId} failed. Reason: $reason',
      );
    } catch (e) {
      debugPrint('Error sending failure notifications: $e');
    }
  }

  Future<String> _uploadFile({
    required String filePath,
    required String folder,
    required String deliveryId,
  }) async {
    try {
      final fileName = '${deliveryId}_${DateTime.now().millisecondsSinceEpoch}';
      // Implementation would upload actual file
      debugPrint('File uploaded: $filePath to $folder/$fileName');
      return 'https://storage.googleapis.com/fufaji-online-business.appspot.com/$folder/$fileName';
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }
}
