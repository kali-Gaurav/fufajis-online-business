import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/app_theme.dart';

/// Custom scanner overlay with scan area guide
class ScannerOverlay extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture)? onDetect;
  final Widget? child;

  const ScannerOverlay({super.key, required this.controller, this.onDetect, this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(controller: controller, onDetect: onDetect ?? (capture) {}),
        // Overlay with transparent center
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = MediaQuery.of(context).size;
              final scanAreaSize = size.width * 0.7;

              return Stack(
                children: [
                  // Darkened background
                  Container(color: Colors.black.withValues(alpha: 0.6)),
                  // Transparent scan area
                  Center(
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.warning, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(width: scanAreaSize, height: 2, color: AppTheme.warning),
                        ],
                      ),
                    ),
                  ),
                  // Corner decorations
                  Positioned(
                    left: size.width / 2 - scanAreaSize / 2 + 8,
                    top: size.height / 2 - scanAreaSize / 2 + 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.white, width: 4),
                          top: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: size.width / 2 - scanAreaSize / 2 + 8,
                    top: size.height / 2 - scanAreaSize / 2 + 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 4),
                          top: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: size.width / 2 - scanAreaSize / 2 + 8,
                    bottom: size.height / 2 - scanAreaSize / 2 + 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.white, width: 4),
                          bottom: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: size.width / 2 - scanAreaSize / 2 + 8,
                    bottom: size.height / 2 - scanAreaSize / 2 + 8,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white, width: 4),
                          bottom: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Instructions
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Position barcode within the frame',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

/// Compact scanner widget for embedding in forms
class CompactScanner extends StatelessWidget {
  final void Function(String) onCode;
  final String? initialCode;

  const CompactScanner({super.key, required this.onCode, this.initialCode});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: MobileScanner(
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null) {
                  onCode(code);
                }
              },
            ),
          ),
          if (initialCode != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(initialCode!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => onCode('')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
