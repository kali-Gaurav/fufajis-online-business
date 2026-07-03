import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/employee_scanner_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';

class DeliveryScreen extends StatefulWidget {
  final String? parcelId;

  const DeliveryScreen({super.key, this.parcelId});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  OrderModel? _currentOrder;
  bool _isLoading = false;
  final _otpController = TextEditingController();
  String _deliveryStatus = '';

  @override
  void initState() {
    super.initState();
    if (widget.parcelId != null) {
      _loadOrderByParcel(widget.parcelId!);
    }
  }

  Future<void> _loadOrderByParcel(String parcelId) async {
    setState(() => _isLoading = true);
    try {
      final orderProvider = context.read<OrderProvider>();
      final order = await orderProvider.getOrderByParcelId(parcelId);
      setState(() {
        _currentOrder = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Order not found for parcel: $parcelId');
    }
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

  Future<void> _verifyDelivery() async {
    if (_currentOrder == null) return;

    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      _showError('Please enter customer OTP');
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

      await service.verifyDelivery(
        orderId: _currentOrder!.id,
        parcelId: _currentOrder!.parcelId ?? '',
        customerOtp: otp,
      );

      setState(() {
        _deliveryStatus = 'delivered';
        _isLoading = false;
      });

      _showSuccess('Delivery completed successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Verification failed: $e');
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _showScannerDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _currentOrder == null
          ? _buildNoDeliveryView()
          : _buildDeliveryView(),
    );
  }

  Widget _buildNoDeliveryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.delivery_dining, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No Delivery Assigned', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Scan a parcel QR code to start delivery',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showScannerDialog(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Parcel QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryView() {
    final order = _currentOrder!;
    final isDelivered = _deliveryStatus == 'delivered';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Delivery Status Card
          Card(
            color: isDelivered
                ? AppTheme.success.withValues(alpha: 0.1)
                : AppTheme.info.withValues(alpha: 0.1),
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
                        label: Text(order.status.name.replaceAll('_', ' ').toUpperCase()),
                        color: WidgetStateProperty.all(
                          isDelivered ? AppTheme.success : AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.person, 'Customer', order.customerName),
                  _buildInfoRow(Icons.phone, 'Phone', order.customerPhone),
                  _buildInfoRow(Icons.location_on, 'Address', order.deliveryAddress.fullAddress),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Order Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Items to Deliver', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...order.items.map(
                    (item) => ListTile(
                      title: Text(item.productName),
                      subtitle: Text('Qty: ${item.quantity}'),
                      trailing: Text('₹${item.price * item.quantity}'),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '₹${order.totalAmount}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // OTP Verification
          if (!isDelivered) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer OTP Verification',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ask the customer for their OTP to complete delivery',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'Enter OTP',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyDelivery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Complete Delivery'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Success Message
          if (isDelivered)
            Card(
              color: AppTheme.success.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 64, color: AppTheme.success),
                    const SizedBox(height: 16),
                    Text('Delivery Completed!', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Stock finalized, loyalty points awarded, invoice finalized',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Parcel ID', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Parcel ID (e.g., PARCEL-12345)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              if (value.startsWith('PARCEL-')) {
                _loadOrderByParcel(value);
              } else {
                _loadOrderByParcel('PARCEL-$value');
              }
            }
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
  }
}
