/// Model for employee performance metrics
class EmployeePerformanceModel {
  final String employeeId;
  final String name;
  final String role;
  final int ordersPacked;
  final double qualityScore; // percentage 0-100
  final double avgTimePerOrder; // in minutes
  final double rating; // 1-5 scale
  final double efficiency; // percentage 0-100
  final double attendanceScore; // percentage 0-100
  final double inventoryAccuracy; // percentage 0-100
  final DateTime lastUpdated;

  const EmployeePerformanceModel({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.ordersPacked,
    required this.qualityScore,
    required this.avgTimePerOrder,
    required this.rating,
    required this.efficiency,
    this.attendanceScore = 100.0,
    this.inventoryAccuracy = 100.0,
    required this.lastUpdated,
  });

  /// Factory constructor to create EmployeePerformanceModel from JSON/Map
  factory EmployeePerformanceModel.fromJson(Map<String, dynamic> json) {
    return EmployeePerformanceModel(
      employeeId: json['employeeId'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      role: json['role'] as String? ?? 'Employee',
      ordersPacked: json['ordersPacked'] as int? ?? 0,
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0.0,
      avgTimePerOrder: (json['avgTimePerOrder'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      efficiency: (json['efficiency'] as num?)?.toDouble() ?? 0.0,
      attendanceScore: (json['attendanceScore'] as num?)?.toDouble() ?? 100.0,
      inventoryAccuracy: (json['inventoryAccuracy'] as num?)?.toDouble() ?? 100.0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  /// Convert EmployeePerformanceModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'name': name,
      'role': role,
      'ordersPacked': ordersPacked,
      'qualityScore': qualityScore,
      'avgTimePerOrder': avgTimePerOrder,
      'rating': rating,
      'efficiency': efficiency,
      'attendanceScore': attendanceScore,
      'inventoryAccuracy': inventoryAccuracy,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Get performance category (Excellent, Good, Fair, Poor)
  String get performanceCategory {
    final avgScore = (qualityScore + efficiency) / 2;
    if (avgScore >= 90) {
      return 'Excellent';
    } else if (avgScore >= 75) {
      return 'Good';
    } else if (avgScore >= 60) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }

  /// Calculate overall performance score (0 - 100)
  double get overallScore {
    // rating is 1-5, convert to 0-100: rating * 20
    return (qualityScore + efficiency + (rating * 20) + attendanceScore + inventoryAccuracy) / 5;
  }

  /// Check if employee needs attention
  bool get needsAttention {
    return overallScore < 60 || qualityScore < 60 || efficiency < 60;
  }

  /// Copy with method for creating modified instances
  EmployeePerformanceModel copyWith({
    String? employeeId,
    String? name,
    String? role,
    int? ordersPacked,
    double? qualityScore,
    double? avgTimePerOrder,
    double? rating,
    double? efficiency,
    double? attendanceScore,
    double? inventoryAccuracy,
    DateTime? lastUpdated,
  }) {
    return EmployeePerformanceModel(
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      role: role ?? this.role,
      ordersPacked: ordersPacked ?? this.ordersPacked,
      qualityScore: qualityScore ?? this.qualityScore,
      avgTimePerOrder: avgTimePerOrder ?? this.avgTimePerOrder,
      rating: rating ?? this.rating,
      efficiency: efficiency ?? this.efficiency,
      attendanceScore: attendanceScore ?? this.attendanceScore,
      inventoryAccuracy: inventoryAccuracy ?? this.inventoryAccuracy,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'EmployeePerformanceModel(id: $employeeId, name: $name, role: $role, '
        'packed: $ordersPacked, quality: $qualityScore%, efficiency: $efficiency%, '
        'rating: $rating/5, overall: ${overallScore.toStringAsFixed(2)})';
  }
}
