import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/weight_verification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../models/product_batch_model.dart';
import '../../models/product_model.dart';
import '../../utils/app_theme.dart';
import '../../services/printer_service.dart';
import '../../widgets/employee/printer_select_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dispatch_scanner_screen.dart';
import '../../services/smart_scan_service.dart';
import '../../widgets/scan_qr_widget.dart';
import '../../services/presence_service.dart';
import '../../constants/order_status.dart';
import '../../services/realtime_database_service.dart';
import '../../services/api_client.dart';

import '../../widgets/common/fj_button.dart';
import '../../widgets/common/fj_card.dart';

class OrderPackingScreen extends StatefulWidget {
  final String? orderId;

  const OrderPackingScreen({super.key, this.orderId});

  @override
  State<OrderPackingScreen> createState() => _OrderPackingScreenState();
}

class _OrderPackingScreenState extends State<OrderPackingScreen> {
  OrderModel? _currentOrder;
  final List<String> _verifiedItems = [];
  bool _isLoading = false;
  String? _parcelId;
  Map<String, ProductBatch?> _suggestedBatches = {};
  Map<String, Map<String, dynamic>> _productLocations = {};
  List<OrderItem> _sortedItems = [];
  bool _autoPrintOnComplete = true;
  static const String _keyAutoPrintPacking = 'auto_print_receipt_on_packing';

  // --- Barcode Mapping and Inputs ---
  final Map<String, String> _barcodeToProductId = {};
  final Map<String, String> _productIdToBarcode = {};
  final TextEditingController _barcodeInputController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  // --- Packing Photo Proof (Feature 4) ---
  XFile? _packingPhoto;

  // --- Weight Verification (Feature 3) ---
  final WeightVerificationService _weightService = WeightVerificationService();
  // Map of productId → packed weight entered by employee
  final Map<String, double> _packedWeights = {};
  // Items that need weight verification (vegetables/fruits)
  List<OrderItem> get _weightVerificationItems => _sortedItems
      .where(
        (item) => _weightService.requiresWeightVerification(_getProductCategory(item.productId)),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadAutoPrintSetting();
    if (widget.orderId != null) {
      _loadOrder(widget.orderId!);
    }
  }

  @override
  void dispose() {
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAutoPrintSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPrintOnComplete = prefs.getBool(_keyAutoPrintPacking) ?? true;
    });
  }

  Future<void> _toggleAutoPrintSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrintPacking, value);
    setState(() {
      _autoPrintOnComplete = value;
    });
  }

  String _formatLocation(Map<String, dynamic>? loc) {
    if (loc == null || loc.isEmpty) return 'No Location';
    final zone = loc['zone'] ?? '';
    final shelf = loc['shelf'];
    if (zone.toString().isNotEmpty && shelf != null) {
      return 'Aisle $zone Shelf $shelf';
    }
    final aisle = loc['aisle'];
    if (aisle != null) return 'Aisle $aisle';
    return 'No Location';
  }

  int _compareLocations(Map<String, dynamic>? locA, Map<String, dynamic>? locB) {
    if (locA == null || locA.isEmpty) return 1;
    if (locB == null || locB.isEmpty) return -1;

    final String zoneA = (locA['zone'] ?? '').toString().toUpperCase();
    final String zoneB = (locB['zone'] ?? '').toString().toUpperCase();
    final int zoneComp = zoneA.compareTo(zoneB);
    if (zoneComp != 0) return zoneComp;

    final int aisleA = int.tryParse(locA['aisle']?.toString() ?? '') ?? 999;
    final int aisleB = int.tryParse(locB['aisle']?.toString() ?? '') ?? 999;
    final int aisleComp = aisleA.compareTo(aisleB);
    if (aisleComp != 0) return aisleComp;

    final int shelfA = int.tryParse(locA['shelf']?.toString() ?? '') ?? 999;
    final int shelfB = int.tryParse(locB['shelf']?.toString() ?? '') ?? 999;
    final int shelfComp = shelfA.compareTo(shelfB);
    if (shelfComp != 0) return shelfComp;

    final int binA = int.tryParse(locA['bin']?.toString() ?? '') ?? 999;
    final int binB = int.tryParse(locB['bin']?.toString() ?? '') ?? 999;
    return binA.compareTo(binB);
  }

  Future<void> _loadOrder(String orderId) async {
    setState(() {
      _isLoading = true;
      _barcodeToProductId.clear();
      _productIdToBarcode.clear();
    });
    try {
      final orderProvider = context.read<OrderProvider>();
      final order = await orderProvider.getOrderById(orderId);
      if (order == null) throw Exception('Order not found');

      final authProvider = context.read<AuthProvider>();
      final shopId = authProvider.currentShop?.id ?? '';
      final branchId = authProvider.currentBranch?.id ?? '';

      final Map<String, ProductBatch?> suggestions = {};
      final Map<String, Map<String, dynamic>> locations = {};

      if (shopId.isNotEmpty && branchId.isNotEmpty) {
        for (var item in order.items) {
          final querySnapshot = await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('branches')
              .doc(branchId)
              .collection('inventory_batches')
              .where('productId', isEqualTo: item.productId)
              .get();

          final batches = querySnapshot.docs
              .map((doc) => ProductBatch.fromMap(doc.data()))
              .where((batch) => batch.quantity > 0 && batch.expiryDate.isAfter(DateTime.now()))
              .toList();

          if (batches.isNotEmpty) {
            batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
            suggestions[item.productId] = batches.first;
          } else {
            suggestions[item.productId] = null;
          }

          final productDoc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('branches')
              .doc(branchId)
              .collection('products')
              .doc(item.productId)
              .get();
          if (productDoc.exists) {
            final product = ProductModel.fromMap(productDoc.data()!);
            locations[item.productId] = product.branchLocations[branchId] ?? const {};
            if (product.barcode.isNotEmpty) {
              _barcodeToProductId[product.barcode] = product.id;
              _productIdToBarcode[product.id] = product.barcode;
            }
          } else {
            locations[item.productId] = const {};
          }
        }
      }

      final sortedItems = List<OrderItem>.from(order.items);
      sortedItems.sort((a, b) {
        final locA = locations[a.productId];
        final locB = locations[b.productId];
        return _compareLocations(locA, locB);
      });

      setState(() {
        _currentOrder = order;
        _suggestedBatches = suggestions;
        _productLocations = locations;
        _sortedItems = sortedItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Order not found: $e');
    }
  }

  Future<void> _printParcelLabel() async {
    if (_parcelId == null || _currentOrder == null) return;

    final printerService = PrinterService();
    final device = await printerService.getSavedDevice();
    if (device != null && await printerService.connectToSavedDevice()) {
      try {
        await printerService.printParcelTag(
          device,
          parcelId: _parcelId!,
          orderNumber: _currentOrder!.orderNumber,
          customerName: _currentOrder!.customerName,
          customerPhone: _currentOrder!.customerPhone,
          address: _currentOrder!.deliveryAddress.fullAddress,
        );
        _showSuccess('Parcel tag printed successfully!');
      } catch (e) {
        _showError('Failed to print parcel tag: $e');
      }
    } else {
      _showPrinterSettings();
    }
  }

  Future<void> _printOrderReceipt() async {
    if (_currentOrder == null) return;

    final printerService = PrinterService();
    final device = await printerService.getSavedDevice();
    if (device != null && await printerService.connectToSavedDevice()) {
      try {
        await printerService.printOrderReceipt(device, _currentOrder!);
        _showSuccess('Receipt printed successfully!');
      } catch (e) {
        _showError('Failed to print receipt: $e');
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => PrinterSelectDialog(
          onDeviceSelected: (selectedDevice) async {
            try {
              await printerService.printOrderReceipt(selectedDevice, _currentOrder!);
              _showSuccess('Receipt printed successfully!');
            } catch (e) {
              _showError('Failed to print receipt: $e');
            }
          },
        ),
      );
    }
  }

  Future<void> _handleAutoPrint(String parcelId) async {
    final printerService = PrinterService();
    final hasDefault = await printerService.getDefaultPrinterAddress() != null;
    if (!hasDefault) {
      _showWarningWithAction(
        'Auto-print failed: No default printer set.',
        'Configure',
        _showPrinterSettings,
      );
      return;
    }

    final connected = await printerService.connectToSavedDevice();
    if (!connected) {
      _showWarningWithAction(
        'Auto-print failed: Cannot connect to printer.',
        'Reconnect',
        _showPrinterSettings,
      );
      return;
    }

    final device = await printerService.getSavedDevice();
    if (device == null) return;

    try {
      await printerService.printOrderReceipt(device, _currentOrder!);
      await Future.delayed(const Duration(milliseconds: 600));
      await printerService.printParcelTag(
        device,
        parcelId: parcelId,
        orderNumber: _currentOrder!.orderNumber,
        customerName: _currentOrder!.customerName,
        customerPhone: _currentOrder!.customerPhone,
        address: _currentOrder!.deliveryAddress.fullAddress,
      );
      _showSuccess('Receipt and parcel tag printed automatically!');
    } catch (e) {
      _showError('Auto-printing failed: $e');
    }
  }

  void _showWarningWithAction(String message, String actionLabel, VoidCallback onAction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.warning,
        action: SnackBarAction(label: actionLabel, textColor: Colors.white, onPressed: onAction),
      ),
    );
  }

  void _showPrinterSettings() {
    showDialog(
      context: context,
      builder: (context) => PrinterSelectDialog(
        onDeviceSelected: (device) {
          _showSuccess('Printer connected and set as default: ${device.name}');
          if (_parcelId != null) {
            _handleAutoPrint(_parcelId!);
          }
        },
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.error));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.success));
  }

  Future<void> _processBarcodeScan(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    _barcodeInputController.clear();
    _barcodeFocusNode.requestFocus(); // Keep focus for continuous hardware scanning

    final productId = _barcodeToProductId[cleanBarcode];
    if (productId != null) {
      final hasItem = _sortedItems.any((item) => item.productId == productId);
      if (hasItem) {
        if (_verifiedItems.contains(productId)) {
          // Already verified — warn with double buzz
          await SmartScanService.hapticError();
          final name = _sortedItems.firstWhere((i) => i.productId == productId).productName;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠ "$name" already scanned'),
                backgroundColor: AppTheme.warning,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // ✓ Verify item
          await _verifyItem(productId);
          await SmartScanService.hapticSuccess();

          final name = _sortedItems.firstWhere((i) => i.productId == productId).productName;
          final remaining = _sortedItems.length - _verifiedItems.length;

          if (mounted) {
            // Check if order is now fully packed
            if (_verifiedItems.length == _sortedItems.length) {
              // All items done — celebration haptic + auto-prompt
              await SmartScanService.hapticComplete();
              _showAllPackedDialog();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✓ $name packed  •  $remaining item${remaining == 1 ? '' : 's'} left',
                  ),
                  backgroundColor: AppTheme.success,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          }
        }
      } else {
        // Wrong item for this order
        await SmartScanService.hapticError();
        _showBarcodeErrorDialog(
          title: 'Incorrect Item',
          message: 'This product is NOT in the customer\'s cart!',
        );
      }
    } else {
      // Unknown barcode
      await SmartScanService.hapticError();
      _showBarcodeErrorDialog(
        title: 'Unknown Barcode',
        message: 'Barcode "$cleanBarcode" is not recognised in this branch.',
      );
    }
  }

  /// Shown after packing completes — displays DISPATCH QR for the dispatch team.
  void _showDispatchQrDialog(String orderId, String orderNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 26),
            SizedBox(width: 8),
            Expanded(child: Text('Packed! Show to Dispatch', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hand this to the dispatch employee to scan.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // DISPATCH QR — scanned by dispatch team
            ScanQrWidget.dispatch(orderId: orderId, orderNumber: orderNumber, size: 200),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: const Text('Go to Dispatch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DispatchScannerScreen(orderId: orderId)),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Auto-shown when every item in the order has been scanned.
  void _showAllPackedDialog() {
    if (_currentOrder == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('All Items Packed!'),
          ],
        ),
        content: Text(
          '${_sortedItems.length} item${_sortedItems.length == 1 ? '' : 's'} verified.\n'
          'Mark this order as packed and ready for dispatch?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Review First')),
          ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Mark Packed & Seal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _completePacking();
            },
          ),
        ],
      ),
    );
  }

  void _showBarcodeErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.error),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _barcodeFocusNode.requestFocus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Opens the inline camera scanner (defined at bottom of this file).
  /// Returns one scanned barcode and processes it.
  Future<void> _openCameraScanner() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PackingItemScanPage()),
    );
    if (code != null && code.isNotEmpty) {
      await _processBarcodeScan(code);
    }
  }

  Future<void> _verifyItem(String productId) async {
    if (_currentOrder == null) return;

    setState(() {
      if (!_verifiedItems.contains(productId)) {
        _verifiedItems.add(productId);
      }
    });

    final authProvider = context.read<AuthProvider>();
    final employeeName = authProvider.currentUser?.name ?? 'Employee';
    final service = EmployeeScannerService(
      shopId: authProvider.currentShop?.id ?? '',
      branchId: authProvider.currentBranch?.id ?? '',
      employeeId: authProvider.currentUser?.uid ?? '',
      employeeName: employeeName,
    );

    await service.verifyPackingItem(orderId: _currentOrder!.id, productId: productId, quantity: 1);

    // Update Realtime Database for Customer View
    final itemName = _sortedItems.firstWhere((i) => i.productId == productId).productName;
    RealtimeDatabaseService.instance.updatePackingProgress(
      orderId: _currentOrder!.id,
      employeeName: employeeName,
      itemsPacked: _verifiedItems.length,
      totalItems: _currentOrder!.items.length,
      lastItemName: itemName,
    );

    // If this is a weight-verified item, prompt weight entry
    final category = _getProductCategory(productId);
    if (_weightService.requiresWeightVerification(category)) {
      _showWeightEntryDialog(productId);
    }
  }

  Future<void> _completePacking() async {
    if (_currentOrder == null) return;

    if (_verifiedItems.length != _currentOrder!.items.length) {
      _showError('Please verify all items before completing');
      return;
    }

    // Require packing photo before completing
    if (_packingPhoto == null) {
      _showError('Please take a packing photo before completing');
      _capturePackingPhoto();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      // Upload packing photo and get proof URL
      final photoUrl = await _savePackingPhotoProof(authProvider);

      // Automated Backend Checkout (Deducts stock + Updates Ledger + Sets Status)
      final checkoutRes = await ApiClient.instance.post('/operations/checkout-order', {
        'orderId': _currentOrder!.id,
        'photoUrl': photoUrl,
      });

      if (checkoutRes.data['success'] != true) {
        throw Exception(checkoutRes.data['error'] ?? 'Checkout failed');
      }

      // Save weight verifications for each applicable item
      for (final item in _weightVerificationItems) {
        final packedWeight = _packedWeights[item.productId];
        if (packedWeight != null) {
          await _weightService.recordWeightVerification(
            orderId: _currentOrder!.id,
            orderItemId: item.id,
            productId: item.productId,
            productName: item.productName,
            orderedWeightKg: item.quantity.toDouble(),
            packedWeightKg: packedWeight,
            employeeId: authProvider.currentUser?.uid ?? '',
            employeeName: authProvider.currentUser?.name ?? 'Employee',
          );
        }
      }

      await service.completePacking(
        orderId: _currentOrder!.id,
        verifiedItems: _verifiedItems,
        photoUrl: photoUrl,
      );

      final completedOrderId = _currentOrder!.id;
      final completedOrderNumber = _currentOrder!.orderNumber;

      setState(() {
        _currentOrder = null;
        _verifiedItems.clear();
        _packedWeights.clear();
        _packingPhoto = null;
        _parcelId = null;
        _isLoading = false;
      });

      await SmartScanService.hapticComplete();

      // Show DISPATCH QR immediately — dispatch team scans this
      if (mounted) _showDispatchQrDialog(completedOrderId, completedOrderNumber);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to submit for approval: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Packing', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: _currentOrder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentOrder = null;
                    _verifiedItems.clear();
                    _packedWeights.clear();
                    _packingPhoto = null;
                    _parcelId = null;
                  });
                },
              )
            : null,
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: _showPrinterSettings),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _currentOrder == null
          ? _buildNoOrderView()
          : _buildOrderView(),
    );
  }

  Widget _buildNoOrderView() {
    final authProvider = context.read<AuthProvider>();
    final branchId = authProvider.currentBranch?.id ?? '';
    final shopId = authProvider.currentShop?.id ?? '';

    final service = EmployeeScannerService(
      shopId: shopId,
      branchId: branchId,
      employeeId: authProvider.currentUser?.uid ?? '',
      employeeName: authProvider.currentUser?.name ?? 'Employee',
    );

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppTheme.warning,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.warning,
              tabs: [
                Tab(icon: Icon(Icons.new_releases), text: 'Confirmed'),
                Tab(icon: Icon(Icons.inventory_2), text: 'Processing'),
                Tab(icon: Icon(Icons.check_circle), text: 'Packed & Sealed'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: service.getPendingOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading tasks: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                final List<OrderModel> allOrders = docs
                    .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>))
                    .toList();

                final confirmed = allOrders.where((order) {
                  return order.status == OrderStatus.confirmed;
                }).toList();

                final processing = allOrders.where((order) {
                  return order.status == OrderStatus.processing;
                }).toList();

                final packed = allOrders.where((order) {
                  return order.status == OrderStatus.packed;
                }).toList();

                return TabBarView(
                  children: [
                    _buildOrderListTab(confirmed, 'No newly confirmed orders'),
                    _buildOrderListTab(
                      processing,
                      'No orders currently being packed',
                      isReview: true,
                    ),
                    _buildOrderListTab(packed, 'No packed orders yet'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListTab(List<OrderModel> orders, String emptyMsg, {bool isReview = false}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isRejected = order.packingStatus == 'rejected';

        return FjCard(
          margin: const EdgeInsets.only(bottom: 12),
          onTap: isReview
              ? null
              : () async {
                  final authProvider = context.read<AuthProvider>();
                  final employeeId = authProvider.currentUser?.uid ?? '';
                  final employeeName = authProvider.currentUser?.name ?? 'Employee';

                  // 1. Attempt to Acquire Lock
                  final lockAcquired = await PresenceService().startTaskLock(
                    order.id,
                    employeeId,
                    employeeName,
                  );

                  if (!lockAcquired) {
                    if (mounted) {
                      _showError('This order is currently being packed by someone else.');
                    }
                    return;
                  }

                  _loadOrder(order.id);
                },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.error),
                    ),
                    child: const Text(
                      'Rejected',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Customer: ${order.customerName}'),
                Text('${order.items.length} items • ₹${order.totalAmount.round()}'),
                if (isRejected && order.packingRejectionReason != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Reason: ${order.packingRejectionReason}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: isReview
                ? const Icon(Icons.hourglass_empty, color: AppTheme.warning)
                : const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      },
    );
  }

  Widget _buildOrderView() {
    final order = _currentOrder!;
    final allVerified = _verifiedItems.length == order.items.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.packingStatus == 'rejected' && order.packingRejectionReason != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PACKING REJECTED BY OWNER',
                          style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.packingRejectionReason!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Order Info Card
          FjCard(
            color: allVerified ? AppTheme.success.withOpacity(0.1) : AppTheme.primaryLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Chip(
                      label: Text(order.status.displayName),
                      backgroundColor: allVerified ? AppTheme.success : AppTheme.warning,
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Customer: ${order.customerName}'),
                Text('Phone: ${order.customerPhone}'),
                Text('Address: ${order.deliveryAddress.fullAddress}'),
                if (_parcelId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code, color: AppTheme.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Parcel QR Code',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(_parcelId!, style: const TextStyle(fontFamily: 'monospace')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FjButton(
                                onPressed: _printOrderReceipt,
                                icon: Icons.receipt,
                                label: 'Print Receipt',
                                type: FjButtonType.secondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FjButton(
                                onPressed: _printParcelLabel,
                                icon: Icons.qr_code,
                                label: 'Print Tag',
                                type: FjButtonType.info,
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

          const SizedBox(height: 16),

          // Auto-print Toggle Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.print, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-print on complete',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Switch(
                value: _autoPrintOnComplete,
                onChanged: _toggleAutoPrintSetting,
                activeThumbColor: AppTheme.success,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Smart Barcode Scanning Section
          FjCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppTheme.warning),
                    SizedBox(width: 8),
                    Text(
                      'Smart Barcode Packing',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeInputController,
                        focusNode: _barcodeFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Scan item barcode...',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.keyboard, size: 20),
                          suffixIcon: _barcodeInputController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _barcodeInputController.clear(),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.warning, width: 2),
                          ),
                        ),
                        onSubmitted: _processBarcodeScan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FjButton(
                      onPressed: _openCameraScanner,
                      icon: Icons.camera_alt,
                      label: 'Scan',
                      type: FjButtonType.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tip: Hardware scanners work automatically when cursor is focused in input box.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Packing Checklist
          Text('Packing Checklist', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          ..._sortedItems.map((item) {
            final isVerified = _verifiedItems.contains(item.productId);
            return FjCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isVerified ? AppTheme.success : Colors.grey.shade100,
                  child: isVerified
                      ? const Icon(Icons.check, color: Colors.white)
                      : Text('${item.quantity}', style: const TextStyle(color: AppTheme.grey700)),
                ),
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${item.quantity} x ₹${item.price.round()}'),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.warning, width: 0.5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 10, color: AppTheme.warning),
                              SizedBox(width: 2),
                              Text(
                                'Fixed Price',
                                style: TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_productIdToBarcode[item.productId] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.qr_code, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Barcode: ${_productIdToBarcode[item.productId]}',
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                    if (_productLocations[item.productId] != null &&
                        _productLocations[item.productId]!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppTheme.warning),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Loc: ${_formatLocation(_productLocations[item.productId])}',
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_suggestedBatches[item.productId] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: AppTheme.info),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Suggest Pick: Batch ${_suggestedBatches[item.productId]!.batchId} (Exp: ${DateFormat('yyyy-MM-dd').format(_suggestedBatches[item.productId]!.expiryDate)})',
                              style: const TextStyle(
                                color: AppTheme.info,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: isVerified
                    ? const Icon(Icons.check_circle, color: AppTheme.success)
                    : FjButton(
                        label: 'Verify',
                        onPressed: () => _verifyItem(item.productId),
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // --- PACKING PHOTO PROOF (Feature 4) ---
          _buildPackingPhotoSection(),

          const SizedBox(height: 8),

          // Complete Button
          if (_currentOrder?.packingStatus != 'approved' &&
              _currentOrder?.status != OrderStatus.packed)
            FjButton(
              label: allVerified ? 'Mark Packed & Seal' : 'Verify All Items First',
              onPressed: allVerified && !_isLoading ? _completePacking : null,
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.local_shipping_outlined,
            ),
        ],
      ),
    );
  }

  /// Opens a full-screen QR scanner that returns one scanned code,
  /// then loads the matching order. Accepts ORDER-{id} or bare UUIDs.
  Future<void> _showScannerDialog() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _OrderQrScanPage()),
    );
    if (code == null || code.isEmpty) return;
    final orderId = code.startsWith('ORDER-') ? code : 'ORDER-$code';
    _loadOrder(orderId);
  }

  // ─────────────── PACKING PHOTO PROOF (Feature 4) ───────────────

  Widget _buildPackingPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt, size: 18, color: AppTheme.infoGrey),
            const SizedBox(width: 8),
            const Text(
              'Packing Photo Proof',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            if (_packingPhoto != null)
              const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        if (_packingPhoto == null)
          GestureDetector(
            onTap: _capturePackingPhoto,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.infoGrey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.infoGrey.withOpacity(0.1),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: AppTheme.infoGrey, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Take Packing Photo',
                      style: TextStyle(color: AppTheme.infoGrey, fontSize: 12),
                    ),
                    Text(
                      'Required before completing',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _packingPhoto!.path,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: AppTheme.success.withOpacity(0.1),
                    child: const Center(
                      child: Icon(Icons.check_circle, color: AppTheme.success, size: 40),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: _capturePackingPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Retake',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (_packingPhoto != null) ...[
          const SizedBox(height: 6),
          const Text(
            '📸 Photo taken — customer will see this with their order',
            style: TextStyle(color: AppTheme.success, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Future<void> _capturePackingPhoto() async {
    final picker = ImagePicker();
    try {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (photo != null) {
        setState(() => _packingPhoto = photo);
      }
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<String?> _savePackingPhotoProof(AuthProvider authProvider) async {
    if (_packingPhoto == null || _currentOrder == null) return null;

    setState(() {
      // Set any other loading state if needed here, but _photoUploading is removed
    });
    try {
      final bytes = await _packingPhoto!.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('packing_proofs')
          .child(_currentOrder!.id)
          .child('photo.jpg');

      final task = await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await task.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('[PackingScreen] Photo upload error: $e');
      return null;
    }
  }

  // ─────────────── WEIGHT VERIFICATION HELPERS ───────────────

  void _showWeightEntryDialog(String productId) {
    final item = _sortedItems.firstWhere(
      (i) => i.productId == productId,
      orElse: () => _sortedItems.first,
    );
    final controller = TextEditingController(
      text: _packedWeights[productId]?.toStringAsFixed(2) ?? item.quantity.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Weigh: ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ordered: ${item.quantity} kg', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Packed Weight (kg)',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Within 5% over: no extra charge to customer\n'
              '• Under-weight: partial refund issued automatically',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() {
                  _packedWeights[productId] = val;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _getProductCategory(String productId) {
    // Lookup from productLocations metadata, or default to empty
    // In a full implementation, this would check the product's category from cache
    final locationMeta = _productLocations[productId];
    return (locationMeta?['category'] as String?) ?? '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OrderQrScanPage
//
// Lightweight fullscreen camera scanner that pops with the raw scanned code.
// Called by OrderPackingScreen._showScannerDialog().
// Accepts: ORDER-{id}, bare UUID, or any alphanumeric order reference.
// ─────────────────────────────────────────────────────────────────────────────

class _OrderQrScanPage extends StatefulWidget {
  const _OrderQrScanPage();

  @override
  State<_OrderQrScanPage> createState() => _OrderQrScanPageState();
}

class _OrderQrScanPageState extends State<_OrderQrScanPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _done = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // Scan frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6A1B9A), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Order QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: _flashOn ? AppTheme.warning : Colors.white,
                    ),
                    onPressed: () async {
                      await _ctrl.toggleTorch();
                      setState(() => _flashOn = !_flashOn);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom hint
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Point at ORDER-{id} QR on the packing label',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PackingItemScanPage
//
// Camera scanner for scanning individual product barcodes while packing.
// Returns raw barcode string. Shown with color-coded frame (purple = packing).
// ─────────────────────────────────────────────────────────────────────────────

class _PackingItemScanPage extends StatefulWidget {
  const _PackingItemScanPage();

  @override
  State<_PackingItemScanPage> createState() => _PackingItemScanPageState();
}

class _PackingItemScanPageState extends State<_PackingItemScanPage> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _done = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // Purple frame for packing mode
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6A1B9A), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Item Barcode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _flashOn ? Icons.flash_on : Icons.flash_off,
                      color: _flashOn ? AppTheme.warning : Colors.white,
                    ),
                    onPressed: () async {
                      await _ctrl.toggleTorch();
                      setState(() => _flashOn = !_flashOn);
                    },
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC6A1B9A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Scan each product barcode to verify',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
