# Provider Refactor Guide — Phase 2

## Overview

This guide explains the new provider architecture and how to refactor remaining providers.

**Goal:** Enforce strict separation between:
- **PostgreSQL** = Source of Truth (transactional, consistent)
- **Firestore** = Read Cache (eventual consistency, real-time)
- **Backend API** = Gatekeeper (validates, enforces business rules)
- **Flutter** = UI Layer (never writes directly to databases)

---

## Architecture Pattern

### Old (❌ Wrong)

```
Flutter Screen
    ↓
Provider
    ↓
Firestore (direct write/read)
```

**Problems:**
- Multiple data sources
- Stale reads
- Race conditions
- Overselling possible
- No audit trail

### New (✅ Correct)

```
Flutter Screen
    ↓
Provider (state management, notification)
    ↓
Repository (data handling, caching, validation)
    ↓
API Service (HTTP calls, auth, error handling)
    ↓
Backend API (Node.js / Render)
    ↓
PostgreSQL (atomic transactions, locks, audit logs)
    ↓
Firestore (synced via Cloud Functions, eventual consistency)
```

**Benefits:**
- Single source of truth
- Atomic transactions
- Inventory locks prevent overselling
- Complete audit trail
- Frontend/backend separation

---

## Files Created (Admin as Template)

### 1. `lib/repositories/admin_repository.dart`

**Purpose:** Handle data logic, validation, error handling.

**Key Methods:**
- `fetchDashboardMetrics()` → `GET /admin/dashboard/metrics`
- `createProduct(data)` → `POST /admin/products`
- `updateProduct(id, updates)` → `PUT /admin/products/:id`
- `adjustInventory(...)` → `POST /admin/inventory/adjust` (atomic)
- `packOrder(id, items)` → `POST /admin/orders/:id/pack` (atomic)

**Never reads from Firestore directly.**
**Never writes directly to Firestore.**

### 2. `lib/services/admin_api_service.dart`

**Purpose:** Make HTTP calls to backend, handle auth, errors, timeouts.

**Key Methods:**
- `_request()` — handles all HTTP logic
- `getDashboardMetrics()` → GET /admin/dashboard/metrics
- `getProducts()` → GET /admin/products
- `createProduct()` → POST /admin/products
- `adjustInventory()` → POST /admin/inventory/adjust
- `packOrder()` → POST /admin/orders/:id/pack

**Responsibilities:**
- Firebase auth token
- HTTP headers
- Timeout handling
- Error parsing

### 3. `lib/providers/admin_provider_v2.dart`

**Purpose:** UI state management.

**Key Methods:**
- `loadDashboardMetrics()` — fetch + notify UI
- `loadProducts()` — paginated product list
- `createProduct()` — create + update local list
- `updateProduct()` — update + refresh UI
- `deleteProduct()` — delete + remove from list
- `adjustInventory()` — atomic stock adjustment
- `packOrder()` — atomic order packing

**Never queries Firestore.**
**Never writes directly to databases.**

---

## How to Refactor Other Providers

### Step 1: Create Repository

**File:** `lib/repositories/product_repository.dart`

Template:

```dart
import '../services/product_api_service.dart';

class ProductRepository {
  final ProductApiService _apiService;

  ProductRepository({required ProductApiService apiService}) : _apiService = apiService;

  /// Method 1: Fetch products
  Future<Map<String, dynamic>> fetchProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
  }) async {
    try {
      return await _apiService.getProducts(
        page: page,
        limit: limit,
        categoryId: categoryId,
      );
    } catch (e) {
      throw ProductRepositoryException('Failed to fetch products: $e');
    }
  }

  /// Method 2: Create product
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    // Validate
    if (data['name'].isEmpty) throw ProductRepositoryException('Name required');
    if (data['price'] <= 0) throw ProductRepositoryException('Price must be > 0');

    try {
      return await _apiService.createProduct(data);
    } catch (e) {
      throw ProductRepositoryException('Failed to create product: $e');
    }
  }

  // ... other methods
}

class ProductRepositoryException implements Exception {
  final String message;
  ProductRepositoryException(this.message);
  @override
  String toString() => 'ProductRepositoryException: $message';
}
```

### Step 2: Create API Service

**File:** `lib/services/product_api_service.dart`

Template:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class ProductApiService {
  static const String _baseUrl = 'https://fufaji-backend.onrender.com/api/products';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get ID token
  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw ProductApiException('User not authenticated');
    final idToken = await user.getIdToken();
    if (idToken == null) throw ProductApiException('Failed to get ID token');
    return idToken;
  }

  /// Generic request handler
  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final idToken = await _getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      };

      Uri url = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) url = url.replace(queryParameters: queryParams);

      late http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: json.encode(body ?? {}));
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: json.encode(body ?? {}));
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw ProductApiException('Unauthorized');
      } else {
        throw ProductApiException('API error: ${response.statusCode}');
      }
    } on ProductApiException rethrow;
    catch (e) {
      throw ProductApiException('API call failed: $e');
    }
  }

  /// GET /products
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (categoryId != null) 'category': categoryId,
    };
    return await _request(method: 'GET', endpoint: '', queryParams: queryParams);
  }

  /// POST /products
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    return await _request(method: 'POST', endpoint: '', body: data);
  }

  // ... other methods
}

class ProductApiException implements Exception {
  final String message;
  ProductApiException(this.message);
  @override
  String toString() => 'ProductApiException: $message';
}
```

### Step 3: Create/Refactor Provider

**File:** `lib/providers/product_provider_v2.dart`

Template:

```dart
import 'package:flutter/foundation.dart';
import '../repositories/product_repository.dart';
import '../services/product_api_service.dart';
import '../models/product_model.dart';

class ProductProvider with ChangeNotifier {
  final ProductRepository _repository;

  ProductProvider({required ProductRepository repository}) : _repository = repository;

  // State
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _error = '';
  String get error => _error;

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  // Methods
  Future<void> loadProducts({int page = 1, String? categoryId}) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _repository.fetchProducts(page: page, categoryId: categoryId);
      final List<dynamic> productsList = result['products'] ?? [];
      _products = productsList
          .map((p) => ProductModel.fromMap(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProductModel?> createProduct(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final result = await _repository.createProduct(data);
      final product = ProductModel.fromMap(result);
      _products.add(product);
      return product;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}
```

---

## Providers to Refactor (in order)

### Priority 1: Critical (affects data integrity)
1. **InventoryProvider** — stock management must be atomic
2. **OrderProvider** — order status affects fulfillment
3. **PaymentProvider** — financial data must be accurate

### Priority 2: Important (affects operations)
4. **EmployeeProvider** — operational data
5. **DeliveryProvider** — delivery operations

### Priority 3: Nice-to-have (supportive data)
6. **ProductProvider** (already started)
7. **ChatProvider** — can stay with Firestore (real-time ok)
8. **NotificationProvider** — can stay with Firestore (real-time ok)

---

## Integration Checklist

### For Each Provider Refactored

- [ ] Create `{Entity}Repository.dart`
- [ ] Create `{Entity}ApiService.dart`
- [ ] Create/Refactor `{Entity}Provider.dart` (v2)
- [ ] Add Provider to MultiProvider in `main.dart`:
  ```dart
  ChangeNotifierProvider(
    create: (_) => InventoryProvider(
      repository: InventoryRepository(
        apiService: InventoryApiService(),
      ),
    ),
  ),
  ```
- [ ] Update screens to use new provider (no more Firestore reads)
- [ ] Test: Create/Update/Delete operations
- [ ] Test: Verify data syncs to Firestore (eventually)
- [ ] Test: Concurrent operations don't cause race conditions

---

## Backend Requirements

Each provider needs corresponding backend endpoints:

### InventoryProvider needs:
- `GET /admin/inventory`
- `POST /admin/inventory/adjust` (MUST be atomic)

### OrderProvider needs:
- `GET /admin/orders`
- `POST /admin/orders/:id/pack` (MUST be atomic)
- `POST /admin/orders/:id/cancel`

### PaymentProvider needs:
- `GET /admin/payments`
- `POST /admin/payments/:id/refund`

### EmployeeProvider needs:
- `GET /admin/employees`
- `POST /admin/employees`
- `PUT /admin/employees/:id`

### DeliveryProvider needs:
- `GET /admin/deliveries`
- `POST /admin/deliveries/:id/assign`

---

## Data Flow Example

### Creating a Product

```
1. Owner taps "Add Product" button
2. ProductsManagementScreen calls:
   context.read<ProductProvider>().createProduct({...})

3. ProductProvider calls:
   _repository.createProduct(data)

4. ProductRepository:
   - Validates: name, price > 0, etc.
   - Calls _apiService.createProduct(data)

5. ProductApiService:
   - Gets Firebase ID token
   - Makes POST /admin/products
   - Returns parsed response

6. Backend (Render):
   - Validates again
   - Inserts into PostgreSQL
   - Triggers Cloud Function

7. Cloud Function:
   - Syncs to Firestore
   - Notifies real-time listeners

8. ProductProvider:
   - Adds product to local list
   - Calls notifyListeners()
   - UI rebuilds

9. Customer App:
   - Listens to Firestore products collection
   - Sees new product in real-time
```

---

## Testing Each Provider

### Unit Tests

```dart
test('ProductRepository.createProduct validates price', () async {
  final repo = ProductRepository(apiService: mockApiService);

  expect(
    () => repo.createProduct({'name': 'Test', 'price': 0}),
    throwsA(isA<ProductRepositoryException>()),
  );
});
```

### Integration Tests

```dart
test('InventoryProvider.adjustInventory updates stock atomically', () async {
  // 1. Set initial stock = 10
  // 2. Employee A packs 6
  // 3. Employee B packs 5 (should fail or get partial)
  // 4. Verify total stock = 4, no overselling
});
```

---

## Final Note

**This refactor is critical.**

Current architecture (Firestore direct reads) can cause:
- ❌ Overselling (customer sees old stock)
- ❌ Double-packing (employee packs same item twice)
- ❌ Price mismatches (customer charged different price)
- ❌ Lost inventory (no audit trail)

Refactored architecture prevents all of these via:
- ✅ PostgreSQL transaction locks
- ✅ Backend validation before writes
- ✅ Atomic operations
- ✅ Complete audit logs
- ✅ Firestore eventual consistency cache

**Do not ship without this refactor.**
