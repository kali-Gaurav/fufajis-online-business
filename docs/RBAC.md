# Role-Based Access Control (RBAC)

This document describes the permission model implemented in
`lib/models/permission_model.dart` and `lib/services/rbac_service.dart`,
and the business rationale behind each role's access level.

`RBACService.rolePermissions` is the single source of truth. All UI gating
(hiding buttons/screens), route guards (`canAccessRoute`), and service-layer
write checks should call into `RBACService` rather than re-implementing role
checks ad hoc.

## Permission Reference

Permissions are grouped into 10 categories:

**Catalog / Products** — `viewProducts`, `createProduct`, `editProduct`,
`deleteProduct`, `manageCategories`, `adjustStock`, `viewInventoryLogs`

**Orders** — `viewOwnOrders`, `viewAllOrders`, `viewBranchOrders`,
`createOrder`, `updateOrderStatus`, `cancelOrder`, `refundOrder`,
`assignDriver`

**Delivery** — `viewAssignedDeliveries`, `updateDeliveryStatus`,
`viewAllDeliveries`, `manageDispatch`

**Wallet / Finance** — `viewOwnWallet`, `adjustCustomerWallet`,
`viewFinancialReports`, `manageCoupons`, `setCodLimits`

**Customers / Users** — `viewCustomerProfiles`, `manageEmployees`,
`changeEmployeeRoles`, `viewDeviceManagement`, `approveKyc`

**Support** — `viewOwnSupportTickets`, `viewAllSupportTickets`,
`assignSupportTickets`, `resolveSupportTickets`

**Analytics / Reporting** — `viewBranchAnalytics`, `viewVendorAnalytics`,
`viewDeliveryAnalytics`, `viewSalesAnalytics`, `exportReports`

**Reviews / Content** — `viewReviews`, `moderateReviews`

**Notifications** — `sendBroadcastNotifications`

**System / Admin** — `viewAuditLogs`, `manageBranches`,
`manageRolesAndPermissions`, `viewHealthDashboard`, `manageSystemSettings`,
`accessBackendDiagnostics`, `manageAiAgents`

## Permission Matrix by Role

| Role | Permissions | Business Goal |
|---|---|---|
| **customer** | `viewProducts`, `viewOwnOrders`, `createOrder`, `viewOwnWallet`, `viewOwnSupportTickets`, `viewReviews` | Self-service shopping only. Customers can browse, order, manage their own wallet/orders, and raise support tickets — but cannot see other customers' data, pricing internals, or operational tooling. |
| **employee** | `viewProducts`, `createProduct`, `editProduct`, `adjustStock`, `viewInventoryLogs`, `viewBranchOrders`, `createOrder`, `updateOrderStatus`, `viewOwnSupportTickets`, `viewAllSupportTickets`, `resolveSupportTickets`, `viewReviews`, `viewCustomerProfiles` | In-store operations: billing, stock updates, order fulfillment, and customer support at the branch level. Employees can edit/add catalog items and adjust stock directly (subject to the `inventory_change_requests` approval flow for bulk writes — see below), but cannot delete products, manage other staff, or see financial/analytics data. |
| **rider** | `viewAssignedDeliveries`, `updateDeliveryStatus`, `viewOwnOrders`, `viewOwnWallet` | Delivery execution only. Riders see and update only the deliveries assigned to them and manage their own earnings wallet — no visibility into the broader order book or other riders. |
| **dispatcher** | `viewAllDeliveries`, `manageDispatch`, `assignDriver`, `viewBranchOrders`, `updateDeliveryStatus`, `viewDeliveryAnalytics` | Delivery coordination across all riders for a branch: assigning drivers, tracking delivery status, and reviewing delivery performance — without catalog, finance, or HR access. |
| **branchManager** | Broad operational set: full catalog management (`createProduct`, `editProduct`, `deleteProduct`, `manageCategories`, `adjustStock`, `viewInventoryLogs`), full order lifecycle (`viewBranchOrders`, `updateOrderStatus`, `cancelOrder`, `refundOrder`), delivery oversight (`assignDriver`, `viewAllDeliveries`, `manageDispatch`, `updateDeliveryStatus`), staff management (`manageEmployees`, `changeEmployeeRoles`, `viewDeviceManagement`, `approveKyc`), support (`viewAllSupportTickets`, `assignSupportTickets`, `resolveSupportTickets`), analytics/reporting (`viewBranchAnalytics`, `viewVendorAnalytics`, `viewDeliveryAnalytics`, `viewSalesAnalytics`, `exportReports`), content (`viewReviews`, `moderateReviews`), finance ops (`manageCoupons`, `setCodLimits`, `adjustCustomerWallet`), `viewCustomerProfiles`, `sendBroadcastNotifications`, `viewAuditLogs`, `viewHealthDashboard` | Runs a single branch/shop end-to-end: inventory, staff, orders, delivery, support, and branch-level reporting. Deliberately **excludes** `manageRolesAndPermissions`, `manageSystemSettings`, `accessBackendDiagnostics`, and `manageAiAgents` — those remain owner/superAdmin-only to prevent a branch manager from altering global system config or other branches' role structures. |
| **supplier** | `viewProducts`, `createProduct`, `editProduct`, `adjustStock`, `viewInventoryLogs`, `viewBranchOrders`, `updateOrderStatus`, `viewVendorAnalytics`, `viewSalesAnalytics`, `viewReviews` | Vendors manage their own catalog and fulfill orders for items they supply, and can see sales/vendor analytics relevant to their own products — but cannot delete products, manage other users, or access branch-wide finance/support tooling. |
| **owner** | All permissions (`Permission.values.toSet()`) | Full operational and system control across the entire business — every branch, every role, system settings, AI agent management, audit logs, backend diagnostics. |
| **franchiseOwner** | All permissions **except** `manageRolesAndPermissions` and `manageSystemSettings` | Same operational breadth as `owner`, scoped to their own franchise branches. Cannot redefine the global role/permission matrix or change platform-wide system settings — those remain centralized with the primary `owner`/`superAdmin`. |
| **superAdmin** | All permissions (`Permission.values.toSet()`) | Unrestricted platform administrator — same full access as `owner`, intended for platform-level engineering/operations accounts rather than a specific business owner. |

## Route Guards

`RBACService.canAccessRoute(role, route)` checks a route against
`routePermissions`. Routes not listed are unrestricted (any authenticated
role per the router's existing auth guard). Currently gated routes:

| Route | Required permission(s) |
|---|---|
| `/owner/backend-diagnostics` | `accessBackendDiagnostics` |
| `/owner/device-management` | `viewDeviceManagement` |
| `/owner/employees` | `manageEmployees` |
| `/owner/analytics` | `viewBranchAnalytics` OR `viewSalesAnalytics` |
| `/owner/analytics/postgres` | any of `viewSalesAnalytics`, `viewVendorAnalytics`, `viewDeliveryAnalytics`, `viewBranchAnalytics` |
| `/owner/audit-logs` | `viewAuditLogs` |
| `/owner/health` | `viewHealthDashboard` |
| `/owner/mission-control` | `manageAiAgents` |
| `/dispatcher/dashboard` | `manageDispatch` |
| `/rider/deliveries` | `viewAssignedDeliveries` |

As new gated screens are added, add an entry to `routePermissions` rather
than checking `UserRole` directly in widget code.

## Escalation Path: Inventory Change Requests

Although `employee`, `branchManager`, and `supplier` roles hold
`adjustStock`/`editProduct` permissions, **bulk inventory writes do not go
directly to `products`**. Per the standing project requirement (tasks
#116-122), bulk changes are staged in `inventory_change_requests` and only
applied to `products` after an `owner`/`superAdmin` calls `approveRequest`.
This means `adjustStock` grants the ability to *propose* a change and make
small/direct edits through the normal product-edit UI, while large/bulk
query-driven updates are routed through the approval queue regardless of the
requester's permission level — RBAC determines *who can propose*, the
approval flow determines *what gets committed*.

## Adding a New Permission or Role

1. Add the new `Permission` value to `lib/models/permission_model.dart`
   under the appropriate category.
2. Add it to the relevant role sets in `RBACService.rolePermissions`.
3. If it gates a route, add an entry to `RBACService.routePermissions`.
4. Update this document's matrix and route table accordingly.
