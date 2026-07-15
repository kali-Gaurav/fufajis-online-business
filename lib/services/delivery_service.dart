import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/delivery_model.dart';
import '../models/delivery_agent_model.dart';
import '../models/order_model.dart';
import 'dart:math';

/// Service for delivery agent assignment and management
class DeliveryService {
  FirebaseFirestore _db = FirebaseFirestore.instance;

  @visibleForTesting
  set db(FirebaseFirestore firestore) => _db = firestore;

  static final DeliveryService _instance = DeliveryService._internal();
  factory DeliveryService() => _instance;
  DeliveryService._internal();

  /// Calculate distance using Haversine formula (more accurate than simple Pythagorean)
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371; // Earth radius in km
    final double dLat = (lat2 - lat1) * pi / 180;
    final double dLng = (lng2 - lng1) * pi / 180;

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }

  /// Find nearest available delivery agent by location
  Future<DeliveryAgent?> findNearestAvailableAgent({
    required double customerLat,
    required double customerLng,
    String? areaFilter,
  }) async {
    try {
      // Query available delivery agents
      var query = _db
          .collection('delivery_agents')
          .where('isAvailable', isEqualTo: true)
          .where('currentStatus', isEqualTo: 'active');

      // Optional area filter (e.g., district, zone)
      if (areaFilter != null && areaFilter.isNotEmpty) {
        query = query.where('area', isEqualTo: areaFilter);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        debugPrint('No available delivery agents found');
        return null;
      }

      DeliveryAgent? nearestAgent;
      double minDistance = double.infinity;

      // Find nearest agent by GPS distance
      for (var doc in snapshot.docs) {
        final agent = DeliveryAgent.fromMap(doc.data());
        final distance = calculateDistance(
          customerLat,
          customerLng,
          agent.currentLat,
          agent.currentLng,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearestAgent = agent;
        }
      }

      if (nearestAgent != null) {
        debugPrint(
          'Found nearest agent: ${nearestAgent.name} at ${minDistance.toStringAsFixed(2)} km',
        );
      }

      return nearestAgent;
    } catch (e) {
      debugPrint('Error finding nearest agent: $e');
      return null;
    }
  }

  /// Assign delivery order to nearest available agent
  Future<bool> assignDeliveryAgent(OrderModel order) async {
    try {
      // Validate order has delivery address
      final customerLat = order.deliveryAddress.latitude;
      final customerLng = order.deliveryAddress.longitude;

      if (customerLat == 0.0 || customerLng == 0.0) {
        throw Exception('Invalid delivery address coordinates');
      }

      // Find nearest available agent
      final nearestAgent = await findNearestAvailableAgent(
        customerLat: customerLat,
        customerLng: customerLng,
      );

      if (nearestAgent == null) {
        throw Exception('No available delivery agents');
      }

      // Assign order in a transaction to ensure atomicity
      await _db.runTransaction((transaction) async {
        // Get fresh agent data to check availability
        final agentDoc = await transaction.get(
          _db.collection('delivery_agents').doc(nearestAgent.id),
        );

        if (!agentDoc.exists) {
          throw Exception('Selected agent is no longer available');
        }

        final agentData = agentDoc.data()!;
        final isStillAvailable = agentData['isAvailable'] as bool? ?? false;

        if (!isStillAvailable) {
          throw Exception('Agent became unavailable during assignment');
        }

        // Update order with agent details
        final orderRef = _db.collection('orders').doc(order.id);
        final timestamp = FieldValue.serverTimestamp();

        transaction.update(orderRef, {
          'deliveryAgentId': nearestAgent.id,
          'deliveryAgentName': nearestAgent.name,
          'deliveryAgentPhone': nearestAgent.phone,
          'assignedAt': timestamp,
          'assignmentDistance': calculateDistance(
            customerLat,
            customerLng,
            nearestAgent.currentLat,
            nearestAgent.currentLng,
          ),
          'status': 'OrderStatus.outForDelivery',
        });

        // Log delivery assignment
        final logRef = _db
            .collection('delivery_assignments')
            .doc('${order.id}_${DateTime.now().millisecondsSinceEpoch}');

        transaction.set(logRef, {
          'orderId': order.id,
          'agentId': nearestAgent.id,
          'agentName': nearestAgent.name,
          'agentPhone': nearestAgent.phone,
          'customerLat': customerLat,
          'customerLng': customerLng,
          'agentLat': nearestAgent.currentLat,
          'agentLng': nearestAgent.currentLng,
          'distanceKm': calculateDistance(
            customerLat,
            customerLng,
            nearestAgent.currentLat,
            nearestAgent.currentLng,
          ),
          'assignedAt': timestamp,
          'status': 'assigned',
        });

        // Update agent: mark as unavailable if this is their only capacity
        // (Allow multiple orders per agent, but track current count)
        final currentOrderCount = (agentData['currentOrderCount'] as num?)?.toInt() ?? 0;
        const maxOrdersPerAgent = 3; // Maximum orders per agent

        transaction.update(_db.collection('delivery_agents').doc(nearestAgent.id), {
          'currentOrderId': order.id,
          'currentOrderCount': currentOrderCount + 1,
          'isAvailable': (currentOrderCount + 1) < maxOrdersPerAgent,
          'lastAssignedAt': timestamp,
        });
      });

      debugPrint('Successfully assigned order ${order.id} to agent ${nearestAgent.name}');
      return true;
    } catch (e) {
      debugPrint('Error assigning delivery agent: $e');
      rethrow;
    }
  }

  /// Update agent location
  Future<void> updateAgentLocation(String agentId, double latitude, double longitude) async {
    try {
      await _db.collection('delivery_agents').doc(agentId).update({
        'currentLat': latitude,
        'currentLng': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating agent location: $e');
    }
  }

  /// Mark agent as available
  Future<void> markAgentAvailable(String agentId) async {
    try {
      await _db.collection('delivery_agents').doc(agentId).update({
        'isAvailable': true,
        'currentStatus': 'active',
        'currentOrderId': null,
        'currentOrderCount': 0,
      });
    } catch (e) {
      debugPrint('Error marking agent available: $e');
    }
  }

  /// Mark agent as unavailable
  Future<void> markAgentUnavailable(String agentId) async {
    try {
      await _db.collection('delivery_agents').doc(agentId).update({'isAvailable': false});
    } catch (e) {
      debugPrint('Error marking agent unavailable: $e');
    }
  }

  /// Get delivery agent by ID
  Future<DeliveryAgent?> getAgent(String agentId) async {
    try {
      final doc = await _db.collection('delivery_agents').doc(agentId).get();
      if (!doc.exists) return null;
      return DeliveryAgent.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching agent: $e');
      return null;
    }
  }

  /// Stream of all available agents
  Stream<List<DeliveryAgent>> getAvailableAgentsStream() {
    return _db
        .collection('delivery_agents')
        .where('isAvailable', isEqualTo: true)
        .where('currentStatus', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => DeliveryAgent.fromMap(doc.data())).toList();
        });
  }

  /// Stream of agents with active deliveries
  Stream<List<DeliveryAgent>> getActiveAgentsStream() {
    return _db
        .collection('delivery_agents')
        .where('currentStatus', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => DeliveryAgent.fromMap(doc.data())).toList();
        });
  }

  /// Increment agent delivery count
  Future<void> incrementAgentDeliveryCount(String agentId) async {
    try {
      await _db.collection('delivery_agents').doc(agentId).update({
        'totalDeliveries': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing delivery count: $e');
    }
  }

  /// Update agent rating
  Future<void> updateAgentRating(String agentId, double newRating) async {
    try {
      await _db.collection('delivery_agents').doc(agentId).update({'rating': newRating});
    } catch (e) {
      debugPrint('Error updating agent rating: $e');
    }
  }

  /// Get delivery assignment history
  Stream<List<Map<String, dynamic>>> getAssignmentHistory(String? agentId) {
    var query = _db.collection('delivery_assignments').orderBy('assignedAt', descending: true);

    if (agentId != null && agentId.isNotEmpty) {
      query = query.where('agentId', isEqualTo: agentId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ==================== ENHANCED DELIVERY MANAGEMENT ====================

  /// Generate a 6-digit OTP
  String generateOTP() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Assign an order to a delivery agent with full details
  Future<String> assignOrderToDelivery(
    String orderId,
    String deliveryAgentId, {
    required String deliveryAgentName,
    required String deliveryAgentPhone,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required GeoPoint pickupLocation,
    required GeoPoint deliveryLocation,
    required DateTime estimatedDeliveryTime,
    String? shopId,
    String? shopName,
  }) async {
    try {
      final deliveryId = _db.collection('deliveries').doc().id;
      final otp = generateOTP();
      final now = DateTime.now();
      final otpExpiresAt = now.add(const Duration(minutes: 15));

      final deliveryTask = DeliveryTask(
        id: deliveryId,
        orderId: orderId,
        deliveryAgentId: deliveryAgentId,
        deliveryAgentName: deliveryAgentName,
        deliveryAgentPhone: deliveryAgentPhone,
        status: DeliveryStatus.assigned,
        pickupLocation: pickupLocation,
        deliveryLocation: deliveryLocation,
        deliveryAddress: deliveryAddress,
        customerName: customerName,
        customerPhone: customerPhone,
        estimatedDeliveryTime: estimatedDeliveryTime,
        otpGenerated: otp,
        otpGeneratedAt: now,
        otpExpiresAt: otpExpiresAt,
        createdAt: now,
        updatedAt: now,
        shopId: shopId,
        shopName: shopName,
      );

      await _db.collection('deliveries').doc(deliveryId).set(deliveryTask.toMap());

      // Create OTP record for verification
      await _db.collection('delivery_otp').doc(deliveryId).set({
        'otp': otp,
        'generatedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(otpExpiresAt),
        'verified': false,
        'attempts': 0,
      });

      return deliveryId;
    } catch (e) {
      throw Exception('Failed to assign delivery: $e');
    }
  }

  /// Get delivery task by ID
  Future<DeliveryTask?> getDeliveryById(String deliveryId) async {
    try {
      final doc = await _db.collection('deliveries').doc(deliveryId).get();
      if (doc.exists) {
        return DeliveryTask.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  /// Get deliveries for an agent on a specific date
  Future<List<DeliveryTask>> getAgentDeliveries(String agentId, {DateTime? date}) async {
    try {
      final queryDate = date ?? DateTime.now();
      final startOfDay = DateTime(queryDate.year, queryDate.month, queryDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final query = _db
          .collection('deliveries')
          .where('deliveryAgentId', isEqualTo: agentId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: false);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => DeliveryTask.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get agent deliveries: $e');
    }
  }

  /// Verify OTP for delivery
  Future<bool> verifyOTP(String deliveryId, String enteredOtp) async {
    try {
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      if (delivery.isOtpExpired) {
        throw Exception('OTP has expired');
      }

      if (delivery.otpAttempts >= 3) {
        throw Exception('Maximum OTP attempts exceeded');
      }

      if (delivery.otpGenerated != enteredOtp) {
        // Increment attempts
        await _db.collection('deliveries').doc(deliveryId).update({
          'otpAttempts': delivery.otpAttempts + 1,
        });
        throw Exception('Invalid OTP');
      }

      // OTP verified
      await _db.collection('deliveries').doc(deliveryId).update({
        'otpVerified': true,
        'otpAttempts': 0,
      });

      await _db.collection('delivery_otp').doc(deliveryId).update({'verified': true});

      return true;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  /// Start delivery (change status to outForDelivery)
  Future<void> startDelivery(String deliveryId) async {
    try {
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.outForDelivery.toString(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to start delivery: $e');
    }
  }

  /// Update delivery agent's live location
  Future<void> updateLocation(String deliveryId, double latitude, double longitude) async {
    try {
      await _db.collection('deliveries').doc(deliveryId).update({'updatedAt': Timestamp.now()});

      // Store location history for analytics
      await _db.collection('delivery_locations').add({
        'deliveryId': deliveryId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  /// Upload proof of delivery
  Future<void> uploadProofOfDelivery(
    String deliveryId, {
    required String photoUrl,
    String? signatureUrl,
    String? notes,
    String? customerName,
    String? customerSignature,
    required GeoPoint location,
  }) async {
    try {
      final now = DateTime.now();
      final proof = ProofOfDelivery(
        photoUrl: photoUrl,
        signatureUrl: signatureUrl,
        timestamp: now,
        location: location,
        notes: notes,
        customerName: customerName,
        customerSignature: customerSignature,
      );

      await _db.collection('deliveries').doc(deliveryId).update({'proofOfDelivery': proof.toMap()});
    } catch (e) {
      throw Exception('Failed to upload proof of delivery: $e');
    }
  }

  /// Complete delivery
  Future<void> completeDelivery(String deliveryId) async {
    try {
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      if (!delivery.otpVerified) {
        throw Exception('OTP must be verified before completing delivery');
      }

      if (delivery.proofOfDelivery == null) {
        throw Exception('Proof of delivery is required');
      }

      final now = DateTime.now();
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.delivered.toString(),
        'actualDeliveryTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Update daily stats
      await _updateDailyStats(
        delivery.deliveryAgentId,
        successful: true,
        isOnTime: now.isBefore(delivery.estimatedDeliveryTime),
      );
    } catch (e) {
      throw Exception('Failed to complete delivery: $e');
    }
  }

  /// Mark delivery as failed
  Future<void> failDelivery(String deliveryId, String reason) async {
    try {
      final delivery = await getDeliveryById(deliveryId);
      if (delivery == null) {
        throw Exception('Delivery not found');
      }

      final now = DateTime.now();
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.failed.toString(),
        'failureReason': reason,
        'updatedAt': Timestamp.fromDate(now),
      });

      // Update daily stats
      await _updateDailyStats(delivery.deliveryAgentId, successful: false);
    } catch (e) {
      throw Exception('Failed to mark delivery as failed: $e');
    }
  }

  /// Reschedule delivery
  Future<void> rescheduleDelivery(String deliveryId, DateTime newDeliveryDate) async {
    try {
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.rescheduled.toString(),
        'rescheduledDate': Timestamp.fromDate(newDeliveryDate),
        'isRescheduled': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to reschedule delivery: $e');
    }
  }

  /// Get delivery statistics for an agent
  Future<DeliveryStats> getDeliveryStats(String agentId, {DateTime? date}) async {
    try {
      final queryDate = date ?? DateTime.now();
      final dateStr =
          '${queryDate.year}-${queryDate.month.toString().padLeft(2, '0')}-${queryDate.day.toString().padLeft(2, '0')}';

      final doc = await _db.collection('agent_daily_stats').doc('${agentId}_$dateStr').get();

      if (doc.exists) {
        return DeliveryStats.fromMap(doc.data()!);
      }

      return DeliveryStats(agentId: agentId, date: dateStr);
    } catch (e) {
      throw Exception('Failed to get delivery stats: $e');
    }
  }

  /// Add customer rating for delivery
  Future<void> rateDelivery(String deliveryId, double rating, String? feedback) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      await _db.collection('deliveries').doc(deliveryId).update({
        'customerRating': rating,
        'customerFeedback': feedback,
        'updatedAt': Timestamp.now(),
      });

      // Update agent's average rating
      final delivery = await getDeliveryById(deliveryId);
      if (delivery != null) {
        await _updateAgentRating(delivery.deliveryAgentId, rating);
      }
    } catch (e) {
      throw Exception('Failed to rate delivery: $e');
    }
  }

  /// Cancel delivery
  Future<void> cancelDelivery(String deliveryId) async {
    try {
      await _db.collection('deliveries').doc(deliveryId).update({
        'status': DeliveryStatus.cancelled.toString(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to cancel delivery: $e');
    }
  }

  /// Stream of deliveries for an agent (real-time)
  Stream<List<DeliveryTask>> streamAgentDeliveries(String agentId) {
    final queryDate = DateTime.now();
    final startOfDay = DateTime(queryDate.year, queryDate.month, queryDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('deliveries')
        .where('deliveryAgentId', isEqualTo: agentId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => DeliveryTask.fromMap(doc.data())).toList());
  }

  /// Stream of a single delivery (real-time tracking)
  Stream<DeliveryTask?> streamDelivery(String deliveryId) {
    return _db
        .collection('deliveries')
        .doc(deliveryId)
        .snapshots()
        .map((snapshot) => snapshot.exists ? DeliveryTask.fromMap(snapshot.data()!) : null);
  }

  /// Helper: Update daily statistics
  Future<void> _updateDailyStats(
    String agentId, {
    required bool successful,
    bool isOnTime = false,
  }) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final statsId = '${agentId}_$dateStr';

      final statsDoc = await _db.collection('agent_daily_stats').doc(statsId).get();

      if (statsDoc.exists) {
        final stats = DeliveryStats.fromMap(statsDoc.data()!);
        final updatedStats = stats.copyWith(
          totalDeliveries: stats.totalDeliveries + 1,
          successfulDeliveries: successful
              ? stats.successfulDeliveries + 1
              : stats.successfulDeliveries,
          failedDeliveries: !successful ? stats.failedDeliveries + 1 : stats.failedDeliveries,
          onTimeDeliveries: isOnTime ? stats.onTimeDeliveries + 1 : stats.onTimeDeliveries,
          onTimePercentage:
              ((isOnTime ? stats.onTimeDeliveries + 1 : stats.onTimeDeliveries) /
              (stats.totalDeliveries + 1) *
              100),
        );
        await _db.collection('agent_daily_stats').doc(statsId).update(updatedStats.toMap());
      } else {
        final newStats = DeliveryStats(
          agentId: agentId,
          date: dateStr,
          totalDeliveries: 1,
          successfulDeliveries: successful ? 1 : 0,
          failedDeliveries: successful ? 0 : 1,
          onTimeDeliveries: isOnTime ? 1 : 0,
          onTimePercentage: isOnTime ? 100.0 : 0.0,
        );
        await _db.collection('agent_daily_stats').doc(statsId).set(newStats.toMap());
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Helper: Update agent's average rating
  Future<void> _updateAgentRating(String agentId, double newRating) async {
    try {
      final deliveriesSnapshot = await _db
          .collection('deliveries')
          .where('deliveryAgentId', isEqualTo: agentId)
          .where('customerRating', isGreaterThan: 0)
          .get();

      if (deliveriesSnapshot.docs.isNotEmpty) {
        double totalRating = 0;
        int count = 0;

        for (var doc in deliveriesSnapshot.docs) {
          final delivery = DeliveryTask.fromMap(doc.data());
          if (delivery.customerRating != null) {
            totalRating += delivery.customerRating!;
            count++;
          }
        }

        final averageRating = count > 0 ? totalRating / count : 0.0;

        await _db.collection('delivery_agents').doc(agentId).update({
          'averageRating': averageRating,
          'totalRatings': count,
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Submit comprehensive delivery feedback with multiple ratings and images
  Future<void> submitDeliveryFeedback({
    required String orderId,
    required String customerId,
    required String deliveryTaskId,
    required double deliverySpeedRating,
    required double riderBehaviorRating,
    required double packagingQualityRating,
    String? review,
    List<String>? photoUrls,
  }) async {
    try {
      final double overallRating = (deliverySpeedRating + riderBehaviorRating + packagingQualityRating) / 3;

      final feedbackData = {
        'order_id': orderId,
        'customer_id': customerId,
        'delivery_task_id': deliveryTaskId,
        'ratings': {
          'delivery_speed': deliverySpeedRating,
          'rider_behavior': riderBehaviorRating,
          'packaging_quality': packagingQualityRating,
          'overall': overallRating,
        },
        'review': review ?? '',
        'photo_urls': photoUrls ?? [],
        'has_images': (photoUrls ?? []).isNotEmpty,
        'image_count': (photoUrls ?? []).length,
        'submitted_at': Timestamp.now(),
        'feedback_timestamp': DateTime.now().toIso8601String(),
      };

      // Save feedback to delivery_feedback collection
      final feedbackRef = await _db.collection('delivery_feedback').add(feedbackData);

      // Update delivery task with feedback reference
      await _db.collection('deliveries').doc(deliveryTaskId).update({
        'customer_feedback_id': feedbackRef.id,
        'customer_feedback_submitted': true,
        'customer_ratings': {
          'delivery_speed': deliverySpeedRating,
          'rider_behavior': riderBehaviorRating,
          'packaging_quality': packagingQualityRating,
          'overall': overallRating,
        },
        'customer_review': review ?? '',
        'customer_feedback_timestamp': Timestamp.now(),
      });

      // Update agent's ratings based on feedback
      final delivery = await getDeliveryById(deliveryTaskId);
      if (delivery != null) {
        await _updateAgentRating(delivery.deliveryAgentId, overallRating);
      }

      // Mark feedback request as submitted
      final feedbackRequests = await _db
          .collection('feedback_requests')
          .where('order_id', isEqualTo: orderId)
          .get();

      for (final doc in feedbackRequests.docs) {
        await doc.reference.update({
          'status': 'submitted',
          'rating': overallRating,
          'review': review ?? '',
          'submitted_at': Timestamp.now(),
        });
      }
    } catch (e) {
      debugPrint('[DeliveryService] Error submitting feedback: $e');
      rethrow;
    }
  }
}
