import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomerDeliveryEventType {
  confirmed,
  preparing,
  assigned,
  picked_up,
  approaching, // e.g. 5 mins away
  delivered,
  exception_occurred,
}

class CustomerDeliveryEventModel {
  final String id;
  final String deliveryTaskId;
  final String orderId;
  final CustomerDeliveryEventType eventType;
  final String title;
  final String description;
  final DateTime timestamp;

  CustomerDeliveryEventModel({
    required this.id,
    required this.deliveryTaskId,
    required this.orderId,
    required this.eventType,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deliveryTaskId': deliveryTaskId,
      'orderId': orderId,
      'eventType': eventType.name,
      'title': title,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory CustomerDeliveryEventModel.fromMap(Map<String, dynamic> map, String docId) {
    return CustomerDeliveryEventModel(
      id: docId,
      deliveryTaskId: map['deliveryTaskId'] as String? ?? '',
      orderId: map['orderId'] as String? ?? '',
      eventType: CustomerDeliveryEventType.values.firstWhere(
        (e) => e.name == map['eventType'] as String?,
        orElse: () => CustomerDeliveryEventType.confirmed,
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
