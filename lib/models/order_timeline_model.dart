import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single status transition entry in the order timeline
class OrderTimelineModel {
  /// The order status at this point in time
  final String status;

  /// When this status change occurred
  final DateTime timestamp;

  /// Optional note about why the status changed (e.g., "Customer requested cancellation")
  final String? notes;

  /// Who made this change: 'customer', 'employee', 'delivery_agent', 'system'
  final String? actor;

  /// Additional actor information (name, ID, role)
  final String? actorId;
  final String? actorName;
  final String? actorRole;

  const OrderTimelineModel({
    required this.status,
    required this.timestamp,
    this.notes,
    this.actor,
    this.actorId,
    this.actorName,
    this.actorRole,
  });

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
      'actor': actor,
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
    };
  }

  /// Create from Firestore map
  factory OrderTimelineModel.fromMap(Map<String, dynamic> map) {
    return OrderTimelineModel(
      status: map['status'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
                ? (map['timestamp'] as Timestamp).toDate()
                : DateTime.parse(map['timestamp'].toString()))
          : DateTime.now(),
      notes: map['notes'] as String?,
      actor: map['actor'] as String?,
      actorId: map['actorId'] as String?,
      actorName: map['actorName'] as String?,
      actorRole: map['actorRole'] as String?,
    );
  }

  /// Create a copy with modified fields
  OrderTimelineModel copyWith({
    String? status,
    DateTime? timestamp,
    String? notes,
    String? actor,
    String? actorId,
    String? actorName,
    String? actorRole,
  }) {
    return OrderTimelineModel(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      actor: actor ?? this.actor,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorRole: actorRole ?? this.actorRole,
    );
  }

  @override
  String toString() => 'OrderTimelineModel(status: $status, timestamp: $timestamp, actor: $actor)';
}
