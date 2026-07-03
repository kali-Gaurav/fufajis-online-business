import 'package:cloud_firestore/cloud_firestore.dart';

/// Task #66 — Canned Response / Macro
///
/// Stored in Firestore: `canned_responses/{id}`
/// All staff roles (owner + employee) read from this collection.
/// Only owner/manager roles may write (enforced in UI; Firestore rules handle it).
class CannedResponseModel {
  final String id;
  final String title;
  final String text;
  final String category; // e.g. 'Greeting', 'Order', 'Delivery', 'Refund'
  final int sortOrder;
  final DateTime createdAt;

  const CannedResponseModel({
    required this.id,
    required this.title,
    required this.text,
    this.category = 'General',
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CannedResponseModel.fromMap(String id, Map<String, dynamic> map) {
    return CannedResponseModel(
      id: id,
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'text': text,
    'category': category,
    'sortOrder': sortOrder,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  CannedResponseModel copyWith({String? title, String? text, String? category, int? sortOrder}) {
    return CannedResponseModel(
      id: id,
      title: title ?? this.title,
      text: text ?? this.text,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
