import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qna_model.dart';
import '../models/product_model.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

/// Service layer for Q&A operations with real-time support
class QnaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final AnalyticsService _analyticsService = AnalyticsService();

  /// Collection reference for Q&A
  CollectionReference<Map<String, dynamic>> _qnaCollection(String productId) =>
      _firestore.collection('products').doc(productId).collection('qna');

  /// Ask a new question
  Future<QnaModel> askQuestion({
    required String productId,
    required String customerId,
    required String customerName,
    String? customerImage,
    required String question,
    bool isVerifiedPurchase = false,
  }) async {
    final qnaId = '${DateTime.now().millisecondsSinceEpoch}_$customerId';
    final now = DateTime.now();

    final qna = QnaModel(
      id: qnaId,
      productId: productId,
      customerId: customerId,
      customerName: customerName,
      customerImage: customerImage,
      question: question,
      createdAt: now,
      status: QnaStatus.pending,
      isVerifiedPurchase: isVerifiedPurchase,
    );

    await _qnaCollection(productId).doc(qnaId).set(qna.toMap());

    // Track analytics
    _analyticsService.trackEvent('qna_question_asked', {
      'productId': productId,
      'questionId': qnaId,
      'isVerifiedPurchase': isVerifiedPurchase,
    });

    // Notify shop owner
    _notifyShopOwner(productId, qna);

    return qna;
  }

  /// Answer a question (shop owner only)
  Future<QnaModel> answerQuestion({
    required String productId,
    required String questionId,
    required String shopOwnerId,
    required String shopOwnerName,
    required String answer,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('Question not found');
    }

    final existingQna = QnaModel.fromMap(doc.data() as Map<String, dynamic>);

    // Verify shop owner owns this product
    final productDoc = await _firestore.collection('products').doc(productId).get();
    if (productDoc.exists && productDoc.data() != null) {
      final product = ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);
      if (product.shopId != shopOwnerId) {
        throw Exception('Only the shop owner can answer this question');
      }
    }

    final updatedQna = existingQna.copyWith(
      answer: answer,
      shopOwnerId: shopOwnerId,
      shopOwnerName: shopOwnerName,
      answeredAt: DateTime.now(),
      status: QnaStatus.answered,
    );

    await _qnaCollection(productId).doc(questionId).update(updatedQna.toMap());

    // Track analytics
    _analyticsService.trackEvent('qna_question_answered', {
      'productId': productId,
      'questionId': questionId,
      'shopOwnerId': shopOwnerId,
    });

    // Notify customer
    _notifyCustomer(existingQna, updatedQna);

    return updatedQna;
  }

  /// Vote helpful on a question
  Future<void> voteHelpful({
    required String productId,
    required String questionId,
    required String userId,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) return;

    final qna = QnaModel.fromMap(doc.data() as Map<String, dynamic>);

    // Check if user already voted
    if (qna.helpfulVoters.contains(userId) || qna.unhelpfulVoters.contains(userId)) {
      throw Exception('User has already voted');
    }

    final updatedQna = qna.copyWith(
      helpfulVotes: qna.helpfulVotes + 1,
      helpfulVoters: [...qna.helpfulVoters, userId],
    );

    await _qnaCollection(productId).doc(questionId).update({
      'helpfulVotes': updatedQna.helpfulVotes,
      'helpfulVoters': updatedQna.helpfulVoters,
    });
  }

  /// Vote unhelpful on a question
  Future<void> voteUnhelpful({
    required String productId,
    required String questionId,
    required String userId,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) return;

    final qna = QnaModel.fromMap(doc.data() as Map<String, dynamic>);

    // Check if user already voted
    if (qna.helpfulVoters.contains(userId) || qna.unhelpfulVoters.contains(userId)) {
      throw Exception('User has already voted');
    }

    final updatedQna = qna.copyWith(
      unhelpfulVotes: qna.unhelpfulVotes + 1,
      unhelpfulVoters: [...qna.unhelpfulVoters, userId],
    );

    await _qnaCollection(productId).doc(questionId).update({
      'unhelpfulVotes': updatedQna.unhelpfulVotes,
      'unhelpfulVoters': updatedQna.unhelpfulVoters,
    });
  }

  /// Remove vote
  Future<void> removeVote({
    required String productId,
    required String questionId,
    required String userId,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) return;

    final qna = QnaModel.fromMap(doc.data() as Map<String, dynamic>);
    final updates = <String, dynamic>{};

    if (qna.helpfulVoters.contains(userId)) {
      updates['helpfulVotes'] = qna.helpfulVotes - 1;
      updates['helpfulVoters'] = FieldValue.arrayRemove([userId]);
    }

    if (qna.unhelpfulVoters.contains(userId)) {
      updates['unhelpfulVotes'] = qna.unhelpfulVotes - 1;
      updates['unhelpfulVoters'] = FieldValue.arrayRemove([userId]);
    }

    if (updates.isNotEmpty) {
      await _qnaCollection(productId).doc(questionId).update(updates);
    }
  }

  /// Flag a question for moderation
  Future<void> flagQuestion({
    required String productId,
    required String questionId,
    required String userId,
    required String reason,
  }) async {
    await _qnaCollection(productId).doc(questionId).update({
      'isFlagged': true,
      'flagReason': reason,
      'reportCount': FieldValue.increment(1),
    });

    // Track for moderation queue
    _analyticsService.trackEvent('qna_question_flagged', {
      'productId': productId,
      'questionId': questionId,
      'reason': reason,
    });
  }

  /// Delete a question (owner or admin only)
  Future<void> deleteQuestion({
    required String productId,
    required String questionId,
    required String userId,
    bool isAdmin = false,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) return;

    final qna = QnaModel.fromMap(doc.data() as Map<String, dynamic>);

    // Only allow deletion by owner, shop owner, or admin
    if (!isAdmin && qna.customerId != userId) {
      throw Exception('Not authorized to delete this question');
    }

    await _qnaCollection(productId).doc(questionId).delete();
  }

  /// Get single question by ID
  Future<QnaModel?> getQuestion({
    required String productId,
    required String questionId,
  }) async {
    final doc = await _qnaCollection(productId).doc(questionId).get();
    if (!doc.exists || doc.data() == null) return null;
    return QnaModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  /// Get all questions for a product with optional filtering
  Stream<List<QnaModel>> getQuestions({
    required String productId,
    QnaStatus? status,
    String? sortBy = 'recent', // recent, helpful, unanswered
    int limit = 50,
  }) {
    Query<Map<String, dynamic>> query = _qnaCollection(productId);

    // Apply status filter
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    // Apply sorting
    switch (sortBy) {
      case 'helpful':
        query = query.orderBy('helpfulVotes', descending: true);
        break;
      case 'unanswered':
        query = query.where('status', isEqualTo: 'pending');
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'recent':
      default:
        query = query.orderBy('createdAt', descending: true);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => QnaModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Get unanswered questions count
  Future<int> getUnansweredCount(String productId) async {
    final snapshot = await _qnaCollection(productId)
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Get questions for moderation (admin)
  Stream<List<QnaModel>> getFlaggedQuestions() {
    return _firestore
        .collectionGroup('qna')
        .where('isFlagged', isEqualTo: true)
        .orderBy('reportCount', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => QnaModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Resolve a question
  Future<void> resolveQuestion({
    required String productId,
    required String questionId,
  }) async {
    await _qnaCollection(productId).doc(questionId).update({
      'status': QnaStatus.resolved.name,
    });
  }

  /// Notify shop owner of new question
  Future<void> _notifyShopOwner(String productId, QnaModel qna) async {
    // Get product to find shop owner
    final productDoc = await _firestore.collection('products').doc(productId).get();
    if (!productDoc.exists || productDoc.data() == null) return;

    final product = ProductModel.fromMap(productDoc.data() as Map<String, dynamic>);

    // Send notification to shop owner
    await _notificationService.sendNotificationToUser(
      userId: product.shopId,
      title: 'New Question on ${product.name}',
      body: '${qna.customerName} asked: "${qna.question.substring(0, min(50, qna.question.length))}..."',
      data: {
        'type': 'qna_new',
        'productId': productId,
        'questionId': qna.id,
      },
    );
  }

  /// Notify customer of answer
  Future<void> _notifyCustomer(QnaModel original, QnaModel answered) async {
    await _notificationService.sendNotificationToUser(
      userId: original.customerId,
      title: 'Your question has been answered!',
      body: '${answered.shopOwnerName} answered your question about ${answered.answer?.substring(0, min(50, answered.answer!.length))}...',
      data: {
        'type': 'qna_answered',
        'productId': original.productId,
        'questionId': original.id,
      },
    );
  }

  /// Helper function to get min value
  static int min(int a, int b) => a < b ? a : b;
}
