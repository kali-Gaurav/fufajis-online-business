/// Family member roles with hierarchical permissions
enum FamilyRole {
  owner, // Full control, billing, can't be removed
  parent, // Approve child orders, manage members
  adult, // Can checkout independently with optional limits
  child, // Needs approval for checkout
  guest, // View-only + limited cart (temporary access)
}

/// Permission actions for the family system
enum FamilyPermission {
  addToCart,
  checkout,
  makePayment,
  viewOrders,
  editAddress,
  approveChildOrders,
  manageMembers,
  setSpendingLimits,
  viewAnalytics,
  removeMember,
}

/// Represents a single member inside a family group
class FamilyMember {
  final String userId;
  final String name;
  final String phoneNumber;
  final String? profileImageUrl;
  final FamilyRole role;
  final double monthlySpendingLimit; // ₹0 = unlimited
  final double currentMonthSpending;
  final bool requiresApproval; // If true, orders need parent/owner sign-off
  final bool isActive;
  final DateTime joinedAt;
  final DateTime? lastOrderAt;
  final String? invitedBy;

  FamilyMember({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.profileImageUrl,
    this.role = FamilyRole.adult,
    this.monthlySpendingLimit = 0.0,
    this.currentMonthSpending = 0.0,
    this.requiresApproval = false,
    this.isActive = true,
    required this.joinedAt,
    this.lastOrderAt,
    this.invitedBy,
  });

  /// Check if this member has a specific permission
  bool hasPermission(FamilyPermission permission) {
    return _permissionMatrix[role]?.contains(permission) ?? false;
  }

  /// Check if member can still spend within their limit
  bool canSpend(double amount) {
    if (monthlySpendingLimit <= 0) return true; // Unlimited
    return (currentMonthSpending + amount) <= monthlySpendingLimit;
  }

  /// Remaining budget for the month
  double get remainingBudget {
    if (monthlySpendingLimit <= 0) return double.infinity;
    return (monthlySpendingLimit - currentMonthSpending).clamp(
      0,
      monthlySpendingLimit,
    );
  }

  static const Map<FamilyRole, Set<FamilyPermission>> _permissionMatrix = {
    FamilyRole.owner: {
      FamilyPermission.addToCart,
      FamilyPermission.checkout,
      FamilyPermission.makePayment,
      FamilyPermission.viewOrders,
      FamilyPermission.editAddress,
      FamilyPermission.approveChildOrders,
      FamilyPermission.manageMembers,
      FamilyPermission.setSpendingLimits,
      FamilyPermission.viewAnalytics,
      FamilyPermission.removeMember,
    },
    FamilyRole.parent: {
      FamilyPermission.addToCart,
      FamilyPermission.checkout,
      FamilyPermission.makePayment,
      FamilyPermission.viewOrders,
      FamilyPermission.editAddress,
      FamilyPermission.approveChildOrders,
      FamilyPermission.manageMembers,
      FamilyPermission.viewAnalytics,
    },
    FamilyRole.adult: {
      FamilyPermission.addToCart,
      FamilyPermission.checkout,
      FamilyPermission.viewOrders,
      FamilyPermission.editAddress,
    },
    FamilyRole.child: {FamilyPermission.addToCart, FamilyPermission.viewOrders},
    FamilyRole.guest: {FamilyPermission.addToCart},
  };

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      role: FamilyRole.values.firstWhere(
        (e) => e.toString() == map['role'],
        orElse: () => FamilyRole.adult,
      ),
      monthlySpendingLimit: (map['monthlySpendingLimit'] ?? 0.0).toDouble(),
      currentMonthSpending: (map['currentMonthSpending'] ?? 0.0).toDouble(),
      requiresApproval: map['requiresApproval'] ?? false,
      isActive: map['isActive'] ?? true,
      joinedAt: map['joinedAt']?.toDate() ?? DateTime.now(),
      lastOrderAt: map['lastOrderAt']?.toDate(),
      invitedBy: map['invitedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'role': role.toString(),
      'monthlySpendingLimit': monthlySpendingLimit,
      'currentMonthSpending': currentMonthSpending,
      'requiresApproval': requiresApproval,
      'isActive': isActive,
      'joinedAt': joinedAt,
      'lastOrderAt': lastOrderAt,
      'invitedBy': invitedBy,
    };
  }

  FamilyMember copyWith({
    String? userId,
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
    FamilyRole? role,
    double? monthlySpendingLimit,
    double? currentMonthSpending,
    bool? requiresApproval,
    bool? isActive,
    DateTime? joinedAt,
    DateTime? lastOrderAt,
    String? invitedBy,
  }) {
    return FamilyMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      monthlySpendingLimit: monthlySpendingLimit ?? this.monthlySpendingLimit,
      currentMonthSpending: currentMonthSpending ?? this.currentMonthSpending,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      isActive: isActive ?? this.isActive,
      joinedAt: joinedAt ?? this.joinedAt,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
      invitedBy: invitedBy ?? this.invitedBy,
    );
  }
}

/// Represents a pending approval request in the family system
class FamilyApprovalRequest {
  final String id;
  final String orderId;
  final String requestedBy; // userId of requester
  final String requestedByName;
  final double orderAmount;
  final List<String> itemNames;
  final String status; // pending, approved, rejected
  final String? approvedBy;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  FamilyApprovalRequest({
    required this.id,
    required this.orderId,
    required this.requestedBy,
    required this.requestedByName,
    required this.orderAmount,
    required this.itemNames,
    this.status = 'pending',
    this.approvedBy,
    this.rejectionReason,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory FamilyApprovalRequest.fromMap(Map<String, dynamic> map) {
    return FamilyApprovalRequest(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      orderAmount: (map['orderAmount'] ?? 0.0).toDouble(),
      itemNames: List<String>.from(map['itemNames'] ?? []),
      status: map['status'] ?? 'pending',
      approvedBy: map['approvedBy'],
      rejectionReason: map['rejectionReason'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      resolvedAt: map['resolvedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'orderAmount': orderAmount,
      'itemNames': itemNames,
      'status': status,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'resolvedAt': resolvedAt,
    };
  }
}

/// Shared item added by a family member to the household cart
class SharedCartItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String addedByUserId;
  final String addedByName;
  final DateTime addedAt;
  final String? note;

  SharedCartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.addedByUserId,
    required this.addedByName,
    required this.addedAt,
    this.note,
  });

  factory SharedCartItem.fromMap(Map<String, dynamic> map) {
    return SharedCartItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 1,
      price: (map['price'] ?? 0.0).toDouble(),
      addedByUserId: map['addedByUserId'] ?? '',
      addedByName: map['addedByName'] ?? '',
      addedAt: map['addedAt']?.toDate() ?? DateTime.now(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'addedByUserId': addedByUserId,
      'addedByName': addedByName,
      'addedAt': addedAt,
      'note': note,
    };
  }
}

/// Represents a complete family group with members, shared cart, and settings
class FamilyGroup {
  final String id;
  final String familyName;
  final String ownerUserId;
  final List<FamilyMember> members;
  final List<SharedCartItem> sharedCart;
  final List<FamilyApprovalRequest> pendingApprovals;
  final double monthlyBudget; // Household monthly budget cap (₹0 = unlimited)
  final double currentMonthSpending;
  final bool autoApproveUnderLimit; // Auto-approve child orders under ₹X
  final double autoApproveThreshold; // The ₹X limit
  final String? defaultAddressId;
  final String? defaultPaymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyGroup({
    required this.id,
    required this.familyName,
    required this.ownerUserId,
    required this.members,
    this.sharedCart = const [],
    this.pendingApprovals = const [],
    this.monthlyBudget = 0.0,
    this.currentMonthSpending = 0.0,
    this.autoApproveUnderLimit = false,
    this.autoApproveThreshold = 200.0,
    this.defaultAddressId,
    this.defaultPaymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the owner member
  FamilyMember? get owner => members.cast<FamilyMember?>().firstWhere(
    (m) => m?.userId == ownerUserId,
    orElse: () => null,
  );

  /// Get active members count
  int get activeMemberCount => members.where((m) => m.isActive).length;

  /// Get shared cart total
  double get sharedCartTotal => sharedCart.fold(
    0.0,
    (total, item) => total + (item.price * item.quantity),
  );

  /// Check if household can afford more spending
  bool canAfford(double amount) {
    if (monthlyBudget <= 0) return true;
    return (currentMonthSpending + amount) <= monthlyBudget;
  }

  factory FamilyGroup.fromMap(Map<String, dynamic> map) {
    return FamilyGroup(
      id: map['id'] ?? '',
      familyName: map['familyName'] ?? '',
      ownerUserId: map['ownerUserId'] ?? '',
      members:
          (map['members'] as List<dynamic>?)
              ?.map(
                (m) =>
                    FamilyMember.fromMap(Map<String, dynamic>.from(m as Map)),
              )
              .toList() ??
          [],
      sharedCart:
          (map['sharedCart'] as List<dynamic>?)
              ?.map(
                (c) =>
                    SharedCartItem.fromMap(Map<String, dynamic>.from(c as Map)),
              )
              .toList() ??
          [],
      pendingApprovals:
          (map['pendingApprovals'] as List<dynamic>?)
              ?.map(
                (a) => FamilyApprovalRequest.fromMap(
                  Map<String, dynamic>.from(a as Map),
                ),
              )
              .toList() ??
          [],
      monthlyBudget: (map['monthlyBudget'] ?? 0.0).toDouble(),
      currentMonthSpending: (map['currentMonthSpending'] ?? 0.0).toDouble(),
      autoApproveUnderLimit: map['autoApproveUnderLimit'] ?? false,
      autoApproveThreshold: (map['autoApproveThreshold'] ?? 200.0).toDouble(),
      defaultAddressId: map['defaultAddressId'],
      defaultPaymentMethod: map['defaultPaymentMethod'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'familyName': familyName,
      'ownerUserId': ownerUserId,
      'members': members.map((m) => m.toMap()).toList(),
      'sharedCart': sharedCart.map((c) => c.toMap()).toList(),
      'pendingApprovals': pendingApprovals.map((a) => a.toMap()).toList(),
      'monthlyBudget': monthlyBudget,
      'currentMonthSpending': currentMonthSpending,
      'autoApproveUnderLimit': autoApproveUnderLimit,
      'autoApproveThreshold': autoApproveThreshold,
      'defaultAddressId': defaultAddressId,
      'defaultPaymentMethod': defaultPaymentMethod,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
