import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String riderId;
  final String riderName;
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final double clockInLatitude;
  final double clockInLongitude;
  final double? clockOutLatitude;
  final double? clockOutLongitude;
  final String status; // 'active' or 'completed'
  final String date; // 'YYYY-MM-DD'

  AttendanceModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.clockInTime,
    this.clockOutTime,
    required this.clockInLatitude,
    required this.clockInLongitude,
    this.clockOutLatitude,
    this.clockOutLongitude,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'clockInTime': Timestamp.fromDate(clockInTime),
      'clockOutTime': clockOutTime != null ? Timestamp.fromDate(clockOutTime!) : null,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,
      'status': status,
      'date': date,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as String? ?? '',
      riderId: map['riderId'] as String? ?? '',
      riderName: map['riderName'] as String? ?? '',
      clockInTime: (map['clockInTime'] as Timestamp).toDate(),
      clockOutTime: map['clockOutTime'] != null
          ? (map['clockOutTime'] as Timestamp).toDate()
          : null,
      clockInLatitude: (map['clockInLatitude'] as num? ?? 0.0).toDouble(),
      clockInLongitude: (map['clockInLongitude'] as num? ?? 0.0).toDouble(),
      clockOutLatitude: (map['clockOutLatitude'] as num?)?.toDouble(),
      clockOutLongitude: (map['clockOutLongitude'] as num?)?.toDouble(),
      status: map['status'] as String? ?? 'active',
      date: map['date'] as String? ?? '',
    );
  }

  AttendanceModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    double? clockInLatitude,
    double? clockInLongitude,
    double? clockOutLatitude,
    double? clockOutLongitude,
    String? status,
    String? date,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      clockInLatitude: clockInLatitude ?? this.clockInLatitude,
      clockInLongitude: clockInLongitude ?? this.clockInLongitude,
      clockOutLatitude: clockOutLatitude ?? this.clockOutLatitude,
      clockOutLongitude: clockOutLongitude ?? this.clockOutLongitude,
      status: status ?? this.status,
      date: date ?? this.date,
    );
  }
}
