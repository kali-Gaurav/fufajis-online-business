import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/scanner_service.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomerMembershipScannerScreen
//
// Employee scans customer's QR (MEMBER-{customerId}) to:
//   - View customer profile (name, phone, tier)
//   - See loyalty points balance
//   - See recent order history
//   - Quick-start a new order for the customer
// ─────────────────────────────────────────────────────────────────────────────

class CustomerMembershipScannerScreen extends StatefulWidget {
  final String? customerId;

  const CustomerMembershipScannerScreen({super.key, this.customerId});

  @override
  State<CustomerMembershipScannerScreen> createState() =>
      _CustomerMembershipScannerScreenState();
}

class _CustomerMembershipScannerScreenState
    extends State<CustomerMembershipScannerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ScannerService _scanner = ScannerService();

  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loading = false;
  String? _errorMsg;
  bool _scanMode = false;
  String _lastCode = '';

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null && widget.customerId!.isNotEmpty) {
      _loadCustomer(widget.customerId!);
    } else {
      _scanMode = true;
      _scanner.startScanning();
    }
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadCustomer(String customerId) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _customer = null;
      _recentOrders = [];
    });
    try {
      final auth = context.read<AuthProvider>();
      final shopId = auth.currentShop?.id ?? 'shop_001';

      // Load user profile
      final userSnap =
          await _db.collection('users').doc(customerId).get();

      if (!userSnap.exists) {
        setState(() {
          _loading = false;
          _errorMsg = 'Member not found (ID: $customerId)';
        });
        return;
      }

      // Load recent orders (last 5)
      final ordersSnap = await _db
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .where('userId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      setState(() {
        _customer = {'id': userSnap.id, ...userSnap.data()!};
        _recentOrders = ordersSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loading = false;
        _scanMode = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Error: $e';
      });
    }
  }

  // ── Scanner ──────────────────────────────────────────────────────────────────

  void _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty || raw == _lastCode) return;

    _lastCode = raw;
    HapticFeedback.mediumImpact();
    await _scanner.stopScanning();

    final customerId = raw
        .replaceFirst('MEMBER-', '')
        .replaceFirst('USER-', '')
        .trim();

    setState(() => _scanMode = false);
    await _loadCustomer(customerId);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Lookup', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFAD1457),
        foregroundColor: Colors.white,
        actions: [
          if (!_scanMode)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                setState(() {
                  _scanMode = true;
                  _customer = null;
                  _recentOrders = [];
                  _errorMsg = null;
                  _lastCode = '';
                });
                _scanner.startScanning();
              },
            ),
        ],
      ),
      body: _scanMode ? _buildScanner() : _buildProfile(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _scanner.controller,
          onDetect: _onBarcodeDetected,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFAD1457), width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Scan Customer Membership QR',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off, size: 64, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_errorMsg!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Again'),
                onPressed: () {
                  setState(() {
                    _scanMode = true;
                    _errorMsg = null;
                    _lastCode = '';
                  });
                  _scanner.startScanning();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_customer == null) return const SizedBox.shrink();

    final name = _customer!['name'] as String? ?? 'Customer';
    final phone = _customer!['phone'] as String? ??
        _customer!['phoneNumber'] as String? ??
        '—';
    final tier = _customer!['membershipTier'] as String? ??
        _customer!['tier'] as String? ??
        'regular';
    final points = _customer!['loyaltyPoints'] as int? ??
        (_customer!['loyaltyPoints'] as num?)?.toInt() ??
        0;
    final totalOrders = _customer!['totalOrders'] as int? ??
        _recentOrders.length;
    final totalSpent = (_customer!['totalSpent'] as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile card
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar + name
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        const Color(0xFFAD1457).withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFAD1457),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(phone,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  _TierBadge(tier: tier),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Loyalty Points',
                  value: '$points pts',
                  icon: Icons.stars,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Total Orders',
                  value: '$totalOrders',
                  icon: Icons.receipt_long,
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Total Spent',
                  value: '₹${totalSpent.toStringAsFixed(0)}',
                  icon: Icons.currency_rupee,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recent orders
          if (_recentOrders.isNotEmpty) ...[
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._recentOrders.map((order) => _OrderRow(order: order)),
          ],

          const SizedBox(height: 16),

          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another Member'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFAD1457),
              side: const BorderSide(color: Color(0xFFAD1457)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _scanMode = true;
                _customer = null;
                _recentOrders = [];
                _lastCode = '';
              });
              _scanner.startScanning();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  final String tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final tierConfig = {
      'gold': (AppTheme.warning, Icons.emoji_events, 'Gold Member'),
      'silver': (AppTheme.infoGrey, Icons.military_tech, 'Silver Member'),
      'platinum': (const Color(0xFF7B1FA2), Icons.diamond, 'Platinum'),
      'regular': (Colors.grey, Icons.person, 'Regular'),
    };

    final (color, icon, label) =
        tierConfig[tier.toLowerCase()] ?? tierConfig['regular']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final number = order['orderNumber'] as String? ?? order['id'];
    final status = order['status'] as String? ?? '';
    final amount =
        (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final ts = (order['createdAt'] as Timestamp?)?.toDate();
    final dateStr =
        ts != null ? DateFormat('dd MMM yy').format(ts) : '—';

    final statusColor = {
          'delivered': AppTheme.success,
          'dispatched': AppTheme.info,
          'packed': Colors.purple,
          'pending': AppTheme.warning,
          'cancelled': AppTheme.error,
        }[status] ??
        Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$number',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
