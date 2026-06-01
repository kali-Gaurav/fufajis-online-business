import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/scanner_service.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import 'inventory_receiving_screen.dart';
import 'order_packing_screen.dart';
import 'delivery_screen.dart';
import 'inventory_audit_screen.dart';
import 'damage_reporting_screen.dart';
import 'attendance_screen.dart';
import 'cash_collection_screen.dart';
import 'returns_screen.dart';

class ScannerScreen extends StatefulWidget {
  final String? initialMode;

  const ScannerScreen({super.key, this.initialMode});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ScannerService _scannerService = ScannerService();
  final List<ScanResult> _scanHistory = [];
  bool _isFlashOn = false;
  String _lastScannedCode = '';

  @override
  void initState() {
    super.initState();
    _scannerService.startScanning();
  }

  @override
  void dispose() {
    _scannerService.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue == _lastScannedCode) return;

    _lastScannedCode = rawValue;
    _scannerService.processBarcode(barcode);

    final result = _scannerService.lastResult.value;
    if (result != null) {
      setState(() {
        _scanHistory.insert(0, result);
        if (_scanHistory.length > 10) _scanHistory.removeLast();
      });
    }

    // Auto-process based on scan type
    final action = _scannerService.parseScanAction(rawValue);
    _handleScanAction(action);
  }

  void _handleScanAction(ScanAction action) {
    switch (action.actionType) {
      case 'product_scan':
        _showProductDialog(action);
        break;
      case 'order_packing':
        _navigateToOrderPacking(action.metadata['orderId']);
        break;
      case 'delivery_verification':
        _navigateToDelivery(action.metadata['parcelId']);
        break;
      case 'attendance':
        _navigateToAttendance(action.metadata['attendanceId']);
        break;
      case 'stock_audit':
        _navigateToAudit(action.metadata['auditId']);
        break;
      default:
        _showGenericDialog(action);
    }
  }

  void _showProductDialog(ScanAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Product Scanned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: ${action.code}'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToInventoryReceive(action.code);
                  },
                  icon: Icon(Icons.add_box),
                  label: Text('Receive'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToDamageReport(action.code);
                  },
                  icon: Icon(Icons.report_problem),
                  label: Text('Report'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGenericDialog(ScanAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Scanned: ${action.actionType.replaceAll('_', ' ').toUpperCase()}'),
        content: Text('Code: ${action.displayCode}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToInventoryReceive(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryReceivingScreen(barcode: barcode),
      ),
    );
  }

  void _navigateToDamageReport(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DamageReportingScreen(barcode: barcode),
      ),
    );
  }

  void _navigateToOrderPacking(String orderId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderPackingScreen(orderId: orderId),
      ),
    );
  }

  void _navigateToDelivery(String parcelId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryScreen(parcelId: parcelId),
      ),
    );
  }

  void _navigateToAttendance(String attendanceId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(qrCodeId: attendanceId),
      ),
    );
  }

  void _navigateToAudit(String auditId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryAuditScreen(auditId: auditId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scannerService.toggleFlashlight();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: () {
              _scannerService.clearScannedCodes();
              setState(() => _scanHistory.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner View
          Expanded(
            flex: 3,
            child: MobileScanner(
              onDetect: _onBarcodeDetected,
            ),
          ),

          // Scan Result Display
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: ValueListenableBuilder<ScanResult?>(
              valueListenable: _scannerService.lastResult,
              builder: (context, result, child) {
                if (result == null) {
                  return Text(
                    'Point camera at a barcode or QR code',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Scan:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      result.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Format: ${result.format}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
          ),

          // Quick Actions
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(
                  Icons.add_box,
                  'Receive',
                  () => _navigateToInventoryReceive(''),
                ),
                _buildQuickAction(
                  Icons.inventory_2,
                  'Pack',
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OrderPackingScreen()),
                  ),
                ),
                _buildQuickAction(
                  Icons.delivery_dining,
                  'Deliver',
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => DeliveryScreen()),
                  ),
                ),
                _buildQuickAction(
                  Icons.inventory,
                  'Audit',
                  () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InventoryAuditScreen()),
                  ),
                ),
              ],
            ),
          ),

          // Scan History
          if (_scanHistory.isNotEmpty)
            Container(
              height: 120,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Scans',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scanHistory.length,
                      itemBuilder: (context, index) {
                        final scan = _scanHistory[index];
                        return Container(
                          width: 150,
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scan.code,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                              Spacer(),
                              Text(
                                '${scan.format} • ${_formatTime(scan.timestamp)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.orange),
            SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
