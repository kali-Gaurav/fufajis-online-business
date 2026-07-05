# Provider Lazy Loading Audit (5-Point Checklist)

This audit ensures that all `ChangeNotifierProvider` and other state managers are initialized without blocking the main UI thread (preventing UI jank) and without throwing "context accessed across async gaps" exceptions.

## Checklist

### 1. [ ] Post-Frame Initialization
**Rule:** Any heavy asynchronous operation during app startup (e.g., loading SharedPreferences, fetching initial data from SQLite) must not block `runApp()`.
**Verification:**
- Check `main.dart`: Does `CartProvider()..loadCart()` block? It shouldn't. It should ideally be `CartProvider()..loadCartAsync()` leveraging `WidgetsBinding.instance.addPostFrameCallback`.

### 2. [ ] Context-Free State Mutations
**Rule:** Providers should not require `BuildContext` to perform internal state updates unless they are navigating or showing dialogs.
**Verification:**
- Ensure methods like `loadCart()`, `syncToCloud()`, and `addToCart()` in `CartProvider` do not accept or use `BuildContext`.

### 3. [ ] Avoid Awaiting Inside `create`
**Rule:** Provider `create` functions must be synchronous.
**Verification:**
- Check `MultiProvider` in `main.dart`. Ensure no `create: (_) async => ...` is used.
- Any async setup should happen inside the provider itself, which sets a `bool isLoading = true; notifyListeners();` while it works.

### 4. [ ] Dependency Ordering (ProxyProviders)
**Rule:** If a provider depends on another provider (e.g., `OrderProvider` depending on `AuthProvider` for the user ID), it must use `ProxyProvider` or `ChangeNotifierProxyProvider`.
**Verification:**
- Ensure `CartProvider` does not try to read `AuthProvider` directly via a global variable. It should either receive the `uid` as an argument (e.g. `mergeCartOnLogin(uid)`), or use a ProxyProvider.

### 5. [ ] AsyncBuilder UI Handling
**Rule:** The UI must gracefully handle the `isLoading` state while the providers lazily load their data.
**Verification:**
- Check `home_screen.dart` or `splash_screen.dart`. Does it show a loading spinner if `cartProvider.isLoading == true`?

## Conclusion
Once all 5 items are checked, the app is resilient against startup crashes and UI jank.
