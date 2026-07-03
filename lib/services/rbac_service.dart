// ============================================================
//  RBACService — Role-Based Access Control
//
//  Maps each UserRole (see models/user_model.dart) to the set
//  of granular Permissions it holds. Use hasPermission() to
//  gate UI actions, route guards, and service-layer writes.
// ============================================================

import '../models/user_model.dart';
import '../models/permission_model.dart';

class RBACService {
  static final RBACService _instance = RBACService._internal();
  factory RBACService() => _instance;
  RBACService._internal();

  /// Source of truth: role -> permission set.
  static final Map<UserRole, Set<Permission>> rolePermissions = {
    // ------------------------------------------------------
    // Customer — self-service only
    // ------------------------------------------------------
    UserRole.customer: {
      Permission.viewProducts,
      Permission.viewOwnOrders,
      Permission.createOrder,
      Permission.viewOwnWallet,
      Permission.viewOwnSupportTickets,
      Permission.viewReviews,
    },

    // ------------------------------------------------------
    // Employee — in-store operations (billing, stock, support)
    // ------------------------------------------------------
    UserRole.employee: {
      Permission.viewProducts,
      Permission.createProduct,
      Permission.editProduct,
      Permission.adjustStock,
      Permission.viewInventoryLogs,
      Permission.viewBranchOrders,
      Permission.createOrder,
      Permission.updateOrderStatus,
      Permission.viewOwnSupportTickets,
      Permission.viewAllSupportTickets,
      Permission.resolveSupportTickets,
      Permission.viewReviews,
      Permission.viewCustomerProfiles,
    },

    // ------------------------------------------------------
    // Rider — delivery execution
    // ------------------------------------------------------
    UserRole.rider: {
      Permission.viewAssignedDeliveries,
      Permission.updateDeliveryStatus,
      Permission.viewOwnOrders,
      Permission.viewOwnWallet,
    },

    // ------------------------------------------------------
    // Dispatcher — delivery coordination
    // ------------------------------------------------------
    UserRole.dispatcher: {
      Permission.viewAllDeliveries,
      Permission.manageDispatch,
      Permission.assignDriver,
      Permission.viewBranchOrders,
      Permission.updateDeliveryStatus,
      Permission.viewDeliveryAnalytics,
    },

    // ------------------------------------------------------
    // Branch Manager — runs a single branch/shop
    // ------------------------------------------------------
    UserRole.branchManager: {
      Permission.viewProducts,
      Permission.createProduct,
      Permission.editProduct,
      Permission.deleteProduct,
      Permission.manageCategories,
      Permission.adjustStock,
      Permission.viewInventoryLogs,
      Permission.viewBranchOrders,
      Permission.updateOrderStatus,
      Permission.cancelOrder,
      Permission.refundOrder,
      Permission.assignDriver,
      Permission.viewAllDeliveries,
      Permission.manageDispatch,
      Permission.updateDeliveryStatus,
      Permission.manageEmployees,
      Permission.changeEmployeeRoles,
      Permission.viewDeviceManagement,
      Permission.approveKyc,
      Permission.viewAllSupportTickets,
      Permission.assignSupportTickets,
      Permission.resolveSupportTickets,
      Permission.viewBranchAnalytics,
      Permission.viewVendorAnalytics,
      Permission.viewDeliveryAnalytics,
      Permission.viewSalesAnalytics,
      Permission.exportReports,
      Permission.viewReviews,
      Permission.moderateReviews,
      Permission.manageCoupons,
      Permission.setCodLimits,
      Permission.adjustCustomerWallet,
      Permission.viewCustomerProfiles,
      Permission.sendBroadcastNotifications,
      Permission.viewAuditLogs,
      Permission.viewHealthDashboard,
    },

    // ------------------------------------------------------
    // Supplier / vendor — manages own catalog + fulfillment
    // ------------------------------------------------------
    UserRole.supplier: {
      Permission.viewProducts,
      Permission.createProduct,
      Permission.editProduct,
      Permission.adjustStock,
      Permission.viewInventoryLogs,
      Permission.viewBranchOrders,
      Permission.updateOrderStatus,
      Permission.viewVendorAnalytics,
      Permission.viewSalesAnalytics,
      Permission.viewReviews,
    },

    // ------------------------------------------------------
    // Owner — full operational control across the business
    // ------------------------------------------------------
    UserRole.owner: Permission.values.toSet(),

    // ------------------------------------------------------
    // Franchise Owner — same as owner, scoped to their branches
    // ------------------------------------------------------
    UserRole.franchiseOwner: Permission.values.toSet()
      ..remove(Permission.manageRolesAndPermissions)
      ..remove(Permission.manageSystemSettings),

    // ------------------------------------------------------
    // Super Admin — unrestricted
    // ------------------------------------------------------
    UserRole.superAdmin: Permission.values.toSet(),
  };

  /// Returns true if [role] has [permission].
  bool hasPermission(UserRole role, Permission permission) {
    return rolePermissions[role]?.contains(permission) ?? false;
  }

  /// Returns true if [role] has ANY of [permissions].
  bool hasAnyPermission(UserRole role, List<Permission> permissions) {
    final granted = rolePermissions[role] ?? const {};
    return permissions.any(granted.contains);
  }

  /// Returns true if [role] has ALL of [permissions].
  bool hasAllPermissions(UserRole role, List<Permission> permissions) {
    final granted = rolePermissions[role] ?? const {};
    return permissions.every(granted.contains);
  }

  /// All permissions granted to [role].
  Set<Permission> getPermissions(UserRole role) {
    return rolePermissions[role] ?? const {};
  }

  /// Route-guard helper: does [role] have at least one of the
  /// permissions required to access [route]?
  bool canAccessRoute(UserRole role, String route) {
    final required = routePermissions[route];
    if (required == null || required.isEmpty) return true; // unrestricted route
    return hasAnyPermission(role, required);
  }

  /// Maps app routes to the permission(s) required to view them.
  /// Add entries here as new gated screens are introduced.
  static final Map<String, List<Permission>> routePermissions = {
    '/owner/backend-diagnostics': [Permission.accessBackendDiagnostics],
    '/owner/device-management': [Permission.viewDeviceManagement],
    '/owner/employees': [Permission.manageEmployees],
    '/owner/analytics': [Permission.viewBranchAnalytics, Permission.viewSalesAnalytics],
    '/owner/analytics/postgres': [
      Permission.viewSalesAnalytics,
      Permission.viewVendorAnalytics,
      Permission.viewDeliveryAnalytics,
      Permission.viewBranchAnalytics,
    ],
    '/owner/audit-logs': [Permission.viewAuditLogs],
    '/owner/health': [Permission.viewHealthDashboard],
    '/owner/mission-control': [Permission.manageAiAgents],
    '/dispatcher/dashboard': [Permission.manageDispatch],
    '/rider/deliveries': [Permission.viewAssignedDeliveries],
  };
}
