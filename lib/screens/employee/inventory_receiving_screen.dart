import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

  // Auto-complete additions
  final _quantityFocusNode = FocusNode(); // auto-focus after scan
  final SmartScanService _smartScan = SmartScanService();
  String? _poReference;       // open PO reference if found
  int _batchCount = 0;        // items processed this session
  bool _autoFillActive = false; // shows green glow when auto-filled

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

  Future<void> _scanProductLabel() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final aiService = AIRecognitionService();
      
      // OCR Extraction
      final ocrResult = await aiService.extractText(image);
      setState(() {
        if (ocrResult.batchNumber != null) {
          _batchNumberController.text = ocrResult.batchNumber!;
        }
        if (ocrResult.expiryDate != null) {
          final parsedDate = DateTime.tryParse(ocrResult.expiryDate!);
          if (parsedDate != null) {
            _expiryDate = parsedDate;
          }
        }
        if (ocrResult.mrp != null) {
          _costPriceController.text = ocrResult.mrp!.toString();
        }
        _isLoading = false;
      });
      if (ocrResult.isEdgeMode) {
        _showSuccess('Edge Mode (Offline) Active: Details extracted on-device.');
      } else {
        _showSuccess('Label details extracted successfully!');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to parse product label: $e');
    }
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
      setState(() => _isLoading = false);
      _showError('Failed to load purchase orders: $e');
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
    
    _showSuccess('Matched invoice OCR with Purchase Order!');
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
      setState(() => _isLoading = false);
      _showError('Failed to parse invoice: $e');
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
      
      _showSuccess('Purchase Order received successfully!');
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
      _showError('Failed to receive Purchase Order: $e');
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
        _showSuccess('Shelf tag printed successfully!');
      } catch (e) {
        _showError('Failed to print shelf tag: $e');
      }
    } else {
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
              _showSuccess('Shelf tag printed successfully!');
            } catch (e) {
              _showError('Failed to print shelf tag: $e');
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
        'Auto-print shelf tag failed: No default printer set.',
        'Configure',
        _showPrinterSettings,
      );
      return;
    }

    final connected = await printerService.connectToSavedDevice();
    if (!connected) {
      _showWarningWithAction(
        'Auto-print shelf tag failed: Cannot connect to printer.',
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
      _showSuccess('Shelf tag printed automatically!');
    } catch (e) {
      _showError('Auto-printing shelf tag failed: $e');
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
      _autoFillActive = false;
      _poReference = null;
    });

    final auth = context.read<AuthProvider>();
    final shopId = auth.currentShop?.id ?? '';
    final branchId = auth.currentBranch?.id ?? '';

    try {
      // SmartScanService: auto-lookup + PO match
      final result = await _smartScan.autoProduct(
        barcode: barcode,
        shopId: shopId,
        branchId: branchId,
      );

      if (result.found) {
        setState(() {
          _product = result.product;
          _isLoading = false;
          _autoFillActive = true;

          // Auto-fill quantity from open PO if available
          if (result.openPoLine != null) {
            _quantityController.text =
                result.openPoLine!.quantity.toString();
            _poReference = result.openPoLine!.poId;
            if (result.openPoLine!.supplier?.isNotEmpty == true) {
              _supplierController.text =
                  result.openPoLine!.supplier!;
            }
          } else {
            _quantityController.text = '1';
          }
        });

        // Auto-focus quantity field so employee just types/confirms
        await SmartScanService.hapticSuccess();
        await Future.delayed(const Duration(milliseconds: 150));
        _quantityFocusNode.requestFocus();
        _quantityController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _quantityController.text.length,
        );
      } else {
        // Fallback: try product provider cache
        final productProvider = context.read<ProductProvider>();
        final cached = productProvider.getProductByBarcode(barcode);
        setState(() {
          _product = cached;
          _isLoading = false;
          _autoFillActive = cached != null;
          if (cached != null) _quantityController.text = '1';
        });

        if (cached != null) {
          await SmartScanService.hapticSuccess();
          await Future.delayed(const Duration(milliseconds: 150));
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
      setState(() => _isLoading = false);
      await SmartScanService.hapticError();
      _showError('Lookup failed: $e');
    }
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

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final service = EmployeeScannerService(
        shopId: authProvider.currentShop?.id ?? '',
        branchId: authProvider.currentBranch?.id ?? '',
        employeeId: authProvider.currentUser?.uid ?? '',
        employeeName: authProvider.currentUser?.name ?? 'Employee',
      );

      await service.receiveInventory(
        productId: _product!.id,
        barcode: _scannedBarcode ?? '',
        quantity: quantity,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        batchNumber: _batchNumberController.text.isNotEmpty ? _batchNumberController.text : null,
        expiryDate: _expiryDate,
        supplier: _supplierController.text.isNotEmpty ? _supplierController.text : null,
        costPrice: double.tryParse(_costPriceController.text),
      );

      final printName = _product!.name;
      final printBarcode = _scannedBarcode ?? '';
      final printPrice = _product!.price;
      final printOriginalPrice = _product!.originalPrice;
      final printBatchNumber = _batchNumberController.text.isNotEmpty ? _batchNumberController.text : null;
      final printExpiryDate = _expiryDate;

      // Add to local list
      setState(() {
        _receivedItems.insert(
          0,
          ReceiveItem(
            productName: printName,
            barcode: printBarcode,
            quantity: quantity,
            timestamp: DateTime.now(),
            price: printPrice,
            originalPrice: printOriginalPrice,
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
        _autoFillActive = false;
        _batchCount++;   // increment session counter
      });

      await SmartScanService.hapticComplete();
      _showSuccess(
          '✓ $quantity × $printName added  —  $_batchCount item${_batchCount == 1 ? '' : 's'} this session');

      if (_autoPrintShelfTag) {
        await _handleAutoPrintShelfTag(
          productName: printName,
          barcode: printBarcode,
          price: printPrice,
          originalPrice: printOriginalPrice,
          batchNumber: printBatchNumber,
          expiryDate: printExpiryDate,
        );
      }
    } catch (e) {
      _showError('Failed to add stock: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _showPrinterSettings,
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
            // Mode Select Toggle
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
                      backgroundColor: !_poMode ? Colors.green : Colors.grey.shade200,
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
                      backgroundColor: _poMode ? Colors.green : Colors.grey.shade200,
                      foregroundColor: _poMode ? Colors.white : Colors.black,
                    ),
                  ),
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
        // PO Selector Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Purchase Order',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                      Text(
                        'PO Items (${_selectedPO!.items.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _scanInvoiceOCR,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Invoice OCR'),
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
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Ordered: ${item.quantity} ${item.unit}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: currentQty > 0
                                          ? () => setState(() => _poReceivedQuantities[item.productId] = currentQty - 1)
                                          : null,
                                    ),
                                    Text('$currentQty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => setState(() => _poReceivedQuantities[item.productId] = currentQty + 1),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            // Optional details for this specific item in PO receiving
                            ExpansionTile(
                              title: const Text('Item Expiry / Batch Details', style: TextStyle(fontSize: 12)),
                              childrenPadding: const EdgeInsets.all(8),
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          labelText: 'Batch Number',
                                          isDense: true,
                                        ),
                                        onChanged: (val) => _poBatchNumbers[item.productId] = val,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now().add(const Duration(days: 180)),
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                                          );
                                          if (date != null) {
                                            setState(() {
                                              _poExpiryDates[item.productId] = date;
                                            });
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Expiry Date',
                                            isDense: true,
                                          ),
                                          child: Text(
                                            _poExpiryDates[item.productId] == null
                                                ? 'Select'
                                                : DateFormat('yyyy-MM-dd').format(_poExpiryDates[item.productId]!),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Confirm PO Receive'),
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
        // Auto-print Toggle Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.print, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Auto-print shelf tag',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Switch(
              value: _autoPrintShelfTag,
              onChanged: _toggleAutoPrintSetting,
              activeThumbColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scan Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Product',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_scannedBarcode != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: _autoFillActive
                                ? Colors.green
                                : Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Barcode: $_scannedBarcode',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (_product != null)
                                Text(
                                  _product!.name,
                                  style: const TextStyle(
                                      color: Colors.grey),
                                ),
                              // PO auto-fill badge
                              if (_poReference != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    '📋 PO auto-filled: $_poReference',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Batch session counter
                        if (_batchCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_batchCount done',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
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

        const SizedBox(height: 16),

        // Product Details
        if (_product != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Name', _product!.name),
                  _buildDetailRow(
                      'Current Stock', _product!.stockQuantity.toString()),
                  _buildDetailRow(
                      'Branch Stock', _product!.branchStock[context.read<AuthProvider>().currentBranch?.id ?? '']?.toString() ?? '0'),
                  _buildDetailRow('Unit', _product!.unit),
                  if (_product!.brand != null)
                    _buildDetailRow('Brand', _product!.brand!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quantity Input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Stock',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    focusNode: _quantityFocusNode, // auto-focused after scan
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addToStock(), // Enter key = save
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      prefixIcon: const Icon(Icons.numbers),
                      border: const OutlineInputBorder(),
                      // Green glow when auto-filled from PO
                      enabledBorder: _autoFillActive
                          ? OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.green.shade400, width: 2))
                          : null,
                      helperText: _poReference != null
                          ? 'Auto-filled from PO'
                          : null,
                      helperStyle:
                          const TextStyle(color: Colors.green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _batchNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number',
                      prefixIcon: Icon(Icons.qr_code_2),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (date != null) {
                        setState(() {
                          _expiryDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expiry Date',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _expiryDate == null
                            ? 'Select Expiry Date'
                            : DateFormat('yyyy-MM-dd').format(_expiryDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price (Optional)',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _scanProductLabel,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Scan Label with OCR/AI'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addToStock,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Add to Stock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Quick Add Buttons
        if (_product == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 5, 10, 20, 50, 100].map((qty) {
                      return ActionChip(
                        label: Text('+$qty'),
                        onPressed: () {
                          _quantityController.text = qty.toString();
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Received Items List
        if (_receivedItems.isNotEmpty) ...[
          Text(
            'Recently Received',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._receivedItems.map((item) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.add_box, color: Colors.white),
                  ),
                  title: Text(item.productName),
                  subtitle: Text('Barcode: ${item.barcode}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.blue),
                        onPressed: () => _printShelfTag(
                          productName: item.productName,
                          barcode: item.barcode,
                          price: item.price ?? 0.0,
                          originalPrice: item.originalPrice,
                          batchNumber: item.batchNumber,
                          expiryDate: item.expiryDate,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              setState(() {
                _scannedBarcode = value;
              });
              _lookupProduct(value);
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
