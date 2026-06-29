# Offline Order Queue System - Integration Guide

## Overview

The Offline Order Queue Service provides SQLite-backed persistent storage for orders placed while the app is offline. Orders are automatically synced to Firestore when connectivity is restored.

**Key Features:**
- Local SQLite persistence of offline orders
- Automatic sync when network reconnects
- Exponential backoff retry strategy (1s → 2s → 4s)
- Conflict resolution (server-wins merge strategy)
- Memory-efficient caching
- 7-day auto-cleanup of synced orders
- Observable status for UI integration

## File Structure

```
lib/
├── services/
│   └── offline_order_queue_service.dart    (620+ lines, core service)
├── widgets/
│   └── offline_queue_status_widget.dart    (UI components)
└── providers/
    └── order_provider.dart                 (integration)

test/
└── services/
    └── offline_order_queue_service_test.dart (30 test cases)
```

## Architecture

### SQLite Schema

```sql
CREATE TABLE offline_orders (
  id TEXT PRIMARY KEY,
  order_json TEXT NOT NULL,
  status TEXT DEFAULT 'queued',
  retry_count INTEGER DEFAULT 0,
  last_retry_at INTEGER,
  firestore_id TEXT,
  conflict_resolution_data TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  synced_at INTEGER
)
```

**Fields:**
- `order_json`: Full OrderModel serialized as JSON
- `status`: `queued | syncing | synced | failed | conflicted`
- `retry_count`: Number of sync attempts (max 3)
- `conflict_resolution_data`: Metadata for merge conflicts
- Timestamps in milliseconds since epoch

## Core Methods

### Initialization

```dart
final queueService = OfflineOrderQueueService();
await queueService.init();
```

Automatically:
- Creates offline_orders table if missing
- Loads cache from SQLite
- Starts connectivity listener
- Sets up 5-minute auto-sync timer

### Add Order to Queue

```dart
final orderId = await queueService.addOrderToQueue(order);
```

Used when `isOffline == true` during checkout.

### Get Queued Orders

```dart
final orders = await queueService.getQueuedOrders();
// Returns only 'queued' and 'failed' status orders

final allOrders = await queueService.getAllQueuedOrders();
// Returns all orders regardless of status

final specific = await queueService.getAllQueuedOrders(status: 'synced');
// Filter by status
```

### Sync Orders

```dart
// Manual trigger
final syncedCount = await queueService.syncQueuedOrders();

// Auto-triggered on:
// 1. Network reconnection
// 2. 5-minute timer
// 3. OrderProvider.syncOfflineOrders()
```

**Process:**
1. Mark order status as 'syncing'
2. Check if order exists in Firestore (conflict detection)
3. If conflict: apply server-wins merge strategy
4. If no conflict: upload new order
5. Mark status as 'synced'
6. Update SQLite with sync time

### Retry Failed Orders

```dart
// Single order
final success = await queueService.retryFailedOrder(orderId);

// Auto-retry with exponential backoff:
// Attempt 1: 1s delay → 2s delay → 4s delay
// After 3 attempts: marked as 'failed' permanently
```

### Queue Statistics

```dart
final stats = await queueService.getQueueStats();
print(stats); // QueueStats(queued: 5, failed: 2, synced: 10, size: 125KB)

// Individual counts
print(queueService.queuedCount.value);    // ValueNotifier<int>
print(queueService.failedCount.value);
print(queueService.syncedCount.value);
print(queueService.isSyncing.value);      // ValueNotifier<bool>
print(queueService.lastSyncTime.value);   // ValueNotifier<DateTime?>
print(queueService.lastSyncError.value);  // ValueNotifier<String?>
```

### Cleanup

```dart
// Remove specific order
await queueService.removeFromQueue(orderId);

// Delete orders older than 7 days
await queueService.cleanupOldSyncedOrders();

// Clear all orders (emergency)
final deletedCount = await queueService.clearQueue();

// Dispose service
queueService.dispose();
```

## OrderProvider Integration

### Added Properties

```dart
class OrderProvider with ChangeNotifier {
  final OfflineOrderQueueService _offlineOrderQueue = OfflineOrderQueueService();
  
  // Getters for UI
  int get queuedOrderCount => _offlineOrderQueue.queuedCount.value;
  int get failedOrderCount => _offlineOrderQueue.failedCount.value;
  bool get isSyncingOrders => _offlineOrderQueue.isSyncing.value;
  String? get syncError => _offlineOrderQueue.lastSyncError.value;
  DateTime? get lastQueueSyncTime => _offlineOrderQueue.lastSyncTime.value;
}
```

### Updated createOrder()

When offline:
```dart
if (isOffline) {
  await OfflineManager().queueOrder(newOrder);
  await _offlineOrderQueue.addOrderToQueue(newOrder);  // NEW
  _orders.insert(0, newOrder);
  notifyListeners();
  return newOrder;
}
```

### Manual Sync Trigger

```dart
Future<void> syncOfflineOrders() async {
  await OfflineSyncService().processQueue();
  await _offlineOrderQueue.syncQueuedOrders();  // NEW
  notifyListeners();
}
```

## UI Integration

### 1. Checkout Screen Warning

```dart
// Show banner when offline
if (isOffline) {
  _buildOfflineWarning()
}

Widget _buildOfflineWarning() {
  return const OfflineCheckoutWarning();
  // Shows: "You are offline. Order will sync when online"
}
```

### 2. Orders Screen Status Badge

```dart
// In Orders list
Consumer<OrderProvider>(
  builder: (context, orderProvider, _) {
    return Stack(
      children: [
        // Order list...
        if (orderProvider.queuedOrderCount > 0)
          const OfflineOrderBadge(),
      ],
    );
  },
)
```

### 3. Home Screen Sync Indicator

```dart
// Top banner in home screen
OfflineQueueStatusWidget(
  showDetails: true,
  onRetryTap: () => context.read<OrderProvider>().syncOfflineOrders(),
)
```

### 4. Queue Status Dialog

```dart
// Show on menu tap
showDialog(
  context: context,
  builder: (_) => QueueStatusDialog(
    queueService: OfflineOrderQueueService(),
  ),
)
```

### 5. Sync Progress Overlay

```dart
// During checkout
Stack(
  children: [
    // Checkout form...
    SyncProgressOverlay(
      queueService: OfflineOrderQueueService(),
    ),
  ],
)
```

## Conflict Resolution Strategy

When an order exists in both local queue and Firestore:

```dart
// Server data takes precedence for:
- status
- paymentStatus
- updatedAt

// Local data merged with:
- All local metadata
- Sync timestamp
- Conflict resolution metadata
```

**Example:**
```
Local Order: pending, updatedAt: 10:00
Server Order: confirmed, updatedAt: 10:05

Result: confirmed (server wins), but sync metadata recorded
```

## Retry Logic

### Exponential Backoff

```
Attempt 1: Fail → Wait 1s → Retry
Attempt 2: Fail → Wait 2s → Retry
Attempt 3: Fail → Wait 4s → Retry
Attempt 4: Fail → Marked as 'failed' (manual retry needed)
```

### Manual Retry

User can:
1. Tap "Retry" button in queue status banner
2. Open queue status dialog and retry
3. Manually trigger `orderProvider.syncOfflineOrders()`

## Error Handling

### Network Errors
- Automatically retried with exponential backoff
- Last error stored in `lastSyncError` ValueNotifier
- UI shows error message for user awareness

### Conflict Errors
- Server data wins (ACID guarantees)
- Conflict metadata stored for audit
- Order marked as synced (data not lost)

### Storage Errors
- SQLite exceptions logged
- Error returned to caller
- Order remains in queue for retry

## Memory Efficiency

### Caching Strategy
```dart
// In-memory cache of queue metadata only
Map<String, Map<String, dynamic>> _queueCache = {};

// Full OrderModel loaded only when needed
final order = await _getOrderFromQueue(orderId);
```

### Cleanup Strategy
```dart
// Auto-cleanup runs:
// 1. On init
// 2. After sync
// 3. Removes orders synced > 7 days ago
// 4. Prevents unbounded table growth
```

## Performance Characteristics

### Database Queries
- `getQueuedOrders()`: O(n) where n = queued + failed
- `getQueueStats()`: O(1) with index on status
- `_refreshCounts()`: O(n) aggregation
- `cleanupOldSyncedOrders()`: O(n) with timestamp index

### Memory Usage
- Metadata cache: ~100 bytes per order
- Full order load on demand
- No all-in-memory queue

### Sync Throughput
- Parallel sync: One order at a time
- Network-bound (not CPU-bound)
- Typical: 3-5 orders per sync session

## Testing

### Run Tests
```bash
flutter test test/services/offline_order_queue_service_test.dart
```

### Test Coverage (30 cases)
- Initialization & setup
- Add/remove operations
- Sync success/failure
- Conflict resolution
- Retry backoff logic
- Queue statistics
- Data persistence
- Special characters
- Large payloads
- Payment methods
- Order status transitions
- Cleanup behavior
- Concurrent operations

## Troubleshooting

### Orders Not Syncing
1. Check connectivity: Is device actually online?
2. Check `queueService.lastSyncError.value`
3. Verify Firestore permissions for 'orders' collection
4. Check SQLite database: `offline_orders` table exists?

### High Memory Usage
1. Check queue size: `getQueueStats().totalSize`
2. Run cleanup: `cleanupOldSyncedOrders()`
3. Monitor timer: Auto-sync should be 5 minutes apart

### Duplicate Orders
1. Firestore conflict resolution works correctly
2. Server-wins strategy prevents duplicates
3. Check order.cartHash for idempotency

## Configuration

### Backoff Settings
```dart
static const Duration _initialBackoff = Duration(seconds: 1);
static const int _maxRetries = 3;
```

### Auto-Sync Timer
```dart
Timer.periodic(
  const Duration(minutes: 5),
  (_) => _autoSyncIfOnline(),
)
```

### Cleanup Period
```dart
DateTime.now().subtract(const Duration(days: 7))
```

## Security Considerations

1. **Data Integrity**: SQLite transactions ensure consistency
2. **Privacy**: Order data stored locally, encrypted with device storage
3. **Sync Security**: HTTPS to Firestore, signed requests
4. **Conflict Resolution**: Server-authoritative (no data loss)

## Future Enhancements

- [ ] Batch sync optimization (10+ orders)
- [ ] Compression for large payloads
- [ ] Pause/resume sync functionality
- [ ] Per-order retry scheduling
- [ ] Sync analytics and metrics
- [ ] Custom conflict resolution hooks

## API Reference

### OfflineOrderQueueService

```dart
// Lifecycle
Future<void> init()
void dispose()

// Queue Operations
Future<String> addOrderToQueue(OrderModel order)
Future<List<OrderModel>> getQueuedOrders()
Future<List<OrderModel>> getAllQueuedOrders({String? status})
Future<int> syncQueuedOrders()
Future<bool> removeFromQueue(String orderId)
Future<bool> retryFailedOrder(String orderId)

// Statistics
Future<QueueStats> getQueueStats()
Future<int> cleanupOldSyncedOrders()
Future<int> clearQueue()

// Observable State
ValueNotifier<int> queuedCount
ValueNotifier<int> failedCount
ValueNotifier<int> syncedCount
ValueNotifier<bool> isSyncing
ValueNotifier<String?> lastSyncError
ValueNotifier<DateTime?> lastSyncTime
```

### QueueStats

```dart
class QueueStats {
  final int queuedCount;
  final int failedCount;
  final int syncedCount;
  final int totalSize;
  final DateTime? lastSyncTime;
  
  int get totalCount
  bool get hasPendingOrders
}
```

## Support

For issues or questions:
1. Check test file for usage examples
2. Review integration guide in OrderProvider
3. Inspect SQLite database: `offline_orders` table
4. Enable debug logging: `debugPrint()` statements

---

**Last Updated:** June 2026
**Version:** 1.0.0
**Status:** Production Ready
