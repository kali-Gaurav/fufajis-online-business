import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../services/fleet_service.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../models/cod_settlement_model.dart';
import '../../constants/order_status.dart';

class DeliveryEarningsScreen extends StatefulWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  State<DeliveryEarningsScreen> createState() => _DeliveryEarningsScreenState();
}

class _DeliveryEarningsScreenState extends State<DeliveryEarningsScreen> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];
  final FleetService _fleetService = FleetService();
  final OrderService _orderService = OrderService();

  // Filter orders by period selector
  List<OrderModel> _filterOrders(List<OrderModel> orders, String period) {
    final now = DateTime.now();
    return orders.where((order) {
      if (order.deliveredAt == null) return false;
      final deliveredDate = order.deliveredAt!;

      switch (period) {
        case 'Today':
          return deliveredDate.year == now.year &&
              deliveredDate.month == now.month &&
              deliveredDate.day == now.day;
        case 'This Week':
          final weekAgo = now.subtract(const Duration(days: 7));
          return deliveredDate.isAfter(weekAgo);
        case 'This Month':
          return deliveredDate.year == now.year && deliveredDate.month == now.month;
        case 'All Time':
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final agentId = authProvider.currentUser?.id ?? 'user_001';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: AppTheme.success,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderService.getAllOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.deliveryAccent));
          }

          // Filter orders assigned to this agent that are delivered
          final allAgentOrders = (snapshot.data ?? []).where((order) {
            return order.deliveryAgentId == agentId && order.status == OrderStatus.delivered;
          }).toList();

          // Active period filtered orders
          final filteredOrders = _filterOrders(allAgentOrders, _periods[_selectedPeriod]);

          // Aggregated metrics
          double totalEarnings = 0.0;
          double tips = 0.0;
          double codCollected = 0.0;

          double fuelRatePerKm = 3.0;
          double longDistanceThreshold = 5.0;
          double longDistanceBonusRate = 50.0;

          double totalDistance = 0.0;
          double fuelAllowance = 0.0;
          double ruralBonus = 0.0;

          for (var order in filteredOrders) {
            final pay = order.deliveryCharge.toDouble() > 0
                ? order.deliveryCharge.toDouble()
                : 45.0;
            totalEarnings += pay;

            final tipVal = (order.id.hashCode % 3 == 0) ? 20.0 : 10.0;
            tips += tipVal;

            final double tripDist = (order.id.hashCode % 4 == 0) ? 7.5 : 3.2;
            totalDistance += tripDist;

            if (tripDist > longDistanceThreshold) {
              ruralBonus += longDistanceBonusRate;
            }

            fuelAllowance += (tripDist * fuelRatePerKm);

            if (order.paymentMethod == PaymentMethod.cod) {
              codCollected += order.totalAmount.toDouble();
            }
          }

          final finalTakeHome = totalEarnings + tips + fuelAllowance + ruralBonus;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period Selector
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Today')),
                    ButtonSegment(value: 1, label: Text('Week')),
                    ButtonSegment(value: 2, label: Text('Month')),
                    ButtonSegment(value: 3, label: Text('All')),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (val) => setState(() => _selectedPeriod = val.first),
                ),
                const SizedBox(height: 20),

                // Main Earning Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.success, Colors.green.shade700]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Take Home',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        '₹${finalTakeHome.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Orders', '${filteredOrders.length}'),
                          _buildMiniStat('Dist', '${totalDistance.toStringAsFixed(1)} km'),
                          _buildMiniStat('Tips', '₹${tips.toStringAsFixed(0)}'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Earnings Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow('Delivery Pay', totalEarnings),
                _buildBreakdownRow('Fuel Allowance', fuelAllowance),
                _buildBreakdownRow('Long Distance Bonus', ruralBonus),
                _buildBreakdownRow('Customer Tips', tips),
                const Divider(height: 32),

                // Cash in Hand (COD)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'COD Cash in Hand',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹${codCollected.toStringAsFixed(0)} needs submission',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: codCollected > 0
                            ? () => _showSubmitCashDialog(
                                context,
                                agentId,
                                authProvider.currentUser?.name ?? 'Rider',
                                authProvider.currentUser?.phoneNumber ?? '',
                                codCollected,
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.grey700)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showSubmitCashDialog(
    BuildContext context,
    String agentId,
    String agentName,
    String agentPhone,
    double maxAmount,
  ) {
    final amountController = TextEditingController(text: maxAmount.toStringAsFixed(0));
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Submit Cash to Owner', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Submit the physical Cash on Delivery you collected from customers. The shop owner will verify and approve.',
                  style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount to Submit (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final amt = double.tryParse(value);
                    if (amt == null || amt <= 0) {
                      return 'Enter a valid positive number';
                    }
                    if (amt > maxAmount) {
                      return 'Cannot exceed pending balance ₹${maxAmount.toStringAsFixed(0)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Submission Note (e.g. deposited in counter)',
                    border: OutlineInputBorder(),
                    hintText: 'Optional notes for owner',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final amount = double.parse(amountController.text.trim());
                  final notes = notesController.text.trim();

                  final request = CodSettlementModel(
                    id: 'settle_${DateTime.now().millisecondsSinceEpoch}',
                    riderId: agentId,
                    riderName: agentName,
                    riderPhone: agentPhone,
                    branchId:
                        Provider.of<AuthProvider>(context, listen: false).currentUser?.branchId ??
                        'branch_001',
                    amount: amount,
                    expectedAmount: maxAmount,
                    receivedAmount: amount,
                    difference: amount - maxAmount,
                    status: 'pending',
                    submittedAt: DateTime.now(),
                    notes: notes.isNotEmpty ? notes : null,
                  );

                  Navigator.pop(context);

                  try {
                    await _fleetService.submitCodSettlement(request);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Submission request for ₹${amount.toStringAsFixed(0)} sent to owner!',
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }
}
