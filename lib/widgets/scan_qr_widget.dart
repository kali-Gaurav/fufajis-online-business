import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../utils/app_theme.dart';

class ScanQrWidget extends StatelessWidget {
  final String qrData;
  final String label;
  final String? sublabel;
  final Color color;
  final double size;
  final bool canCopy;
  final bool canFullscreen;
  final bool compact;

  const ScanQrWidget._({
    required this.qrData,
    required this.label,
    this.sublabel,
    required this.color,
    this.size = 180,
    this.canCopy = true,
    this.compact = false,
  }) : canFullscreen = true;

  factory ScanQrWidget.order({
    required String orderId,
    String? orderNumber,
    double size = 180,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'ORDER-$orderId',
    label: 'Order QR',
    sublabel: orderNumber != null ? '#$orderNumber' : null,
    color: const Color(0xFF6A1B9A),
    size: size,
    canCopy: true,
    compact: compact,
  );

  factory ScanQrWidget.dispatch({
    required String orderId,
    String? orderNumber,
    double size = 180,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'DISPATCH-$orderId',
    label: 'Dispatch QR',
    sublabel: orderNumber != null ? 'Scan to dispatch #$orderNumber' : null,
    color: const Color(0xFFE65100),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.parcel({
    required String orderId,
    String? orderNumber,
    double size = 180,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'PARCEL-$orderId',
    label: 'Delivery QR',
    sublabel: orderNumber != null ? 'Scan to confirm delivery #$orderNumber' : null,
    color: const Color(0xFF2E7D32),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.member({
    required String customerId,
    String? customerName,
    double size = 180,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'MEMBER-$customerId',
    label: 'Member QR',
    sublabel: customerName,
    color: const Color(0xFFAD1457),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.shelf({
    required String shelfId,
    String? shelfName,
    double size = 160,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'SHELF-$shelfId',
    label: 'Shelf QR',
    sublabel: shelfName ?? shelfId,
    color: const Color(0xFFF57F17),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.attendance({
    required String branchId,
    String? branchName,
    double size = 200,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: 'ATTENDANCE-$branchId',
    label: 'Attendance QR',
    sublabel: branchName ?? 'Scan to check in / out',
    color: const Color(0xFF37474F),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.product({
    required String barcode,
    String? productName,
    double size = 160,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: barcode,
    label: 'Product Barcode',
    sublabel: productName,
    color: const Color(0xFF1565C0),
    size: size,
    compact: compact,
  );

  factory ScanQrWidget.custom({
    required String data,
    required String label,
    String? sublabel,
    Color color = const Color(0xFF455A64),
    double size = 180,
    bool compact = false,
  }) => ScanQrWidget._(
    qrData: data,
    label: label,
    sublabel: sublabel,
    color: color,
    size: size,
    compact: compact,
  );

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                    ),
                    if (sublabel != null)
                      Text(sublabel!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              if (canFullscreen)
                IconButton(
                  icon: const Icon(Icons.fullscreen, size: 20),
                  onPressed: () => _showFullscreen(context),
                  tooltip: 'Enlarge',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showFullscreen(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: size,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  qrData,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: qrData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.copy, size: 14, color: color),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: size,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              if (sublabel != null) ...[
                Text(sublabel!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 280,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                qrData,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrData));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
