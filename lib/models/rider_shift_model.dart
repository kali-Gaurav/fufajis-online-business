import 'package:cloud_firestore/cloud_firestore.dart';

enum RiderShiftState {
  offline,
  available,
  assigned,
  busy,
  on_break
}

class RiderShiftModel {
  final String id;
  final String riderId;
  final String branchId;
  final RiderShiftState currentState;
  final DateTime startedAt;
  final DateTime? endedAt;
  
  // Stats for the current shift
  final int totalDeliveries;
  final double totalEarnings;
  final double totalDistance; // km
  final int totalIncidents;

  RiderShiftModel({
    required this.id,
    required this.riderId,
    required this.branchId,
    this.currentState = RiderShiftState.offline,
    required this.startedAt,
    this.endedAt,
    this.totalDeliveries = 0,
    this.totalEarnings = 0.0,
    this.totalDistance = 0.0,
    this.totalIncidents = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'branchId': branchId,
      'currentState': currentState.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
      'totalDistance': totalDistance,
      'totalIncidents': totalIncidents,
    };
  }

  factory RiderShiftModel.fromMap(Map<String, dynamic> map, String docId) {
    return RiderShiftModel(
      id: docId,
      riderId: map['riderId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      currentState: RiderShiftState.values.firstWhere(
        (e) => e.name == map['currentState'] as String?,
        orElse: () => RiderShiftState.offline,
      ),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      totalDeliveries: map['totalDeliveries'] as int? ?? 0,
      totalEarnings: (map['totalEarnings'] as num? ?? 0.0).toDouble(),
      totalDistance: (map['totalDistance'] as num? ?? 0.0).toDouble(),
      totalIncidents: map['totalIncidents'] as int? ?? 0,
    );
  }

  RiderShiftModel copyWith({
    RiderShiftState? currentState,
    DateTime? endedAt,
    int? totalDeliveries,
    double? totalEarnings,
    double? totalDistance,
    int? totalIncidents,
  }) {
    return RiderShiftModel(
      id: id,
      riderId: riderId,
      branchId: branchId,
      currentState: currentState ?? this.currentState,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalDistance: totalDistance ?? this.totalDistance,
      totalIncidents: totalIncidents ?? this.totalIncidents,
    );
  }
}
