import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../services/invoice_service.dart';
import '../../services/storage_service.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/payment_method.dart';
import '../../utils/app_theme.dart';
import '../../constants/order_status.dart';
import '../../utils/monetary_value.dart';

// ---------------------------------------------------------------------------
// Bill item — wraps a ProductModel with a quantity for the current bill
// ---------------------------------------------------------------------------
class _BillItem {
  final ProductModel product;
  int quantity;

  _BillItem({required this.product}) : quantity = 1;

  double get lineTotal => (product.price * quantity).toDouble();
}

// ---------------------------------------------------------------------------
// CashRegisterScreen
// ---------------------------------------------------------------------------
class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _cashGivenCtrl = TextEditingController();
  final StorageService _storage = StorageService();

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  final List<_BillItem> _billItems = [];

  bool _isLoading = true;
  bool _isOnline = true;
  bool _isProcessing = false;
  String? _upiId;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadProducts();
    _loadShopSettings();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _cashGivenCtrl.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── Connectivity ─────────────────────────────────────────────────────
  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
      });
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      });
    } catch (_) {}
  }

  // ── Load products from Hive cache (offline-first) ────────────────────
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      await _storage.init();

      // Try loading from local Hive cache first
      final cached = _storage.get('pos_products_cache');
      if (cached != null && cached is List) {
        final products = cached
            .map((e) => ProductModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }

      // If online, refresh cache from Firestore
      if (_isOnline) {
        final snap = await FirebaseFirestore.instance
            .collection('products')
            .where('isAvailable', isEqualTo: true)
            .orderBy('name')
            .get();
        final products = snap.docs.map((d) => ProductModel.fromMap(d.data())).toList();

        // Cache to Hive for offline use
        await _storage.put('pos_products_cache', products.map((p) => p.toMap()).toList());

        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CashRegister] Error loading products: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Load shop UPI from settings ───────────────────────────────────────
  Future<void> _loadShopSettings() async {
    try {
      if (_isOnline) {
        final doc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('shop_config')
            .get();
        if (doc.exists) {
          setState(() {
            _upiId = doc.data()?['upiId'] as String?;
          });
        }
      } else {
        _upiId = _storage.get('shop_upi_id') as String?;
      }
    } catch (_) {}
  }

  // ── Search ────────────────────────────────────────────────────────────
  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filteredProducts = q.isEmpty
          ? _allProducts
          : _allProducts.where((p) {
              return p.name.toLowerCase().contains(q) ||
                  p.barcode.contains(q) ||
                  p.category.toString().toLowerCase().contains(q);
            }).toList();
    });
  }

  // ── Bill manipulation ────────────────────────────────────────────────
  void _addToBill(ProductModel product) {
    setState(() {
      final existing = _billItems.indexWhere((i) => i.product.id == product.id);
      if (existing >= 0) {
        _billItems[existing].quantity++;
      } else {
        _billItems.add(_BillItem(product: product));
      }
    });
  }

  void _incrementItem(int index) {
    setState(() => _billItems[index].quantity++);
  }

  void _decrementItem(int index) {
    setState(() {
      if (_billItems[index].quantity > 1) {
        _billItems[index].quantity--;
      } else {
        _billItems.removeAt(index);
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _billItems.removeAt(index));
  }

  void _clearBill() {
    setState(() {
      _billItems.clear();
      _cashGivenCtrl.clear();
    });
  }

  // ── Totals ────────────────────────────────────────────────────────────
  double get _totalAmount => _billItems.fold(0.0, (total, item) => total + item.lineTotal);

  // ── Save order to Firestore (or queue if offline) ────────────────────
  Future<OrderModel?> _buildOrder(String paymentMethod) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final now = DateTime.now();
    final orderNumber = 'POS-${now.millisecondsSinceEpoch.toString().substring(6)}';

    final items = _billItems.map((bi) {
      return OrderItem(
        id: bi.product.id,
        productId: bi.product.id,
        productName: bi.product.name,
        productImage: bi.product.imageUrl,
        unit: bi.product.unit,
        quantity: bi.quantity,
        price: bi.product.price,
        totalPrice: MonetaryValue(bi.lineTotal),
      );
    }).toList();

    final order = OrderModel(
      id: 'pos_${now.millisecondsSinceEpoch}',
      orderNumber: orderNumber,
      customerId: user?.id ?? 'walk_in',
      customerName: 'Walk-in Customer',
      customerPhone: '',
      items: items,
      subtotal: MonetaryValue(_totalAmount),
      deliveryCharge: MonetaryValue(0),
      discount: MonetaryValue(0),
      tax: MonetaryValue(0),
      totalAmount: MonetaryValue(_totalAmount),
      paymentMethod: paymentMethod == 'UPI' ? PaymentMethod.upi : PaymentMethod.cod,
      paymentStatus: 'paid',
      status: OrderStatus.delivered,
      deliveryAddress: Address(
        id: 'pos',
        label: 'In-store',
        fullAddress: 'POS Sale',
        village: 'Store',
        landmark: 'Counter',
        pincode: '',
        latitude: 0,
        longitude: 0,
      ),
      createdAt: now,
      updatedAt: now,
      deliveredAt: now,
      shopId: user?.id,
    );

    return order;
  }

  Future<void> _processPayment(String method) async {
    if (_billItems.isEmpty) {
      _showSnack('Bill is empty!');
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final order = await _buildOrder(method);
      if (order == null) {
        _showSnack('Could not create order.');
        setState(() => _isProcessing = false);
        return;
      }

      if (_isOnline) {
        await FirebaseFirestore.instance.collection('orders').doc(order.id).set(order.toMap());
      } else {
        // Offline: cache locally in Hive until connectivity returns
        const pendingKey = 'pending_pos_orders';
        final existing = (_storage.get(pendingKey) as List?) ?? [];
        existing.add(order.toMap());
        await _storage.put(pendingKey, existing);
        _showSnack('Offline: order saved locally, will sync when online.');
      }

      // Print receipt
      try {
        await InvoiceService().generateAndPrintInvoice(order);
      } catch (e) {
        debugPrint('[CashRegister] Print error: $e');
      }

      if (mounted) {
        _showSnack('Payment of ₹${_totalAmount.round()} received!');
        _clearBill();
      }
    } catch (e) {
      debugPrint('[CashRegister] Payment error: $e');
      _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Cash change calculator dialog ─────────────────────────────────────
  void _showCashDialog() {
    _cashGivenCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => AlertDialog(
          title: const Text('Cash Payment', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total: ₹${_totalAmount.round()}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cashGivenCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cash Given by Customer (₹)',
                  prefixText: '₹ ',
                ),
                onChanged: (_) => setS(() {}),
              ),
              const SizedBox(height: 12),
              if (_cashGivenCtrl.text.isNotEmpty) ...[
                Builder(
                  builder: (_) {
                    final given = double.tryParse(_cashGivenCtrl.text) ?? 0;
                    final change = given - _totalAmount;
                    return Column(
                      children: [
                        Text(
                          change >= 0
                              ? 'Change: ₹${change.round()}'
                              : 'Insufficient! Short by ₹${(-change).round()}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: change >= 0 ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final given = double.tryParse(_cashGivenCtrl.text) ?? 0;
                if (given < _totalAmount) {
                  _showSnack('Insufficient cash!');
                  return;
                }
                Navigator.pop(ctx);
                _processPayment('Cash');
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  // ── UPI QR dialog ─────────────────────────────────────────────────────
  void _showUpiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UPI Payment', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${_totalAmount.round()}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (_upiId != null && _upiId!.isNotEmpty) ...[
              const Text('Scan to Pay:', style: TextStyle(color: AppTheme.grey600)),
              const SizedBox(height: 8),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.grey300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code, size: 80, color: AppTheme.grey700),
                      const SizedBox(height: 4),
                      Text(
                        _upiId!,
                        style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Icon(Icons.qr_code, size: 80, color: AppTheme.grey400),
              const Text(
                'UPI ID not configured.\nSet it in Shop Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.grey500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processPayment('UPI');
            },
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey100,
      appBar: AppBar(
        title: const Text('Cash Register', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.white,
        actions: [
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: AppTheme.warning, size: 18),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(color: AppTheme.warning, fontSize: 12)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh products',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + Barcode bar ─────────────────────────────────
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _openBarcodeScanner,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.qr_code_scanner, color: AppTheme.white, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main body: product grid + bill ───────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Product grid
                Expanded(
                  flex: 6,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.ownerAccent))
                      : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No products found.',
                            style: TextStyle(color: AppTheme.grey500),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (ctx, i) => _ProductCard(
                            product: _filteredProducts[i],
                            onTap: () => _addToBill(_filteredProducts[i]),
                          ),
                        ),
                ),

                // Right: Bill
                Container(
                  width: 260,
                  color: AppTheme.white,
                  child: Column(
                    children: [
                      // Bill header
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppTheme.primary,
                        width: double.infinity,
                        child: const Text(
                          'Current Bill',
                          style: TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      // Bill items
                      Expanded(
                        child: _billItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tap products to add',
                                  style: TextStyle(color: AppTheme.grey400),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(0),
                                itemCount: _billItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (ctx, i) => _BillItemRow(
                                  item: _billItems[i],
                                  onIncrement: () => _incrementItem(i),
                                  onDecrement: () => _decrementItem(i),
                                  onRemove: () => _removeItem(i),
                                ),
                              ),
                      ),

                      // Total + buttons
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.white,
                          border: Border(top: BorderSide(color: AppTheme.grey200)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  '₹${_totalAmount.round()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _billItems.isEmpty ? null : _showCashDialog,
                                    icon: const Icon(Icons.money, size: 18),
                                    label: const Text('Cash'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.info,
                                      foregroundColor: AppTheme.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _billItems.isEmpty ? null : _showUpiDialog,
                                    icon: const Icon(Icons.phone_android, size: 18),
                                    label: const Text('UPI'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.info,
                                      foregroundColor: AppTheme.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _billItems.isEmpty || _isProcessing
                                        ? null
                                        : _printBill,
                                    icon: const Icon(Icons.print, size: 18),
                                    label: const Text('Print'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _billItems.isEmpty ? null : _clearBill,
                                    icon: const Icon(Icons.clear_all, size: 18),
                                    label: const Text('Clear'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.error,
                                      side: const BorderSide(color: AppTheme.error),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Processing overlay indicator
          if (_isProcessing)
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.all(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                  ),
                  SizedBox(width: 8),
                  Text('Processing...', style: TextStyle(color: AppTheme.white)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openBarcodeScanner() async {
    // Navigate to the scanner screen in context
    final productId = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _BarcodeScannerPlaceholder()));
    if (productId != null && productId.isNotEmpty) {
      final match = _allProducts.firstWhere(
        (p) => p.barcode == productId || p.id == productId,
        orElse: () => _allProducts.first,
      );
      _addToBill(match);
    }
  }

  Future<void> _printBill() async {
    if (_billItems.isEmpty) return;
    try {
      final order = await _buildOrder('Print');
      if (order != null) {
        await InvoiceService().generateAndPrintInvoice(order);
      }
    } catch (e) {
      _showSnack('Print failed: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Product card widget
// ---------------------------------------------------------------------------
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.shopping_bag, size: 40, color: AppTheme.grey300),
                        )
                      : Container(
                          color: AppTheme.grey100,
                          child: const Center(
                            child: Icon(Icons.shopping_bag, size: 40, color: AppTheme.grey300),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${product.price.toDouble().round()}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(product.unit, style: const TextStyle(fontSize: 10, color: AppTheme.grey500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bill item row widget
// ---------------------------------------------------------------------------
class _BillItemRow extends StatelessWidget {
  final _BillItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _BillItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₹${item.product.price.toDouble().round()} × ${item.quantity} = ₹${item.lineTotal.round()}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _QtyBtn(icon: Icons.remove, onTap: onDecrement, color: AppTheme.error),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              _QtyBtn(icon: Icons.add, onTap: onIncrement, color: AppTheme.info),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 16, color: AppTheme.grey500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 1),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder for barcode scanner — replace with mobile_scanner integration
// ---------------------------------------------------------------------------
class _BarcodeScannerPlaceholder extends StatelessWidget {
  const _BarcodeScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: AppTheme.grey400),
            const SizedBox(height: 16),
            const Text('Point camera at barcode', style: TextStyle(color: AppTheme.grey600)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
