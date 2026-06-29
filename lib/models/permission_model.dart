// ============================================================
//  Permission model — granular RBAC permissions for Fufaji
//
//  Used by RBACService to gate UI actions, routes, and
//  service-layer writes by UserRole (see user_model.dart).
// ============================================================

enum Permission {
  // ---- Catalog / products ----
  viewProducts,
  createProduct,
  editProduct,
  deleteProduct,
  manageCategories,
  adjustStock,
  viewInventoryLogs,

  // ---- Orders ----
  viewOwnOrders,
  viewAllOrders,
  viewBranchOrders,
  createOrder,
  updateOrderStatus,
  cancelOrder,
  refundOrder,
  assignDriver,

  // ---- Delivery ----
  viewAssignedDeliveries,
  updateDeliveryStatus,
  viewAllDeliveries,
  manageDispatch,

  // ---- Wallet / finance ----
  viewOwnWallet,
  adjustCustomerWallet,
  viewFinancialReports,
  manageCoupons,
  setCodLimits,

  // ---- Customers / users ----
  viewCustomerProfiles,
  manageEmployees,
  changeEmployeeRoles,
  viewDeviceManagement,
  approveKyc,

  // ---- Support ----
  viewOwnSupportTickets,
  viewAllSupportTickets,
  assignSupportTickets,
  resolveSupportTickets,

  // ---- Analytics / reporting ----
  viewBranchAnalytics,
  viewVendorAnalytics,
  viewDeliveryAnalytics,
  viewSalesAnalytics,
  exportReports,

  // ---- Reviews / content ----
  viewReviews,
  moderateReviews,

  // ---- Notifications ----
  sendBroadcastNotifications,

  // ---- System / admin ----
  viewAuditLogs,
  manageBranches,
  manageRolesAndPermissions,
  viewHealthDashboard,
  manageSystemSettings,
  accessBackendDiagnostics,
  manageAiAgents,
}
