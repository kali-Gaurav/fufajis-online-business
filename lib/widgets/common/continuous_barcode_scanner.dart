import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/scanner_service.dart';
import '../../utils/app_theme.dart';
import 'fj_button.dart';

class ContinuousBarcodeScannerDialog extends StatefulWidget {
  final Function(String) onBarcodeScanned;
  final String title;

  const ContinuousBarcodeScannerDialog({
    super.key,
    required this.onBarcodeScanned,
    this.title = 'Continuous Scanner',
  });

  @override
  State<ContinuousBarcodeScannerDialog> createState() => _ContinuousBarcodeScannerDialogState();
}

class _ContinuousBarcodeScannerDialogState extends State<ContinuousBarcodeScannerDialog> {
  final ScannerService _scanner = ScannerService();
  String _lastCode = '';
  String? _statusMsg;
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _scanner.startScanning();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final code = barcode.rawValue ?? '';
    if (code.isEmpty || code == _lastCode) return;

    _lastCode = code;
    _handleCode(code);
  }

  void _handleCode(String code) {
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);
    widget.onBarcodeScanned(code);

    setState(() {
      _statusMsg = 'Scanned: $code';
      _statusColor = AppTheme.success;
    });

    // Reset status msg after 1.5 seconds to allow scanning same item again
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _statusMsg = null;
          _lastCode = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          MobileScanner(controller: _scanner.controller, onDetect: _onDetect),

          // Overlay UI
          Positioned.fill(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  title: Text(widget.title),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.flash_on),
                      onPressed: () => _scanner.toggleFlashlight(),
                    ),
                  ],
                ),
                const Spacer(),

                // Scan target area
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const Spacer(),

                // Status Indicator
                if (_statusMsg != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _statusMsg!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FjButton(
                    label: 'Done Scanning',
                    onPressed: () => Navigator.pop(context),
                    width: double.infinity,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
