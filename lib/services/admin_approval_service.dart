import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for secure product approval workflows with role-based access control
/// Only admins can approve products, and products are verified to belong to valid shops
class AdminApprovalService {
  static final AdminApprovalService _instance = AdminApprovalService._internal();
  factory AdminApprovalService() => _instance;
  AdminApprovalService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Valid admin roles that can approve products
  static const Set<String> _validAdminRoles = {'admin', 'superAdmin', 'owner'};

  /// Approves a product for public visibility.
  /// Only users with admin roles can approve products.
  /// Verifies that the product belongs to a valid shop before approval.
  ///
  /// Parameters:
  ///   productId: ID of the product to approve
  ///   approverRole: The role of the user approving the product
  ///   approverId: The user ID of the person approving
  ///   notes: Optional approval notes/comments
  ///
  /// Throws: UnauthorizedException if user doesn't have admin role
  /// Throws: ArgumentError if product or shop doesn't exist
  Future<bool> approveProduct({
    required String productId,
    required String approverRole,
    required String approverId,
    String? notes,
  }) async {
    try {
      // SECURITY: Verify the approver has admin role
      _verifyAdminRole(approverRole);

      // Fetch product to verify it exists and get shop info
      final productDoc = await _db.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw ArgumentError('Product $productId does not exist');
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final shopId = productData['shopId'] as String?;

      if (shopId == null || shopId.isEmpty) {
        throw ArgumentError('Product $productId has no associated shop');
      }

      // SECURITY: Verify the shop exists and is valid
      await _verifyShopExists(shopId);

      // VALIDATION: Verify product data is valid
      _validateProductForApproval(productData);

      // Approve the product
      await _db.collection('products').doc(productId).update({
        'approvalStatus': 'approved',
        'approvedBy': approverId,
        'approvedAt': FieldValue.serverTimestamp(),
        'isAvailable': true,
        'approvalNotes': notes ?? '',
      });

      // Record approval in audit log
      await _recordApprovalAudit(
        productId: productId,
        shopId: shopId,
        approverId: approverId,
        approverRole: approverRole,
        notes: notes,
        action: 'APPROVED',
      );

      debugPrint(
        '[AdminApprovalService] Product $productId approved by $approverId ($approverRole)',
      );
      return true;
    } catch (e) {
      debugPrint('[AdminApprovalService] Approval failed: $e');
      rethrow;
    }
  }

  /// Rejects a product and prevents it from being visible.
  /// Only users with admin roles can reject products.
  ///
  /// Parameters:
  ///   productId: ID of the product to reject
  ///   approverRole: The role of the user rejecting the product
  ///   approverId: The user ID of the person rejecting
  ///   reason: Required reason for rejection
  ///
  /// Throws: UnauthorizedException if user doesn't have admin role
  /// Throws: ArgumentError if product doesn't exist or reason is empty
  Future<bool> rejectProduct({
    required String productId,
    required String approverRole,
    required String approverId,
    required String reason,
  }) async {
    try {
      // SECURITY: Verify the rejector has admin role
      _verifyAdminRole(approverRole);

      if (reason.trim().isEmpty) {
        throw ArgumentError('Rejection reason cannot be empty');
      }

      // Fetch product to verify it exists and get shop info
      final productDoc = await _db.collection('products').doc(productId).get();
      if (!productDoc.exists) {
        throw ArgumentError('Product $productId does not exist');
      }

      final productData = productDoc.data() as Map<String, dynamic>;
      final shopId = productData['shopId'] as String?;

      if (shopId == null || shopId.isEmpty) {
        throw ArgumentError('Product $productId has no associated shop');
      }

      // Reject the product
      await _db.collection('products').doc(productId).update({
        'approvalStatus': 'rejected',
        'rejectedBy': approverId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'isAvailable': false,
        'rejectionReason': reason,
      });

      // Record rejection in audit log
      await _recordApprovalAudit(
        productId: productId,
        shopId: shopId,
        approverId: approverId,
        approverRole: approverRole,
        notes: reason,
        action: 'REJECTED',
      );

      debugPrint(
        '[AdminApprovalService] Product $productId rejected by $approverId ($approverRole)',
      );
      return true;
    } catch (e) {
      debugPrint('[AdminApprovalService] Rejection failed: $e');
      rethrow;
    }
  }

  /// Fetches all pending product approvals for the admin dashboard
  Future<List<Map<String, dynamic>>> getPendingApprovals({int limit = 50}) async {
    try {
      final query = await _db
          .collection('products')
          .where('approvalStatus', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('[AdminApprovalService] Error fetching pending approvals: $e');
      return [];
    }
  }

  /// Verifies that the given role is an admin role
  void _verifyAdminRole(String role) {
    if (!_validAdminRoles.contains(role.toLowerCase())) {
      throw UnauthorizedException(
        'Role "$role" is not authorized to approve products. Only $_validAdminRoles can approve.',
      );
    }
  }

  /// Verifies that the shop exists in Firestore
  Future<void> _verifyShopExists(String shopId) async {
    try {
      final shopDoc = await _db.collection('shops').doc(shopId).get();
      if (!shopDoc.exists) {
        throw ArgumentError('Shop $shopId does not exist');
      }

      final shopData = shopDoc.data() as Map<String, dynamic>;
      final shopStatus = shopData['status'] as String? ?? 'active';

      // Shop should be active or at least not deleted
      if (shopStatus == 'closed' || shopStatus == 'deleted') {
        throw ArgumentError('Shop $shopId is $shopStatus and cannot have products');
      }
    } catch (e) {
      debugPrint('[AdminApprovalService] Shop verification failed: $e');
      rethrow;
    }
  }

  /// Validates product data before approval
  void _validateProductForApproval(Map<String, dynamic> productData) {
    // Validate required fields exist
    final name = productData['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      throw ArgumentError('Product must have a valid name');
    }

    final category = productData['category'] as String?;
    if (category == null || category.trim().isEmpty) {
      throw ArgumentError('Product must have a valid category');
    }

    // Validate price is non-negative
    final price = (productData['price'] as num?)?.toDouble() ?? 0.0;
    if (price < 0) {
      throw ArgumentError('Product price must be >= 0');
    }

    // Validate stock is non-negative
    final stock = (productData['stockQuantity'] as int?) ?? 0;
    if (stock < 0) {
      throw ArgumentError('Product stock must be >= 0');
    }

    debugPrint('[AdminApprovalService] Product validation passed');
  }

  /// Records product approval/rejection in audit log
  Future<void> _recordApprovalAudit({
    required String productId,
    required String shopId,
    required String approverId,
    required String approverRole,
    required String? notes,
    required String action,
  }) async {
    try {
      await _db.collection('approval_audits').add({
        'productId': productId,
        'shopId': shopId,
        'approverId': approverId,
        'approverRole': approverRole,
        'action': action,
        'notes': notes ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('[AdminApprovalService] Approval audit recorded for product $productId');
    } catch (e) {
      debugPrint('[AdminApprovalService] Failed to record audit: $e');
      // Don't rethrow - audit failure shouldn't block the approval
    }
  }
}

/// Custom exception for authorization failures
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'UnauthorizedException: $message';
}
