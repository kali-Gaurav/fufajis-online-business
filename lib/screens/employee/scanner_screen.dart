import 'package:flutter/material.dart';
import 'unified_scanner_hub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScannerScreen — thin wrapper kept for backwards-compatibility.
//
// All routes that previously pointed to ScannerScreen now get the full
// UnifiedScannerHub experience with 9 mode tiles and Firestore audit logging.
//
// Usage:
//   ScannerScreen()                     → shows mode picker
//   ScannerScreen(initialMode: 'packing') → opens directly in packing mode
// ─────────────────────────────────────────────────────────────────────────────

class ScannerScreen extends StatelessWidget {
  final String? initialMode;

  const ScannerScreen({super.key, this.initialMode});

  @override
  Widget build(BuildContext context) {
    return UnifiedScannerHub(initialMode: initialMode);
  }
}
