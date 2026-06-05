import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_order_model.dart';

class GroupBuyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new neighborhood pool (Feature 15)
  Future<String> createPool({
    required String userId,
    required String shopId,
    required String district,
    required String village,
    required double initialContribution,
    required double goalAmount,
  }) async {
    final id = 'pool_${DateTime.now().millisecondsSinceEpoch}';
    final pool = GroupOrderModel(
      id: id,
      shopId: shopId,
      district: district,
      village: village,
      memberIds: [userId],
      memberContributions: {userId: initialContribution},
      totalAmount: initialContribution,
      goalAmount: goalAmount,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 3)),
    );

    await _firestore.collection('group_pools').doc(id).set(pool.toMap());
    return id;
  }

  /// Joins an existing pool
  Future<void> joinPool(
    String poolId,
    String userId,
    double contribution,
  ) async {
    final docRef = _firestore.collection('group_pools').doc(poolId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) throw Exception('Pool not found');

      final pool = GroupOrderModel.fromMap(snapshot.data()!);
      if (pool.isExpired) throw Exception('Pool expired');
      if (pool.isCompleted) throw Exception('Pool already full');

      final newMemberIds = [...pool.memberIds];
      if (!newMemberIds.contains(userId)) newMemberIds.add(userId);

      final newContributions = Map<String, double>.from(
        pool.memberContributions,
      );
      newContributions[userId] =
          (newContributions[userId] ?? 0.0) + contribution;

      final newTotal = pool.totalAmount + contribution;
      final isCompleted = newTotal >= pool.goalAmount;

      transaction.update(docRef, {
        'memberIds': newMemberIds,
        'memberContributions': newContributions,
        'totalAmount': newTotal,
        'isCompleted': isCompleted,
      });
    });
  }

  /// Streams active pools for a specific village
  Stream<List<GroupOrderModel>> getVillagePools(
    String district,
    String village,
  ) {
    return _firestore
        .collection('group_pools')
        .where('district', isEqualTo: district)
        .where('village', isEqualTo: village)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GroupOrderModel.fromMap(doc.data()))
              .where((p) => !p.isExpired)
              .toList(),
        );
  }
}
