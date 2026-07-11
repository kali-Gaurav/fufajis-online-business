class DeliveryFeedbackModel {
  final String id;
  final String orderId;
  final String employeeId;
  final String customerId;

  final int serviceRating; // 1-5
  final String? feedbackText;
  final List<String> tags; // ['punctual', 'polite', 'careful', 'damaged', 'delayed', 'wrong_address']

  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryFeedbackModel({
    required this.id,
    required this.orderId,
    required this.employeeId,
    required this.customerId,
    required this.serviceRating,
    this.feedbackText,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryFeedbackModel.fromJson(Map<String, dynamic> json) {
    return DeliveryFeedbackModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      employeeId: json['employee_id'] as String,
      customerId: json['customer_id'] as String,
      serviceRating: json['service_rating'] as int,
      feedbackText: json['feedback_text'] as String?,
      tags: List<String>.from(json['tags'] as List? ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'employee_id': employeeId,
      'customer_id': customerId,
      'service_rating': serviceRating,
      'feedback_text': feedbackText,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DeliveryFeedbackModel copyWith({
    String? id,
    String? orderId,
    String? employeeId,
    String? customerId,
    int? serviceRating,
    String? feedbackText,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryFeedbackModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      serviceRating: serviceRating ?? this.serviceRating,
      feedbackText: feedbackText ?? this.feedbackText,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
