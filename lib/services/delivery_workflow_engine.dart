// ============================================================
//  DeliveryWorkflowEngine — delivery_tracking status state machine
//
//  Mirrors OrderWorkflowEngine but for the `delivery_tracking`
//  table (per-driver delivery attempts). Validates transitions
//  before calling SupabaseDatabaseService.updateDeliveryStatus,
//  and helps drivers/dispatchers know which status changes are
//  currently legal.
//
//  Statuses:
//    assigned -> picked_up -> out_for_delivery -> delivered
//    assigned/picked_up/out_for_delivery -> failed | cancelled
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'delivery_ledger_service.dart';

/// Result of a [DeliveryWorkflowEngine.transition] attempt.
class DeliveryTransitionResult {
  final bool success;
  final String? error;

  const DeliveryTransitionResult.ok() : success = true, error = null;
  const DeliveryTransitionResult.failure(this.error) : success = false;
}

class DeliveryWorkflowEngine {
  static final DeliveryWorkflowEngine _instance = DeliveryWorkflowEngine._internal();
  factory DeliveryWorkflowEngine() => _instance;
  DeliveryWorkflowEngine._internal();

  final DeliveryLedgerService _ledger = DeliveryLedgerService();

  /// Map of delivery status -> set of statuses it may transition to.
  static const Map<String, Set<String>> validTransitions = {
    'assigned': {'picked_up', 'failed', 'cancelled'},
    'picked_up': {'out_for_delivery', 'failed', 'cancelled'},
    'out_for_delivery': {'delivered', 'failed', 'cancelled'},
    'delivered': <String>{},
    'failed': <String>{},
    'cancelled': <String>{},
  };

  static const Set<String> terminalStatuses = {'delivered', 'failed', 'cancelled'};

  bool isTerminal(String status) => terminalStatuses.contains(status);

  bool canTransition(String from, String to) {
    if (from == to) return false;
    return validTransitions[from]?.contains(to) ?? false;
  }

  /// Attempts to move the delivery_tracking row [trackingId] from
  /// [fromStatus] to [toStatus]. On success updates the row (status,
  /// optional location/proof/notes). On an invalid transition, returns
  /// a failure result and makes no writes.
  Future<DeliveryTransitionResult> transition({
    required String trackingId,
    required String fromStatus,
    required String toStatus,
    double? latitude,
    double? longitude,
    String? proofImageUrl,
    String? notes,
  }) async {
    if (!canTransition(fromStatus, toStatus)) {
      final msg = 'Invalid delivery transition: $fromStatus -> $toStatus (tracking $trackingId)';
      debugPrint('[DeliveryWorkflowEngine] $msg');
      return DeliveryTransitionResult.failure(msg);
    }

    // Delivery proof should accompany the terminal "delivered" status.
    if (toStatus == 'delivered' && proofImageUrl == null) {
      debugPrint(
        '[DeliveryWorkflowEngine] Warning: marking delivered without proofImageUrl (tracking $trackingId)',
      );
    }

    try {
      await FirebaseFirestore.instance.collection('delivery_tracking').doc(trackingId).update({
        'status': toStatus,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (proofImageUrl != null) 'proofImageUrl': proofImageUrl,
        if (notes != null) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const DeliveryTransitionResult.ok();
    } catch (e) {
      return DeliveryTransitionResult.failure('Failed to persist delivery status change: $e');
    }
  }

  /// Transitions a task in the AWS RDS `delivery_tasks` table and records audit events.
  Future<DeliveryTransitionResult> transitionTask({
    required String taskId,
    required String routeId,
    required String fromStatus,
    required String toStatus,
    double? latitude,
    double? longitude,
    String? proofImageUrl,
    String? notes,
    String? actorId,
  }) async {
    if (!canTransition(fromStatus, toStatus)) {
      final msg = 'Invalid delivery transition: $fromStatus -> $toStatus (task $taskId)';
      debugPrint('[DeliveryWorkflowEngine] $msg');
      return DeliveryTransitionResult.failure(msg);
    }

    final ok = await _ledger.updateTaskStatus(
      taskId: taskId,
      routeId: routeId,
      fromStatus: fromStatus,
      toStatus: toStatus,
      latitude: latitude,
      longitude: longitude,
      proofImageUrl: proofImageUrl,
      notes: notes,
      actorId: actorId,
    );

    if (!ok) {
      return const DeliveryTransitionResult.failure(
        'Failed to persist delivery task status change',
      );
    }
    return const DeliveryTransitionResult.ok();
  }

  /// Returns the set of statuses [fromStatus] may legally move to —
  /// useful for building action buttons in driver/dispatcher UIs.
  Set<String> nextStatuses(String fromStatus) {
    return validTransitions[fromStatus] ?? const <String>{};
  }
}
