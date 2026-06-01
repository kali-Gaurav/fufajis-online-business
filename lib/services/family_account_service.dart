import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/family_group_model.dart';
import 'notification_service.dart';
import 'whatsapp_notification_service.dart';

/// Production-grade Family Account Service
///
/// Handles:
/// - Family group CRUD
/// - Member management with role-based permissions
/// - Shared household cart syncing
/// - Parental approval workflows for child/guest orders
/// - Per-member spending limits and monthly budget tracking
/// - Real-time cart sync across family members
/// - WhatsApp notifications for approvals
class FamilyAccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WhatsAppNotificationService _whatsappService = WhatsAppNotificationService();

  static final FamilyAccountService _instance = FamilyAccountService._internal();
  factory FamilyAccountService() => _instance;
  FamilyAccountService._internal();

  // ===== FAMILY GROUP CRUD =====

  /// Creates a new family group with the requesting user as owner
  Future<FamilyGroup> createFamilyGroup({
    required String ownerUserId,
    required String ownerName,
    required String ownerPhone,
    required String familyName,
    double monthlyBudget = 0.0,
  }) async {
    try {
      final familyId = 'fam_${DateTime.now().millisecondsSinceEpoch}';
      final ownerMember = FamilyMember(
        userId: ownerUserId,
        name: ownerName,
        phoneNumber: ownerPhone,
        role: FamilyRole.owner,
        monthlySpendingLimit: 0.0, // Unlimited for owner
        joinedAt: DateTime.now(),
      );

      final group = FamilyGroup(
        id: familyId,
        familyName: familyName,
        ownerUserId: ownerUserId,
        members: [ownerMember],
        monthlyBudget: monthlyBudget,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('family_groups').doc(familyId).set(group.toMap());

      // Link family to user document
      await _firestore.collection('users').doc(ownerUserId).update({
        'familyGroupId': familyId,
        'familyRole': FamilyRole.owner.toString(),
      });

      return group;
    } catch (e) {
      debugPrint('Error creating family group: $e');
      rethrow;
    }
  }

  /// Get family group by ID
  Future<FamilyGroup?> getFamilyGroup(String familyId) async {
    try {
      final doc = await _firestore.collection('family_groups').doc(familyId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FamilyGroup.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('Error getting family group: $e');
      return null;
    }
  }

  /// Get family group for a user (looks up via user doc)
  Future<FamilyGroup?> getFamilyGroupForUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final familyId = userDoc.data()?['familyGroupId'];
      if (familyId == null) return null;
      return getFamilyGroup(familyId);
    } catch (e) {
      debugPrint('Error getting family group for user: $e');
      return null;
    }
  }

  /// Stream family group changes in real-time
  Stream<FamilyGroup?> watchFamilyGroup(String familyId) {
    return _firestore.collection('family_groups').doc(familyId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FamilyGroup.fromMap(doc.data()!);
    });
  }

  /// Delete a family group (owner only)
  Future<void> deleteFamilyGroup(String familyId, String requestingUserId) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');
      if (group.ownerUserId != requestingUserId) {
        throw Exception('Only the family owner can delete the group');
      }

      // Remove familyGroupId from all members
      final batch = _firestore.batch();
      for (final member in group.members) {
        batch.update(_firestore.collection('users').doc(member.userId), {
          'familyGroupId': FieldValue.delete(),
          'familyRole': FieldValue.delete(),
        });
      }
      batch.delete(_firestore.collection('family_groups').doc(familyId));
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting family group: $e');
      rethrow;
    }
  }

  // ===== MEMBER MANAGEMENT =====

  /// Invite a new member to the family group
  Future<void> addMember({
    required String familyId,
    required String requestingUserId,
    required String newUserId,
    required String newUserName,
    required String newUserPhone,
    FamilyRole role = FamilyRole.adult,
    double monthlySpendingLimit = 0.0,
    bool requiresApproval = false,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      // Permission check: only owner/parent can add members
      final requester = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == requestingUserId,
        orElse: () => null,
      );
      if (requester == null || !requester.hasPermission(FamilyPermission.manageMembers)) {
        throw Exception('You do not have permission to add members');
      }

      // Can't add someone who's already in the group
      if (group.members.any((m) => m.userId == newUserId)) {
        throw Exception('User is already a member of this family');
      }

      // Max 8 members per family
      if (group.members.length >= 8) {
        throw Exception('Maximum 8 members per family group');
      }

      // Owner can't add another owner
      if (role == FamilyRole.owner) {
        throw Exception('There can only be one owner per family');
      }

      // Child and guest roles require approval by default
      if (role == FamilyRole.child || role == FamilyRole.guest) {
        requiresApproval = true;
      }

      final newMember = FamilyMember(
        userId: newUserId,
        name: newUserName,
        phoneNumber: newUserPhone,
        role: role,
        monthlySpendingLimit: monthlySpendingLimit,
        requiresApproval: requiresApproval,
        joinedAt: DateTime.now(),
        invitedBy: requestingUserId,
      );

      // Update Firestore
      await _firestore.collection('family_groups').doc(familyId).update({
        'members': FieldValue.arrayUnion([newMember.toMap()]),
        'updatedAt': DateTime.now(),
      });

      // Link user doc to family
      await _firestore.collection('users').doc(newUserId).update({
        'familyGroupId': familyId,
        'familyRole': role.toString(),
        'familyMemberIds': FieldValue.arrayUnion([newUserId]),
      });

      // Notify via WhatsApp
      WhatsAppNotificationService.sendOrderUpdate(
        phoneNumber: newUserPhone,
        message: '🏠 Welcome to ${group.familyName}! You have been added as a ${role.name} member by ${requester.name}. You can now share carts and place orders together.',
      );
    } catch (e) {
      debugPrint('Error adding family member: $e');
      rethrow;
    }
  }

  /// Remove a member from the family group
  Future<void> removeMember({
    required String familyId,
    required String requestingUserId,
    required String targetUserId,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      // Can't remove the owner
      if (targetUserId == group.ownerUserId) {
        throw Exception('Cannot remove the family owner');
      }

      final requester = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == requestingUserId,
        orElse: () => null,
      );
      if (requester == null || !requester.hasPermission(FamilyPermission.removeMember)) {
        // Allow self-removal
        if (requestingUserId != targetUserId) {
          throw Exception('You do not have permission to remove members');
        }
      }

      final targetMember = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == targetUserId,
        orElse: () => null,
      );
      if (targetMember == null) throw Exception('Member not found');

      // Remove from Firestore
      final updatedMembers = group.members.where((m) => m.userId != targetUserId).toList();
      await _firestore.collection('family_groups').doc(familyId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'updatedAt': DateTime.now(),
      });

      // Unlink user doc
      await _firestore.collection('users').doc(targetUserId).update({
        'familyGroupId': FieldValue.delete(),
        'familyRole': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('Error removing family member: $e');
      rethrow;
    }
  }

  /// Update a member's role or spending limit
  Future<void> updateMemberSettings({
    required String familyId,
    required String requestingUserId,
    required String targetUserId,
    FamilyRole? newRole,
    double? monthlySpendingLimit,
    bool? requiresApproval,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      final requester = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == requestingUserId,
        orElse: () => null,
      );
      if (requester == null || !requester.hasPermission(FamilyPermission.setSpendingLimits)) {
        throw Exception('You do not have permission to update member settings');
      }

      final updatedMembers = group.members.map((m) {
        if (m.userId == targetUserId) {
          return m.copyWith(
            role: newRole,
            monthlySpendingLimit: monthlySpendingLimit,
            requiresApproval: requiresApproval,
          );
        }
        return m;
      }).toList();

      await _firestore.collection('family_groups').doc(familyId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'updatedAt': DateTime.now(),
      });

      // Update user doc if role changed
      if (newRole != null) {
        await _firestore.collection('users').doc(targetUserId).update({
          'familyRole': newRole.toString(),
        });
      }
    } catch (e) {
      debugPrint('Error updating member settings: $e');
      rethrow;
    }
  }

  // ===== SHARED CART MANAGEMENT =====

  /// Add an item to the shared family cart
  Future<void> addToSharedCart({
    required String familyId,
    required String userId,
    required String userName,
    required String productId,
    required String productName,
    required int quantity,
    required double price,
    String? note,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      final member = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == userId,
        orElse: () => null,
      );
      if (member == null || !member.hasPermission(FamilyPermission.addToCart)) {
        throw Exception('You do not have permission to add items to cart');
      }

      // Check guest item limit (max 5 items for guests)
      if (member.role == FamilyRole.guest) {
        final guestItems = group.sharedCart.where((i) => i.addedByUserId == userId).length;
        if (guestItems >= 5) {
          throw Exception('Guest members can add up to 5 items');
        }
      }

      final cartItem = SharedCartItem(
        productId: productId,
        productName: productName,
        quantity: quantity,
        price: price,
        addedByUserId: userId,
        addedByName: userName,
        addedAt: DateTime.now(),
        note: note,
      );

      // Check if product already exists in shared cart
      final existingIndex = group.sharedCart.indexWhere((i) => i.productId == productId);
      List<SharedCartItem> updatedCart;

      if (existingIndex >= 0) {
        // Update quantity
        updatedCart = List.from(group.sharedCart);
        final existing = updatedCart[existingIndex];
        updatedCart[existingIndex] = SharedCartItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + quantity,
          price: price,
          addedByUserId: userId,
          addedByName: '$userName (+${existing.addedByName})',
          addedAt: DateTime.now(),
          note: note ?? existing.note,
        );
      } else {
        updatedCart = [...group.sharedCart, cartItem];
      }

      await _firestore.collection('family_groups').doc(familyId).update({
        'sharedCart': updatedCart.map((c) => c.toMap()).toList(),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error adding to shared cart: $e');
      rethrow;
    }
  }

  /// Remove an item from the shared cart
  Future<void> removeFromSharedCart({
    required String familyId,
    required String productId,
    required String userId,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      final member = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == userId,
        orElse: () => null,
      );
      if (member == null) throw Exception('Member not found');

      // Members can remove their own items, owner/parent can remove any
      final item = group.sharedCart.cast<SharedCartItem?>().firstWhere(
        (i) => i?.productId == productId,
        orElse: () => null,
      );
      if (item == null) return;

      if (item.addedByUserId != userId &&
          !member.hasPermission(FamilyPermission.manageMembers)) {
        throw Exception('You can only remove items you added');
      }

      final updatedCart = group.sharedCart.where((i) => i.productId != productId).toList();

      await _firestore.collection('family_groups').doc(familyId).update({
        'sharedCart': updatedCart.map((c) => c.toMap()).toList(),
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error removing from shared cart: $e');
      rethrow;
    }
  }

  /// Clear the entire shared cart (after checkout)
  Future<void> clearSharedCart(String familyId) async {
    try {
      await _firestore.collection('family_groups').doc(familyId).update({
        'sharedCart': [],
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error clearing shared cart: $e');
      rethrow;
    }
  }

  /// Stream real-time shared cart updates
  Stream<List<SharedCartItem>> watchSharedCart(String familyId) {
    return _firestore.collection('family_groups').doc(familyId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return [];
      final data = doc.data()!;
      return (data['sharedCart'] as List<dynamic>?)
              ?.map((c) => SharedCartItem.fromMap(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [];
    });
  }

  // ===== APPROVAL WORKFLOWS =====

  /// Submit an order for parental/owner approval (used by child/guest members)
  Future<String> requestOrderApproval({
    required String familyId,
    required String orderId,
    required String requestedByUserId,
    required String requestedByName,
    required double orderAmount,
    required List<String> itemNames,
  }) async {
    try {
      final approvalId = 'approval_${DateTime.now().millisecondsSinceEpoch}';
      final request = FamilyApprovalRequest(
        id: approvalId,
        orderId: orderId,
        requestedBy: requestedByUserId,
        requestedByName: requestedByName,
        orderAmount: orderAmount,
        itemNames: itemNames,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('family_groups').doc(familyId).update({
        'pendingApprovals': FieldValue.arrayUnion([request.toMap()]),
        'updatedAt': DateTime.now(),
      });

      // Also store in sub-collection for easy querying
      await _firestore
          .collection('family_groups')
          .doc(familyId)
          .collection('approval_requests')
          .doc(approvalId)
          .set(request.toMap());

      // Notify all parents/owner via push & WhatsApp
      final group = await getFamilyGroup(familyId);
      if (group != null) {
        final approvers = group.members.where(
          (m) => m.hasPermission(FamilyPermission.approveChildOrders) && m.userId != requestedByUserId,
        );

        for (final approver in approvers) {
          WhatsAppNotificationService.sendOrderUpdate(
            phoneNumber: approver.phoneNumber,
            message: '🔔 $requestedByName wants to order ${itemNames.length} items for ₹${orderAmount.toStringAsFixed(0)}. Reply APPROVE or REJECT.',
          );
        }
      }

      return approvalId;
    } catch (e) {
      debugPrint('Error requesting order approval: $e');
      rethrow;
    }
  }

  /// Approve or reject a child/guest order request
  Future<void> resolveApproval({
    required String familyId,
    required String approvalId,
    required String resolverUserId,
    required bool approved,
    String? rejectionReason,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      final resolver = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == resolverUserId,
        orElse: () => null,
      );
      if (resolver == null || !resolver.hasPermission(FamilyPermission.approveChildOrders)) {
        throw Exception('You do not have permission to approve orders');
      }

      // Update sub-collection doc
      await _firestore
          .collection('family_groups')
          .doc(familyId)
          .collection('approval_requests')
          .doc(approvalId)
          .update({
        'status': approved ? 'approved' : 'rejected',
        'approvedBy': resolverUserId,
        'rejectionReason': rejectionReason,
        'resolvedAt': DateTime.now(),
      });

      // Remove from pendingApprovals array
      final updatedApprovals = group.pendingApprovals.where((a) => a.id != approvalId).toList();
      await _firestore.collection('family_groups').doc(familyId).update({
        'pendingApprovals': updatedApprovals.map((a) => a.toMap()).toList(),
        'updatedAt': DateTime.now(),
      });

      // Notify the requester
      final request = group.pendingApprovals.cast<FamilyApprovalRequest?>().firstWhere(
        (a) => a?.id == approvalId,
        orElse: () => null,
      );
      if (request != null) {
        final requesterMember = group.members.cast<FamilyMember?>().firstWhere(
          (m) => m?.userId == request.requestedBy,
          orElse: () => null,
        );
        if (requesterMember != null) {
          final status = approved ? '✅ Approved' : '❌ Rejected';
          WhatsAppNotificationService.sendOrderUpdate(
            phoneNumber: requesterMember.phoneNumber,
            message: '$status: Your order request for ₹${request.orderAmount.toStringAsFixed(0)} has been ${approved ? 'approved' : 'rejected'} by ${resolver.name}.${rejectionReason != null ? ' Reason: $rejectionReason' : ''}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error resolving approval: $e');
      rethrow;
    }
  }

  /// Stream pending approvals for a family
  Stream<List<FamilyApprovalRequest>> watchPendingApprovals(String familyId) {
    return _firestore
        .collection('family_groups')
        .doc(familyId)
        .collection('approval_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FamilyApprovalRequest.fromMap(doc.data())).toList();
    });
  }

  // ===== SPENDING TRACKING =====

  /// Record a member's spending and update monthly totals
  Future<void> recordMemberSpending({
    required String familyId,
    required String userId,
    required double amount,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) return;

      // Update member's current month spending
      final updatedMembers = group.members.map((m) {
        if (m.userId == userId) {
          return m.copyWith(
            currentMonthSpending: m.currentMonthSpending + amount,
            lastOrderAt: DateTime.now(),
          );
        }
        return m;
      }).toList();

      await _firestore.collection('family_groups').doc(familyId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
        'currentMonthSpending': group.currentMonthSpending + amount,
        'updatedAt': DateTime.now(),
      });

      // Check if member exceeded their limit
      final member = updatedMembers.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == userId,
        orElse: () => null,
      );
      if (member != null &&
          member.monthlySpendingLimit > 0 &&
          member.currentMonthSpending > member.monthlySpendingLimit * 0.9) {
        // Notify owner about approaching limit
        final owner = group.members.cast<FamilyMember?>().firstWhere(
          (m) => m?.userId == group.ownerUserId,
          orElse: () => null,
        );
        if (owner != null) {
          WhatsAppNotificationService.sendOrderUpdate(
            phoneNumber: owner.phoneNumber,
            message: '⚠️ ${member.name} has used ${((member.currentMonthSpending / member.monthlySpendingLimit) * 100).toStringAsFixed(0)}% of their monthly limit (₹${member.monthlySpendingLimit.toStringAsFixed(0)}).',
          );
        }
      }
    } catch (e) {
      debugPrint('Error recording member spending: $e');
    }
  }

  /// Reset monthly spending for all members (should be called on 1st of each month)
  Future<void> resetMonthlySpending(String familyId) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) return;

      final resetMembers = group.members.map((m) {
        return m.copyWith(currentMonthSpending: 0.0);
      }).toList();

      await _firestore.collection('family_groups').doc(familyId).update({
        'members': resetMembers.map((m) => m.toMap()).toList(),
        'currentMonthSpending': 0.0,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error resetting monthly spending: $e');
    }
  }

  // ===== HOUSEHOLD BUDGET =====

  /// Update the family monthly budget
  Future<void> updateFamilyBudget({
    required String familyId,
    required String requestingUserId,
    required double newBudget,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      if (group.ownerUserId != requestingUserId) {
        throw Exception('Only the owner can update the family budget');
      }

      await _firestore.collection('family_groups').doc(familyId).update({
        'monthlyBudget': newBudget,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error updating family budget: $e');
      rethrow;
    }
  }

  /// Update auto-approve settings
  Future<void> updateAutoApproveSettings({
    required String familyId,
    required String requestingUserId,
    required bool enabled,
    double? threshold,
  }) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) throw Exception('Family group not found');

      final requester = group.members.cast<FamilyMember?>().firstWhere(
        (m) => m?.userId == requestingUserId,
        orElse: () => null,
      );
      if (requester == null || !requester.hasPermission(FamilyPermission.setSpendingLimits)) {
        throw Exception('You do not have permission to update auto-approve settings');
      }

      await _firestore.collection('family_groups').doc(familyId).update({
        'autoApproveUnderLimit': enabled,
        if (threshold != null) 'autoApproveThreshold': threshold,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      debugPrint('Error updating auto-approve settings: $e');
      rethrow;
    }
  }

  /// Check if a member's order should be auto-approved
  bool shouldAutoApprove(FamilyGroup group, String userId, double orderAmount) {
    final member = group.members.cast<FamilyMember?>().firstWhere(
      (m) => m?.userId == userId,
      orElse: () => null,
    );
    if (member == null) return false;

    // Owner and parent never need approval
    if (member.role == FamilyRole.owner || member.role == FamilyRole.parent) return true;

    // Adult members without requiresApproval flag
    if (member.role == FamilyRole.adult && !member.requiresApproval) return true;

    // Check auto-approve threshold
    if (group.autoApproveUnderLimit && orderAmount <= group.autoApproveThreshold) {
      return true;
    }

    return false;
  }

  // ===== FAMILY ANALYTICS =====

  /// Get spending breakdown by member for the current month
  Future<Map<String, double>> getMemberSpendingBreakdown(String familyId) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) return {};

      final breakdown = <String, double>{};
      for (final member in group.members) {
        breakdown[member.name] = member.currentMonthSpending;
      }
      return breakdown;
    } catch (e) {
      debugPrint('Error getting spending breakdown: $e');
      return {};
    }
  }

  /// Get family order history
  Future<List<Map<String, dynamic>>> getFamilyOrderHistory(String familyId, {int limit = 20}) async {
    try {
      final group = await getFamilyGroup(familyId);
      if (group == null) return [];

      final memberIds = group.members.map((m) => m.userId).toList();
      final snapshot = await _firestore
          .collection('orders')
          .where('customerId', whereIn: memberIds.take(10).toList()) // Firestore limit
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final memberName = group.members
            .cast<FamilyMember?>()
            .firstWhere((m) => m?.userId == data['customerId'], orElse: () => null)
            ?.name ?? 'Unknown';
        return {
          ...data,
          'memberName': memberName,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting family order history: $e');
      return [];
    }
  }
}
