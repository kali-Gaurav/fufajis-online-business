import 'package:cloud_firestore/cloud_firestore.dart';

/// Q&A Status enum for tracking question lifecycle
enum QnaStatus {
  pending('Pending'),
  answered('Answered'),
  resolved('Resolved'),
  flagged('Flagged');

  final String displayName;
  const QnaStatus(this.displayName);
}

/// Enhanced Q&A Model with voting, status tracking, and moderation support
class QnaModel {
  final String id;
  final String productId;
  final String customerId;
  final String customerName;
  final String? customerImage;
  final String question;
  final String? answer;
  final String? shopOwnerId;
  final String? shopOwnerName;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final int helpfulVotes;
  final int unhelpfulVotes;
  final List<String> helpfulVoters;
  final List<String> unhelpfulVoters;
  final QnaStatus status;
  final bool isFlagged;
  final String? flagReason;
  final int reportCount;
  final bool isVerifiedPurchase;

  QnaModel({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    this.customerImage,
    required this.question,
    this.answer,
    this.shopOwnerId,
    this.shopOwnerName,
    required this.createdAt,
    this.answeredAt,
    this.helpfulVotes = 0,
    this.unhelpfulVotes = 0,
    this.helpfulVoters = const [],
    this.unhelpfulVoters = const [],
    this.status = QnaStatus.pending,
    this.isFlagged = false,
    this.flagReason,
    this.reportCount = 0,
    this.isVerifiedPurchase = false,
  });

  /// Calculate helpfulness score for sorting
  int get helpfulnessScore => helpfulVotes - unhelpfulVotes;

  /// Check if user has voted helpful
  bool hasUserVotedHelpful(String userId) => helpfulVoters.contains(userId);

  /// Check if user has voted unhelpful
  bool hasUserVotedUnhelpful(String userId) => unhelpfulVoters.contains(userId);

  /// Check if user can vote (hasn't voted yet)
  bool canUserVote(String userId) =>
      !helpfulVoters.contains(userId) && !unhelpfulVoters.contains(userId);

  /// Get time ago string for display
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} weeks ago';
    return '${difference.inDays ~/ 30} months ago';
  }

  /// Get answer time ago string
  String? get answerTimeAgo {
    if (answeredAt == null) return null;
    final now = DateTime.now();
    final difference = now.difference(answeredAt!);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${difference.inDays ~/ 7} weeks ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'customerId': customerId,
      'customerName': customerName,
      'customerImage': customerImage,
      'question': question,
      'answer': answer,
      'shopOwnerId': shopOwnerId,
      'shopOwnerName': shopOwnerName,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
      'helpfulVotes': helpfulVotes,
      'unhelpfulVotes': unhelpfulVotes,
      'helpfulVoters': helpfulVoters,
      'unhelpfulVoters': unhelpfulVoters,
      'status': status.name,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'reportCount': reportCount,
      'isVerifiedPurchase': isVerifiedPurchase,
    };
  }

  factory QnaModel.fromMap(Map<String, dynamic> map) {
    return QnaModel(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerImage: map['customerImage'],
      question: map['question'] ?? '',
      answer: map['answer'],
      shopOwnerId: map['shopOwnerId'],
      shopOwnerName: map['shopOwnerName'],
      createdAt: _parseTimestamp(map['createdAt']),
      answeredAt: _parseTimestamp(map['answeredAt']),
      helpfulVotes: map['helpfulVotes'] ?? 0,
      unhelpfulVotes: map['unhelpfulVotes'] ?? 0,
      helpfulVoters: List<String>.from(map['helpfulVoters'] ?? []),
      unhelpfulVoters: List<String>.from(map['unhelpfulVoters'] ?? []),
      status: _parseStatus(map['status']),
      isFlagged: map['isFlagged'] ?? false,
      flagReason: map['flagReason'],
      reportCount: map['reportCount'] ?? 0,
      isVerifiedPurchase: map['isVerifiedPurchase'] ?? false,
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
  }

  static QnaStatus _parseStatus(dynamic status) {
    if (status == null) return QnaStatus.pending;
    if (status is QnaStatus) return status;
    try {
      return QnaStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return QnaStatus.pending;
    }
  }

  /// Create a copy with updated fields
  QnaModel copyWith({
    String? answer,
    String? shopOwnerId,
    String? shopOwnerName,
    DateTime? answeredAt,
    int? helpfulVotes,
    int? unhelpfulVotes,
    List<String>? helpfulVoters,
    List<String>? unhelpfulVoters,
    QnaStatus? status,
    bool? isFlagged,
    String? flagReason,
    int? reportCount,
  }) {
    return QnaModel(
      id: id,
      productId: productId,
      customerId: customerId,
      customerName: customerName,
      customerImage: customerImage,
      question: question,
      answer: answer ?? this.answer,
      shopOwnerId: shopOwnerId ?? this.shopOwnerId,
      shopOwnerName: shopOwnerName ?? this.shopOwnerName,
      createdAt: createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      helpfulVotes: helpfulVotes ?? this.helpfulVotes,
      unhelpfulVotes: unhelpfulVotes ?? this.unhelpfulVotes,
      helpfulVoters: helpfulVoters ?? this.helpfulVoters,
      unhelpfulVoters: unhelpfulVoters ?? this.unhelpfulVoters,
      status: status ?? this.status,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      reportCount: reportCount ?? this.reportCount,
      isVerifiedPurchase: isVerifiedPurchase,
    );
  }
}
