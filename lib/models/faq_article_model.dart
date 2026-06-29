import 'package:cloud_firestore/cloud_firestore.dart';

/// Task #69 — FAQ article stored in Firestore `faq_articles/{id}`.
///
/// Each article has a list of [keywords] used for offline matching;
/// [views] is incremented each time the article is linked in chat.
class FaqArticleModel {
  final String id;
  final String question;
  final String answer;
  final String category;
  final List<String> keywords; // For offline matching
  final int sortOrder;
  final bool isActive;
  final int views;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FaqArticleModel({
    required this.id,
    required this.question,
    required this.answer,
    this.category = 'General',
    this.keywords = const [],
    this.sortOrder = 0,
    this.isActive = true,
    this.views = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory FaqArticleModel.fromMap(String id, Map<String, dynamic> map) {
    return FaqArticleModel(
      id: id,
      question: map['question'] as String? ?? '',
      answer: map['answer'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      keywords: List<String>.from(map['keywords'] as Iterable? ?? []),
      sortOrder: map['sortOrder'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      views: map['views'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'category': category,
      'keywords': keywords,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'views': views,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  FaqArticleModel copyWith({
    String? id,
    String? question,
    String? answer,
    String? category,
    List<String>? keywords,
    int? sortOrder,
    bool? isActive,
    int? views,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FaqArticleModel(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      keywords: keywords ?? this.keywords,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
