# Unified Packing Service API

**Single Source of Truth**: `PackingWorkflowService`  
**Collection**: `fulfillment_tasks` (NOT `fulfillment_tasks_v2`)  
**Status Values**: `new`, `assigned`, `picking`, `quality_check`, `verified`, `completed`, `rejected`

---

## Quick Reference

### Import
```dart
import 'package:fufaji_online_business/services/packing_workflow_service.dart';

final packing = PackingWorkflowService();
```

### Workflow

```
CREATE
  ↓
ASSIGN to employee
  ↓
PICK items
  ↓
REQUEST QC
  ↓
VERIFY (or REJECT)
  ↓
COMPLETE (hand off to delivery)
```

---

## API Methods

### 1. CREATE FULFILLMENT TASK

**When**: Order is confirmed and ready for packing

```dart
final task = await packing.createFulfillmentTask(
  orderId: 'order_123',
  shopId: 'shop_456',
  branchId: 'branch_789',
  items: [
    {
      'id': 'item_1',
      'productId': 'prod_123',
      'productName': 'Widget A',
      'quantity': 2,
      'unit': 'pcs',
    },
    {
      'id': 'item_2',
      'productId': 'prod_456',
      'productName': 'Widget B',
      'quantity': 1,
      'unit': 'box',
    },
  ],
);

// Returns:
// {
//   'id': 'task_xyz',
//   'status': 'new',
//   'createdAt': Timestamp,
//   'itemCount': 2,
//   ...
// }
```

---

### 2. ASSIGN TO EMPLOYEE

**When**: Task is ready to be worked on

```dart
await packing.assignToEmployee(
  taskId: 'task_xyz',
  employeeId: 'emp_123',
  employeeName: 'John Doe',
);

// Task status: new → assigned
// Employee is notified via NotificationService
```

---

### 3. MARK ITEM PICKED

**When**: Employee picks an item from shelf (with optional batch/expiry)

```dart
await packing.markItemPicked(
  taskId: 'task_xyz',
  itemId: 'item_1',
  quantity: 2,
  batchNumber: 'BATCH-2026-001',
  expiryDate: '2026-12-31',
);

// Auto-transitions task:
// - First pick: assigned → picking
// - All items picked: picking → quality_check
```

---

### 4. REQUEST QUALITY CHECK

**When**: All items have been picked

```dart
await packing.requestQualityCheck('task_xyz');

// Task status: picking → quality_check
// QC team is notified
```

---

### 5. VERIFY ITEMS (PASSED QC)

**When**: QC inspector approves the packing

```dart
await packing.verifyItems(
  taskId: 'task_xyz',
  verifiedBy: 'qc_inspector_123',
  notes: 'All items counted and verified',
);

// Task status: quality_check → verified
// Employee is notified that packing passed
```

---

### 6. REJECT PACKING (FAILED QC)

**When**: QC finds issues (missing items, damage, etc.)

```dart
await packing.rejectPacking(
  taskId: 'task_xyz',
  rejectionReason: 'Item missing from order - Widget B not found',
  rejectedBy: 'qc_inspector_123',
);

// Task status: quality_check → rejected
// Items are reset (picked/verified cleared)
// Employee is notified to redo
```

---

### 7. MARK COMPLETED (HAND OFF TO DELIVERY)

**When**: Packing is verified and ready for shipment

```dart
await packing.markCompleted('task_xyz');

// Task status: verified → completed
// Order status: → packed
// Delivery system creates delivery task
```

---

## QUERIES

### Get All Tasks

```dart
// Get tasks by status
final newTasks = await packing.getTasksByStatus('new');
final inProgressTasks = await packing.getTasksByStatus('assigned');
final completedTasks = await packing.getTasksByStatus('completed');
```

### Get Employee Tasks

```dart
final employeeTasks = await packing.getEmployeeTasks('emp_123');
// Returns: tasks with status in [assigned, picking, quality_check]
```

### Get Single Task

```dart
final task = await packing.getTask('task_xyz');
// Returns: full task data with status history
```

### Get Order's Fulfillment Task

```dart
final task = await packing.getOrderFulfillmentTask('order_123');
// Returns: the fulfillment task for this order
```

### Get Shop Tasks

```dart
final shopTasks = await packing.getShopTasks(
  'shop_456',
  statusFilter: 'assigned', // optional
  limit: 50,
);
```

---

## STATE MACHINE

```
             ┌─────────┐
             │   new   │
             └────┬────┘
                  │
                  ↓
           ┌─────────────┐
           │  assigned   │
           └────┬────────┘
                │
         ┌──────┴──────┐
         ↓             ↓
    ┌────────┐  ┌──────────┐
    │ picking│  │ rejected  │
    └────┬───┘  └────┬─────┘
         │           │
         └──────┬────┘  (reassign)
                ↓
        ┌──────────────┐
        │quality_check │
        └────┬────────┘
             │
        ┌────┴────┐
        ↓         ↓
    ┌────────┐┌──────────┐
    │verified││ rejected  │
    └────┬───┘└────┬─────┘
         │         │
         └────┬────┘  (reassign)
              ↓
         ┌──────────┐
         │completed │ (TERMINAL)
         └──────────┘
```

### Valid Transitions

```dart
// From 'new'
new → assigned

// From 'assigned'
assigned → picking
assigned → rejected

// From 'picking'
picking → quality_check
picking → rejected

// From 'quality_check'
quality_check → verified
quality_check → rejected

// From 'verified'
verified → completed

// From 'rejected'
rejected → assigned  // Reassign for rework

// From 'completed'
// No transitions (terminal state)
```

---

## ERROR HANDLING

### Invalid Transition

```dart
try {
  // Trying to verify while still picking
  await packing.verifyItems(taskId: 'task_xyz');
} on Exception catch (e) {
  // Exception: Invalid transition: picking → verified for task task_xyz
}
```

### Task Not Found

```dart
try {
  await packing.getTask('nonexistent_task');
} on Exception catch (e) {
  // Exception: Task not found: nonexistent_task
}
```

### Validation Error

```dart
try {
  // Trying to complete without all items verified
  await packing.completePacking(taskId: 'task_xyz');
} on Exception catch (e) {
  // Exception: Cannot complete: 2 items not verified
}
```

---

## FIRESTORE STRUCTURE

### Document: `fulfillment_tasks/{taskId}`

```json
{
  "id": "task_xyz",
  "orderId": "order_123",
  "shopId": "shop_456",
  "branchId": "branch_789",
  "status": "quality_check",
  "items": [
    {
      "id": "item_1",
      "productId": "prod_123",
      "productName": "Widget A",
      "quantity": 2,
      "picked": true,
      "pickedAt": "2026-06-23T10:30:00Z",
      "verified": false
    }
  ],
  "assignedToEmployeeId": "emp_123",
  "assignedToEmployeeName": "John Doe",
  "assignedAt": "2026-06-23T09:00:00Z",
  "pickedItems": [
    {
      "itemId": "item_1",
      "pickedAt": "2026-06-23T10:30:00Z",
      "notes": "Found on shelf B3"
    }
  ],
  "verifiedItems": [],
  "createdAt": "2026-06-23T08:00:00Z",
  "updatedAt": "2026-06-23T10:35:00Z",
  "statusHistory": [
    {
      "status": "new",
      "timestamp": "2026-06-23T08:00:00Z",
      "reason": "task_created"
    },
    {
      "status": "assigned",
      "timestamp": "2026-06-23T09:00:00Z",
      "reason": "assigned_to_employee"
    },
    {
      "status": "picking",
      "timestamp": "2026-06-23T09:05:00Z",
      "reason": "started_picking"
    },
    {
      "status": "quality_check",
      "timestamp": "2026-06-23T10:35:00Z",
      "reason": "all_items_picked"
    }
  ]
}
```

---

## INTEGRATION POINTS

### Order Creation
```dart
// When order is confirmed (payment received)
final order = await orderService.confirmOrder(orderId: 'order_123');
await packing.createFulfillmentTask(
  orderId: order.id,
  shopId: order.shopId,
  branchId: order.branchId,
  items: order.items,
);
```

### Delivery Handoff
```dart
// When packing is complete
await packing.markCompleted('task_xyz');
// Automatically creates delivery task:
// DeliveryWorkflowService.createDeliveryTask(orderId: '...')
```

### Inventory Tracking
```dart
// Stock deduction happens on verification
await packing.verifyItems(taskId: 'task_xyz');
// InventoryService.deductStock(productId, quantity) is called
```

---

## COMMON FLOWS

### Success Flow
```
Create → Assign → Pick All → QC Request → Verify → Complete
```

### Rejection Flow
```
Create → Assign → Pick Some → QC Request → Reject
  → Reset To Assigned → Pick All → QC Request → Verify → Complete
```

### Multi-Attempt Flow
```
Create → Assign → Pick → QC → Reject → Assign → Pick → QC → Reject → ...
         → Assign → Pick → QC → Verify → Complete
```

---

## MIGRATION FROM V2

**Do NOT use**:
- `PackingService.getUnassignedTasksV2()`
- `PackingService.markItemPackedV2()`
- `PackingService.completePackingV2()`

**These are deprecated** and will return empty results.

**Use instead**:
- `PackingWorkflowService.getTasksByStatus('new')`
- `PackingWorkflowService.markItemPicked()`
- `PackingWorkflowService.markCompleted()`

---

## TESTING

### Unit Test Template
```dart
test('Complete packing workflow', () async {
  final packing = PackingWorkflowService();
  
  // Create
  final task = await packing.createFulfillmentTask(...);
  expect(task['status'], equals('new'));
  
  // Assign
  await packing.assignToEmployee(...);
  final assigned = await packing.getTask(task['id']);
  expect(assigned['status'], equals('assigned'));
  
  // Pick
  await packing.markItemPicked(...);
  
  // QC
  await packing.requestQualityCheck(task['id']);
  final qc = await packing.getTask(task['id']);
  expect(qc['status'], equals('quality_check'));
  
  // Verify
  await packing.verifyItems(...);
  
  // Complete
  await packing.markCompleted(task['id']);
  final completed = await packing.getTask(task['id']);
  expect(completed['status'], equals('completed'));
});
```

---

**Last Updated**: 2026-06-23  
**Service**: Unified Packing/Fulfillment  
**Collection**: `fulfillment_tasks`  
**Status**: Production Ready
