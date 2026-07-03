import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/monetary_value.dart';

enum ExpenseCategory {
  salary,
  rent,
  utilities,
  maintenance,
  marketing,
  inventory,
  delivery,
  refund,
  other,
}

class ExpenseModel {
  final String id;
  final String branchId;
  final String description;
  final MonetaryValue amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? receiptUrl;
  final String recordedBy; // userId of the employee/manager
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    required this.id,
    required this.branchId,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.receiptUrl,
    required this.recordedBy,
    this.isRecurring = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branchId': branchId,
      'description': description,
      'amount': amount,
      'category': category.toString(),
      'date': Timestamp.fromDate(date),
      'receiptUrl': receiptUrl,
      'recordedBy': recordedBy,
      'isRecurring': isRecurring,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      description: map['description'] as String? ?? '',
      amount: MonetaryValue(map['amount'] ?? 0.0),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == map['category'] as String?,
        orElse: () => ExpenseCategory.other,
      ),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      receiptUrl: map['receiptUrl'] as String?,
      recordedBy: map['recordedBy'] as String? ?? '',
      isRecurring: map['isRecurring'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? branchId,
    String? description,
    MonetaryValue? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? receiptUrl,
    String? recordedBy,
    bool? isRecurring,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      recordedBy: recordedBy ?? this.recordedBy,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
