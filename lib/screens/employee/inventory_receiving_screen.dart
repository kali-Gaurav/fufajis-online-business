import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/smart_scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/employee_scanner_service.dart';
import '../../services/ai_recognition_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/purchase_order.dart';
import '../../services/printer_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/employee/printer_select_dialog.dart';

class InventoryReceivingScreen extends StatefulWidget {
  final String? barcode;

  const InventoryReceivingScreen({super.key, this.barcode});

  @override
  State<InventoryReceivingScreen> createState() =>
      _InventoryReceivingScreenState();
}

class _InventoryReceivingScreenState extends State<InventoryReceivingScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _supplierController = TextEditingController();
  final _costPriceController = TextEditingController();
  DateTime? _expiryDate;

  final _quantityFocusNode = FocusNode();
  final SmartScanService _smartScan = SmartScanService();
  String? _poReference;
  bool _bulkMode = false;

  String? _scannedBarcode;
  ProductModel? _product;
  bool _isLoading = false;
  final List<ReceiveItem> _receivedItems = [];

  PurchaseOrder? _selectedPO;
  List<PurchaseOrder> _purchaseOrders = [];
  Map<String, int> _poReceivedQuantities = {};
  Map<String, String> _poBatchNumbers = {};
  Map<String, DateTime> _poExpiryDates = {};
  Map<String, double> _poCostPrices = {};
  bool _poMode = false;
  bool _autoPrintShelfTag = false;
  static const String _keyAutoPrintShelfTag = 'auto_print_shelf_tag_on_receiving';
  Future<void> _loadAutoPrintSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoPrintShelfTag = prefs.getBool(_keyAutoPrintShelfTag) ?? false;
    });
  }

  Future<void> _toggleAutoPrintSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPrintShelfTag, value);
    setState(() {
      _autoPrintShelfTag = value;
    });
  }



  Future<void> _loadPurchaseOrders() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final shopId = authProvider.currentShop?.id ?? '';
      final branchId = authProvider.currentBranch?.id ?? '';
      
      if (shopId.isNotEmpty && branchId.isNotEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('branches')
            .doc(branchId)
            .collection('purchase_orders')
            .where('status', isNotEqualTo: 'received')
            .get();
            
        final pos = querySnapshot.docs
            .map((doc) => PurchaseOrder.fromMap(doc.data()))
            .toList();
            
        setState(() {
          _purchaseOrders = pos;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('PO load failed: $e');
    }
  }

  void _matchInvoiceWithPO(OCRResult ocr) {
    if (_selectedPO == null) return;
    
    final lines = ocr.lines;
    final Map<String, int> matchedQuantities = {};
    
    for (var item in _selectedPO!.items) {
      final productName = item.productName.toUpperCase();
      final words = productName.split(' ').where((w) => w.length > 2).toList();
      
      bool matched = false;
      for (var line in lines) {
        final upperLine = line.toUpperCase();
        int matchCount = 0;
        for (var word in words) {
          if (upperLine.contains(word)) {
            matchCount++;
          }
        }
        
        if (matchCount >= (words.length > 1 ? 2 : 1)) {
          final numbers = RegExp(r'\b\d+\b').allMatches(upperLine).map((m) => int.tryParse(m.group(0) ?? '')).whereType<int>().toList();
          if (numbers.isNotEmpty) {
            int bestQty = item.quantity;
            int minDiff = 999999;
            for (var num in numbers) {
              final diff = (num - item.quantity).abs();
              if (diff < minDiff) {
                minDiff = diff;
                bestQty = num;
              }
            }
            matchedQuantities[item.productId] = bestQty;
            matched = true;
            break;
          }
        }
      }
      
      if (!matched) {
        matchedQuantities[item.productId] = item.quantity;
      }
    }
    
    setState(() {
      _poReceivedQuantities = matchedQuantities;
      if (ocr.batchNumber != null) {
        for (var item in _selectedPO!.items) {
          _poBatchNumbers[item.productId] = ocr.batchNumber!;
        }
      }
      if (ocr.expiryDate != null) {
        final parsedDate = DateTime.tryParse(ocr.expiryDate!);
        if (parsedDate != null) {
          for (var item in _selectedPO!.items) {
            _poExpiryDates[item.productId] = parsedDate;
          }
        }
      }
      if (ocr.mrp != null) {
        for (var item in _selectedPO!.items) {
          _poCostPrices[item.productId] = ocr.mrp!;
        }
      }
    });
    
    _showSuccess('Matched invoice OCR');
  }

  Future<void> _scanInvoiceOCR() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final aiService = AIRecognitionService();
      final ocrResult = await aiService.extractText(image);
      _matchInvoiceWithPO(ocrResult);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Invoice scan failed: $e');
    }
  }

  Future<void> _confirmPOReceive() async {
    if (_selectedPO == null) return;
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final shopId = authProvider.currentShop?.id ?? '';
      final branchId = authProvider.currentBranch?.id ?? '';
      
      final service = EmployeeScannerService(
        shopId: shopId,
        branchId: branchId,
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );
      
      for (var item in _selectedPO!.items) {
        final qty = _poReceivedQuantities[item.productId] ?? item.quantity;
        if (qty <= 0) continue;
        
        await service.receiveInventory(
          productId: item.productId,
          barcode: '',
          quantity: qty,
          batchNumber: _poBatchNumbers[item.productId],
          expiryDate: _poExpiryDates[item.productId],
          costPrice: _poCostPrices[item.productId],
          supplier: _selectedPO!.distributorName,
          notes: 'Received bulk via PO #${_selectedPO!.id}',
        );
      }
      
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('branches')
          .doc(branchId)
          .collection('purchase_orders')
          .doc(_selectedPO!.id)
          .update({
        'status': 'received',
        'receivedAt': FieldValue.serverTimestamp(),
      });
      
      _showSuccess('PO received successfully');
      setState(() {
        _selectedPO = null;
        _poMode = false;
        _poReceivedQuantities = {};
        _poBatchNumbers = {};
        _poExpiryDates = {};
        _poCostPrices = {};
      });
      _loadPurchaseOrders();
    } catch (e) {
      _showError('PO receive failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _printShelfTag({
    required String productName,
    required String barcode,
    required double price,
    double? originalPrice,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    final printerService = PrinterService();
    final device = await printerService.getSavedDevice();
    if (device != null && await printerService.connectToSavedDevice()) {
      try {
        await printerService.printProductTag(
          device,
          productName: productName,
          price: price,
          originalPrice: originalPrice,
          barcode: barcode,
          batchNumber: batchNumber,
          expiryDate: expiryDate,
        );
        _showSuccess('Shelf tag printed');
      } catch (e) {
        _showError('Print failed: $e');
      }
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => PrinterSelectDialog(
          onDeviceSelected: (selectedDevice) async {
            try {
              await printerService.printProductTag(
                selectedDevice,
                productName: productName,
                price: price,
                originalPrice: originalPrice,
                barcode: barcode,
                batchNumber: batchNumber,
                expiryDate: expiryDate,
              );
              _showSuccess('Shelf tag printed');
            } catch (e) {
              _showError('Print failed: $e');
            }
          },
        ),
      );
    }
  }

  Future<void> _handleAutoPrintShelfTag({
    required String productName,
    required String barcode,
    required double price,
    double? originalPrice,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    final printerService = PrinterService();
    final hasDefault = await printerService.getDefaultPrinterAddress() != null;
    if (!hasDefault) {
      _showWarningWithAction(
        'Auto-print failed: No printer.',
        'Configure',
        _showPrinterSettings,
      );
      return;
    }

    final connected = await printerService.connectToSavedDevice();
    if (!connected) {
      _showWarningWithAction(
        'Auto-print failed: Reconnect.',
        'Reconnect',
        _showPrinterSettings,
      );
      return;
    }

    final device = await printerService.getSavedDevice();
    if (device == null) return;

    try {
      await printerService.printProductTag(
        device,
        productName: productName,
        price: price,
        originalPrice: originalPrice,
        barcode: barcode,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
      );
      _showSuccess('Auto-printed shelf tag');
    } catch (e) {
      _showError('Auto-print failed: $e');
    }
  }

  void _showWarningWithAction(String message, String actionLabel, VoidCallback onAction) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.warning,
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
          _showSuccess('Printer default set: ${device.name}');
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAutoPrintSetting();
    if (widget.barcode != null) {
      _scannedBarcode = widget.barcode;
      _lookupProduct(widget.barcode!);
    }
  }

  Future<void> _lookupProduct(String barcode) async {
    setState(() {
      _isLoading = true;
      _poReference = null;
    });

    final auth = context.read<AuthProvider>();
    final shopId = auth.currentShop?.id ?? '';
    final branchId = auth.currentBranch?.id ?? '';

    try {
      final result = await _smartScan.autoProduct(
        barcode: barcode,
        shopId: shopId,
        branchId: branchId,
      );

      if (!mounted) return;

      if (result.found) {
        if (_bulkMode && result.product != null) {
          await _performAdd(
            product: result.product!,
            barcode: barcode,
            quantity: 1,
            notes: 'Bulk scanned',
          );
          return;
        }

        setState(() {
          _product = result.product;
          _isLoading = false;
          if (result.openPoLine != null) {
            _quantityController.text = result.openPoLine!.quantity.toString();
            _poReference = result.openPoLine!.poId;
            if (result.openPoLine!.supplier?.isNotEmpty == true) {
              _supplierController.text = result.openPoLine!.supplier!;
            }
          } else {
            _quantityController.text = '1';
          }
        });

        await SmartScanService.hapticSuccess();
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        _quantityFocusNode.requestFocus();
        _quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _quantityController.text.length,
        );
      } else {
        final productProvider = context.read<ProductProvider>();
        final cached = productProvider.getProductByBarcode(barcode);
        
        if (cached != null && _bulkMode) {
          await _performAdd(
            product: cached,
            barcode: barcode,
            quantity: 1,
            notes: 'Bulk scanned',
          );
          return;
        }

        setState(() {
          _product = cached;
          _isLoading = false;
          if (cached != null) {
            _quantityController.text = '1';
          }
        });

        if (cached != null) {
          await SmartScanService.hapticSuccess();
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          _quantityFocusNode.requestFocus();
          _quantityController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _quantityController.text.length,
          );
        } else {
          await SmartScanService.hapticError();
          _showError('Product not found: $barcode');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await SmartScanService.hapticError();
      _showError('Lookup failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _addToStock() async {
    if (_product == null) {
      _showError('Please scan a product first');
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('Please enter a valid quantity');
      return;
    }

    await _performAdd(
      product: _product!,
      barcode: _scannedBarcode ?? '',
      quantity: quantity,
      batchNumber: _batchNumberController.text.isNotEmpty ? _batchNumberController.text : null,
      expiryDate: _expiryDate,
      supplier: _supplierController.text.isNotEmpty ? _supplierController.text : null,
      costPrice: double.tryParse(_costPriceController.text),
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );
  }

  Future<void> _performAdd({
    required ProductModel product,
    required String barcode,
    required int quantity,
    String? batchNumber,
    DateTime? expiryDate,
    String? supplier,
    double? costPrice,
    String? notes,
  }) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final shopId = authProvider.currentShop?.id ?? '';
      final branchId = authProvider.currentBranch?.id ?? '';

      final service = EmployeeScannerService(
        shopId: shopId,
        branchId: branchId,
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      String? finalNotes = notes;
      if (_poReference != null) {
        final poNote = 'Auto-filled from PO: $_poReference';
        finalNotes = finalNotes == null ? poNote : '$finalNotes ($poNote)';
      }

      await service.receiveInventory(
        productId: product.id,
        barcode: barcode,
        quantity: quantity,
        notes: finalNotes,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        supplier: supplier,
        costPrice: costPrice,
      );

      final printName = product.name;
      final printBarcode = barcode;
      final printPrice = product.price;
      final printOriginalPrice = product.originalPrice;
      final printBatchNumber = batchNumber;
      final printExpiryDate = expiryDate;

      setState(() {
        _receivedItems.insert(
          0,
          ReceiveItem(
            productName: printName,
            barcode: printBarcode,
            quantity: quantity,
            timestamp: DateTime.now(),
            price: printPrice.toDouble(),
            originalPrice: printOriginalPrice?.toDouble(),
            batchNumber: printBatchNumber,
            expiryDate: printExpiryDate,
          ),
        );
        _product = null;
        _scannedBarcode = null;
        _quantityController.text = '1';
        _notesController.clear();
        _batchNumberController.clear();
        _supplierController.clear();
        _costPriceController.clear();
        _expiryDate = null;
        _poReference = null;
      });

      await SmartScanService.hapticComplete();
      _showSuccess('✓ $quantity × $printName added');

      if (_autoPrintShelfTag) {
        await _handleAutoPrintShelfTag(
          productName: printName,
          barcode: printBarcode,
          price: printPrice.toDouble(),
          originalPrice: printOriginalPrice?.toDouble(),
          batchNumber: printBatchNumber,
          expiryDate: printExpiryDate,
        );
      }
    } catch (e) {
      _showError('Add stock failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    _batchNumberController.dispose();
    _supplierController.dispose();
    _costPriceController.dispose();
    _quantityFocusNode.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Inventory', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _showPrinterSettings,
          ),
          if (_poMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh POs',
              onPressed: _loadPurchaseOrders,
            ),
          if (!_poMode)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _showScannerDialog(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _poMode = false;
                      });
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Standard Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_poMode ? AppTheme.success : Colors.grey.shade200,
                      foregroundColor: !_poMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _poMode = true;
                      });
                      _loadPurchaseOrders();
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Receive via PO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _poMode ? AppTheme.success : Colors.grey.shade200,
                      foregroundColor: _poMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Auto-print shelf tag', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Switch(
                  value: _autoPrintShelfTag,
                  onChanged: _toggleAutoPrintSetting,
                  activeThumbColor: AppTheme.success,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Bulk mode (Qty 1)', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Switch(
                  value: _bulkMode,
                  onChanged: (val) => setState(() => _bulkMode = val),
                  activeThumbColor: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_poMode)
              _buildPOWorkflowView()
            else
              _buildStandardWorkflowView(),
          ],
        ),
      ),
    );
  }

  Widget _buildPOWorkflowView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Purchase Order', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _purchaseOrders.isEmpty
                    ? const Text('No pending Purchase Orders found.')
                    : DropdownButtonFormField<PurchaseOrder>(
                        initialValue: _selectedPO,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt),
                        ),
                        items: _purchaseOrders.map((po) {
                          return DropdownMenuItem<PurchaseOrder>(
                            value: po,
                            child: Text('PO #${po.id.substring(0, 8)} (${po.distributorName})'),
                          );
                        }).toList(),
                        onChanged: (po) {
                          setState(() {
                            _selectedPO = po;
                            if (po != null) {
                              _poReceivedQuantities = {for (var item in po.items) item.productId: item.quantity};
                            }
                          });
                        },
                      ),
              ],
            ),
          ),
        ),
        
        if (_selectedPO != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PO Items (${_selectedPO!.items.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _scanInvoiceOCR,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Invoice'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedPO!.items.length,
                    itemBuilder: (context, index) {
                      final item = _selectedPO!.items[index];
                      final currentQty = _poReceivedQuantities[item.productId] ?? item.quantity;
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text('Ordered: ${item.quantity} ${item.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => _poReceivedQuantities[item.productId] = (currentQty - 1).clamp(0, 999))),
                            Text('$currentQty'),
                            IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _poReceivedQuantities[item.productId] = currentQty + 1)),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirmPOReceive,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm PO Receive'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStandardWorkflowView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scan Product', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_scannedBarcode != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Barcode: $_scannedBarcode', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (_product != null) Text(_product!.name),
                              if (_poReference != null)
                                Text('📋 PO: $_poReference', style: const TextStyle(fontSize: 11, color: AppTheme.info)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primary),
                          onPressed: () {
                            setState(() {
                              _product = null;
                              _scannedBarcode = null;
                              _poReference = null;
                            });
                            _showScannerDialog();
                          },
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _showScannerDialog(),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Product Barcode'),
                  ),
              ],
            ),
          ),
        ),

        if (_product != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    children: [1, 5, 10, 20, 50, 100].map((qty) {
                      return ActionChip(
                        label: Text('+$qty'),
                        onPressed: () {
                          _quantityController.text = qty.toString();
                          _quantityFocusNode.requestFocus();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _addToStock(),
                    decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _batchNumberController, decoration: const InputDecoration(labelText: 'Batch Number', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _supplierController, decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _costPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost Price', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addToStock,
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Add to Stock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (_receivedItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Recently Received', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._receivedItems.map((item) => Card(
            child: ListTile(
              title: Text(item.productName),
              subtitle: Text('Qty: ${item.quantity}'),
              trailing: IconButton(icon: const Icon(Icons.print), onPressed: () => _printShelfTag(productName: item.productName, barcode: item.barcode, price: item.price ?? 0)),
            ),
          )),
        ],
      ],
    );
  }


  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          autofocus: true,
          onSubmitted: (value) {
            Navigator.pop(context);
            if (value.isNotEmpty) {
              setState(() => _scannedBarcode = value);
              _lookupProduct(value);
            }
          },
        ),
      ),
    );
  }
}

class ReceiveItem {
  final String productName;
  final String barcode;
  final int quantity;
  final DateTime timestamp;
  final double? price;
  final double? originalPrice;
  final String? batchNumber;
  final DateTime? expiryDate;

  ReceiveItem({
    required this.productName,
    required this.barcode,
    required this.quantity,
    required this.timestamp,
    this.price,
    this.originalPrice,
    this.batchNumber,
    this.expiryDate,
  });
}
