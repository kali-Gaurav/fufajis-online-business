import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/weight_verification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../models/product_batch_model.dart';
import '../../models/product_model.dart';
import '../../services/printer_service.dart';
import '../../widgets/employee/printer_select_dialog.dart';


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

  // --- Packing Photo Proof (Feature 4) ---
  XFile? _packingPhoto;
  bool _photoUploading = false;

  // --- Weight Verification (Feature 3) ---
  final WeightVerificationService _weightService = WeightVerificationService();
  // Map of productId → packed weight entered by employee
  final Map<String, double> _packedWeights = {};
  // Items that need weight verification (vegetables/fruits)
  List<OrderItem> get _weightVerificationItems => _sortedItems
      .where((item) => _weightService.requiresWeightVerification(
          _getProductCategory(item.productId)))
      .toList();
  bool _allWeightsVerified = false;

  @override
  void initState() {
    super.initState();
    _loadAutoPrintSetting();
    if (widget.orderId != null) {
      _loadOrder(widget.orderId!);
    }
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
    setState(() => _isLoading = true);
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
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onAction,
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _verifyItem(String productId) async {
    if (_currentOrder == null) return;

    setState(() {
      if (!_verifiedItems.contains(productId)) {
        _verifiedItems.add(productId);
      }
    });

    final authProvider = context.read<AuthProvider>();
    final service = EmployeeScannerService(
      shopId: authProvider.currentShop?.id ?? '',
      branchId: authProvider.currentBranch?.id ?? '',
      employeeId: authProvider.currentUser?.uid ?? '',
      employeeName: authProvider.currentUser?.name ?? 'Employee',
    );

    await service.verifyPackingItem(
      orderId: _currentOrder!.id,
      productId: productId,
      quantity: 1,
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

      // Upload packing photo and save proof record
      await _savePackingPhotoProof(authProvider);

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

      final parcelId = await service.completePacking(
        orderId: _currentOrder!.id,
        verifiedItems: _verifiedItems,
      );

      setState(() {
        _parcelId = parcelId;
        _isLoading = false;
      });

      _showSuccess('Order packed! Parcel: $parcelId');

      if (_autoPrintOnComplete) {
        await _handleAutoPrint(parcelId);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to complete packing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Packing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _showPrinterSettings,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: const CircularProgressIndicator())
          : _currentOrder == null
              ? _buildNoOrderView()
              : _buildOrderView(),
    );
  }

  Widget _buildNoOrderView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No Order Selected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan an order QR code or select from list',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showScannerDialog(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Order QR'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showOrderList(),
            child: const Text('View Pending Orders'),
          ),
        ],
      ),
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
          // Order Info Card
          Card(
            color: allVerified ? Colors.green.shade50 : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        color: MaterialStateProperty.all(
                          allVerified ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Customer: ${order.customerName}'),
                  Text('Phone: ${order.customerPhone}'),
                  Text('Address: ${order.deliveryAddress}'),
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
                              const Icon(Icons.qr_code, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Parcel QR Code',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _parcelId!,
                                      style: const TextStyle(fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _printOrderReceipt,
                                  icon: const Icon(Icons.receipt),
                                  label: const Text('Print Receipt'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _printParcelLabel,
                                  icon: const Icon(Icons.qr_code),
                                  label: const Text('Print Tag'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
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
                activeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Packing Checklist
          Text(
            'Packing Checklist',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          ..._sortedItems.map((item) {
            final isVerified = _verifiedItems.contains(item.productId);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: isVerified
                      ? const Icon(Icons.check, color: Colors.white)
                      : Text('${item.quantity}'),
                  backgroundColor: isVerified ? Colors.green : Colors.grey,
                ),
                title: Text(item.productName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.quantity} x ₹${item.price}'),
                    if (_productLocations[item.productId] != null && _productLocations[item.productId]!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Loc: ${_formatLocation(_productLocations[item.productId])}',
                              style: const TextStyle(
                                color: Colors.orange,
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
                          const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Suggest Pick: Batch ${_suggestedBatches[item.productId]!.batchId} (Exp: ${DateFormat('yyyy-MM-dd').format(_suggestedBatches[item.productId]!.expiryDate)})',
                              style: const TextStyle(
                                color: Colors.blue,
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
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () => _verifyItem(item.productId),
                        child: const Text('Verify'),
                      ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // --- PACKING PHOTO PROOF (Feature 4) ---
          _buildPackingPhotoSection(),

          const SizedBox(height: 8),

          // Complete Button
          if (_parcelId == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allVerified && !_isLoading ? _completePacking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  allVerified ? 'Complete Packing' : 'Verify All Items First',
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Order ID'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Order ID (e.g., ORDER-12345)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              if (value.startsWith('ORDER-')) {
                _loadOrder(value);
              } else {
                _loadOrder('ORDER-$value');
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showOrderList() {
    // Show list of pending orders
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order list feature coming soon')),
    );
  }

  // ─────────────── PACKING PHOTO PROOF (Feature 4) ───────────────

  Widget _buildPackingPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt, size: 18, color: Colors.blueGrey),
            const SizedBox(width: 8),
            const Text('Packing Photo Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            if (_packingPhoto != null)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        if (_packingPhoto == null)
          GestureDetector(
            onTap: _capturePackingPhoto,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: Colors.blueGrey, size: 28),
                    SizedBox(height: 4),
                    Text('Take Packing Photo', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                    Text('Required before completing', style: TextStyle(color: Colors.grey, fontSize: 10)),
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
                    color: Colors.green.shade50,
                    child: const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 40)),
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
                    child: const Text('Retake', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
            ],
          ),
        if (_packingPhoto != null) ...[
          const SizedBox(height: 6),
          Text(
            '📸 Photo taken — customer will see this with their order',
            style: TextStyle(color: Colors.green.shade700, fontSize: 11),
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

  Future<void> _savePackingPhotoProof(AuthProvider authProvider) async {
    if (_packingPhoto == null || _currentOrder == null) return;

    setState(() => _photoUploading = true);
    try {
      final bytes = await _packingPhoto!.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('packing_proofs')
          .child(_currentOrder!.id)
          .child('photo.jpg');

      final task = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await task.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('orders').doc(_currentOrder!.id).update({
        'packingProof': {
          'photoUrl': downloadUrl,
          'packedBy': authProvider.currentUser?.name ?? 'Employee',
          'employeeId': authProvider.currentUser?.uid ?? '',
          'packedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[PackingScreen] Photo upload error: $e');
      // Non-fatal — log but don't block packing completion
    } finally {
      setState(() => _photoUploading = false);
    }
  }

  // ─────────────── WEIGHT VERIFICATION HELPERS ───────────────

  void _showWeightEntryDialog(String productId) {
    final item = _sortedItems.firstWhere((i) => i.productId == productId,
        orElse: () => _sortedItems.first);
    final controller = TextEditingController(
        text: _packedWeights[productId]?.toStringAsFixed(2) ?? item.quantity.toStringAsFixed(2));

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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() {
                  _packedWeights[productId] = val;
                  _allWeightsVerified = _weightVerificationItems
                      .every((i) => _packedWeights.containsKey(i.productId));
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

