import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/order_model.dart';
import '../../models/payment_method.dart';
import '../../models/cod_settlement_model.dart';
import 'package:uuid/uuid.dart';

class DeliveryEarningsScreen extends StatefulWidget {
  const DeliveryEarningsScreen({super.key});

  @override
  State<DeliveryEarningsScreen> createState() => _DeliveryEarningsScreenState();
}

class _DeliveryEarningsScreenState extends State<DeliveryEarningsScreen> {
  int _selectedPeriod = 0;
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'All Time'];
  final FirestoreService _firestoreService = FirestoreService();

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

    return StreamBuilder<List<OrderModel>>(
      stream: _firestoreService.getAllOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.secondary));
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
        int longDistanceTrips = 0;
        double fuelAllowance = 0.0;
        double ruralBonus = 0.0;

        for (var order in filteredOrders) {
          final pay = order.deliveryCharge > 0 ? order.deliveryCharge : 45.0;

          final tipVal = (order.id.hashCode % 3 == 0) ? 20.0 : 10.0;
          tips += tipVal;

          final double tripDist = (order.id.hashCode % 4 == 0) ? 7.5 : 3.2;
          totalDistance += tripDist;

          if (tripDist > longDistanceThreshold) {
            longDistanceTrips++;
            ruralBonus += longDistanceBonusRate;
          }

          fuelAllowance += (tripDist * fuelRatePerKm);
          totalEarnings += (pay + tipVal);

          if (order.paymentMethod == PaymentMethod.cod) {
            codCollected += order.totalAmount;
          }
        }

        // Add incentives to total earnings
        totalEarnings += (fuelAllowance + ruralBonus);

        // Aggregate All Time (or period totals) for sub-widgets
        double todayVal = 0.0;
        double weekVal = 0.0;
        double monthVal = 0.0;
        
        for (var order in allAgentOrders) {
          final pay = order.deliveryCharge > 0 ? order.deliveryCharge : 45.0;
          final tipVal = (order.id.hashCode % 3 == 0) ? 20.0 : 10.0;

          final double tripDist = (order.id.hashCode % 4 == 0) ? 7.5 : 3.2;
          final double fuel = tripDist * fuelRatePerKm;
          final double bonus = (tripDist > longDistanceThreshold) ? longDistanceBonusRate : 0.0;
          final earned = pay + tipVal + fuel + bonus;

          final deliveredDate = order.deliveredAt ?? DateTime.now();
          final now = DateTime.now();

          // Today
          if (deliveredDate.year == now.year && deliveredDate.month == now.month && deliveredDate.day == now.day) {
            todayVal += earned;
          }
          // Week
          if (deliveredDate.isAfter(now.subtract(const Duration(days: 7)))) {
            weekVal += earned;
          }
          // Month
          if (deliveredDate.year == now.year && deliveredDate.month == now.month) {
            monthVal += earned;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Earnings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                  // Period Selector
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                        )
                      ]
                    ),
                    child: Row(
                      children: List.generate(_periods.length, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPeriod = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPeriod == index ? AppTheme.secondary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _periods[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _selectedPeriod == index ? FontWeight.bold : FontWeight.normal,
                                color: _selectedPeriod == index ? AppTheme.white : AppTheme.grey700,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Dynamic Earnings Card
              _buildEarningsCard(totalEarnings, todayVal, weekVal, monthVal),
              const SizedBox(height: 24),
              
              // Stats Grid
              _buildStatsGrid(filteredOrders.length, totalDistance, tips, codCollected),
              const SizedBox(height: 24),

              // Fuel & Travel Incentives breakdown card
              _buildIncentivesPanel(totalDistance, fuelAllowance, longDistanceTrips, ruralBonus),
              const SizedBox(height: 24),
              
              // Earnings History Logs
              _buildEarningsHistory(filteredOrders),
              const SizedBox(height: 24),
              
              // Withdraw Section
              _buildWithdrawSection(totalEarnings),
              const SizedBox(height: 24),

              // COD Collection Logbook Section
              _buildCodCollectionLedger(
                agentId,
                authProvider.currentUser?.name ?? 'Rider',
                authProvider.currentUser?.phoneNumber ?? '',
                codCollected,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningsCard(double total, double today, double week, double month) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998e).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, color: AppTheme.white),
              const SizedBox(width: 8),
              Text(
                'Calculated Period Pay',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppTheme.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEarningsStat('₹${today.toStringAsFixed(0)}', 'Today'),
              Container(width: 1, height: 30, color: AppTheme.white.withValues(alpha: 0.3)),
              _buildEarningsStat('₹${week.toStringAsFixed(0)}', 'This Week'),
              Container(width: 1, height: 30, color: AppTheme.white.withValues(alpha: 0.3)),
              _buildEarningsStat('₹${month.toStringAsFixed(0)}', 'This Month'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsStat(String amount, String label) {
    return Column(
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(int tripCount, double distance, double tips, double cod) {
    final stats = [
      {'title': 'Trips Done', 'value': '$tripCount', 'icon': Icons.local_shipping, 'color': AppTheme.primary},
      {'title': 'Distance (Est)', 'value': '${distance.toStringAsFixed(1)} km', 'icon': Icons.directions_bike, 'color': AppTheme.info},
      {'title': 'Tips Shared', 'value': '₹${tips.toStringAsFixed(0)}', 'icon': Icons.volunteer_activism, 'color': AppTheme.warning},
      {'title': 'COD Collected', 'value': '₹${cod.toStringAsFixed(0)}', 'icon': Icons.payments, 'color': AppTheme.success},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                stat['value'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['title'] as String,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.grey500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncentivesPanel(double totalDistance, double fuelAllowance, int longDistanceCount, double ruralBonus) {
    final totalIncentive = fuelAllowance + ruralBonus;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_gas_station, color: AppTheme.info),
                  SizedBox(width: 8),
                  Text(
                    'Fuel & Travel Incentives',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+₹${totalIncentive.toStringAsFixed(0)} Earned',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Riders receive automatic fuel payouts per kilometer plus bonus incentives for long-distance rural runs.',
            style: TextStyle(fontSize: 12, color: AppTheme.grey600),
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Travel Distance', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                    const SizedBox(height: 4),
                    Text('${totalDistance.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Base Fuel Pay (₹3/km)', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                    const SizedBox(height: 4),
                    Text('₹${fuelAllowance.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rural Trips (>5 km)', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                    const SizedBox(height: 4),
                    Text('$longDistanceCount trips', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rural Bonus (₹50/trip)', style: TextStyle(fontSize: 12, color: AppTheme.grey500)),
                    const SizedBox(height: 4),
                    Text('₹${ruralBonus.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.success)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsHistory(List<OrderModel> orders) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earnings History Logs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No completed deliveries found in this period.',
                  style: TextStyle(color: AppTheme.grey500),
                ),
              ),
            )
          else
            ...orders.map((order) {
              final pay = order.deliveryCharge > 0 ? order.deliveryCharge : 45.0;
              final tipVal = (order.id.hashCode % 3 == 0) ? 20.0 : 10.0;
              
              final double tripDist = (order.id.hashCode % 4 == 0) ? 7.5 : 3.2;
              final double fuel = tripDist * 3.0;
              final double bonus = (tripDist > 5.0) ? 50.0 : 0.0;
              final total = pay + tipVal + fuel + bonus;
              
              final timeStr = DateFormat('MMM dd, hh:mm a').format(order.deliveredAt ?? order.createdAt);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delivery_dining,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.grey900,
                            ),
                          ),
                          Text(
                            'Fare: ₹${pay.toStringAsFixed(0)} | Fuel: ₹${fuel.toStringAsFixed(0)} | Rural Bonus: ₹${bonus.toStringAsFixed(0)} | Tip: ₹${tipVal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(fontSize: 10, color: AppTheme.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildWithdrawSection(double availableAmount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Withdraw Earnings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Period Balance',
                      style: TextStyle(fontSize: 14, color: AppTheme.grey500),
                    ),
                    Text(
                      '₹${availableAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: availableAmount > 0
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payout request of ₹${availableAmount.toStringAsFixed(0)} submitted successfully!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.account_balance),
                label: const Text('Withdraw'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bank Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'State Bank of India ****8829',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Direct UPI IMPS payout linked successfully',
                        style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Change', style: TextStyle(color: AppTheme.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodCollectionLedger(
      String agentId, String agentName, String agentPhone, double totalCodCollected) {
    return StreamBuilder<List<CodSettlementModel>>(
      stream: _firestoreService.getCodSettlementsStream(agentId),
      builder: (context, snapshot) {
        final settlements = snapshot.data ?? [];
        
        double approvedSettlements = 0.0;
        double pendingSettlements = 0.0;
        
        for (var s in settlements) {
          if (s.status == 'approved') {
            approvedSettlements += s.amount;
          } else if (s.status == 'pending') {
            pendingSettlements += s.amount;
          }
        }
        
        final cashInHand = totalCodCollected - approvedSettlements;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.menu_book, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'COD Collection Logbook',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // COD balance breakdown
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLedgerMetric('₹${totalCodCollected.toStringAsFixed(0)}', 'Total Collected', AppTheme.grey700),
                  _buildLedgerMetric('₹${approvedSettlements.toStringAsFixed(0)}', 'Submitted (Approved)', AppTheme.success),
                  _buildLedgerMetric('₹${pendingSettlements.toStringAsFixed(0)}', 'In Transit (Pending)', AppTheme.warning),
                ],
              ),
              const Divider(height: 32),
              
              // Cash in hand card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PENDING CASH IN HAND',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${cashInHand.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Submit this cash to the shop owner to clear your dues.',
                            style: TextStyle(fontSize: 11, color: AppTheme.grey600),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: cashInHand > 0
                          ? () => _showSubmitCashDialog(context, agentId, agentName, agentPhone, cashInHand)
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit Cash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Settlement Request History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey800,
                ),
              ),
              const SizedBox(height: 12),
              
              if (settlements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No cash submissions found.',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: settlements.length > 5 ? 5 : settlements.length,
                  itemBuilder: (context, index) {
                    final s = settlements[index];
                    final dateStr = DateFormat('MMM dd, yyyy').format(s.submittedAt);
                    
                    Color statusColor = AppTheme.warning;
                    IconData statusIcon = Icons.pending_actions;
                    if (s.status == 'approved') {
                      statusColor = AppTheme.success;
                      statusIcon = Icons.check_circle_outline;
                    } else if (s.status == 'rejected') {
                      statusColor = AppTheme.error;
                      statusIcon = Icons.error_outline;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash Submission Request',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.grey800,
                                  ),
                                ),
                                Text(
                                  '$dateStr${s.notes != null && s.notes!.isNotEmpty ? ' • ${s.notes}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${s.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.grey900,
                                ),
                              ),
                              Text(
                                s.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLedgerMetric(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.grey500,
          ),
        ),
      ],
    );
  }

  void _showSubmitCashDialog(BuildContext context, String agentId, String agentName, String agentPhone, double maxAmount) {
    final amountController = TextEditingController(text: maxAmount.toStringAsFixed(0));
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Submit Cash to Owner'),
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
                    amount: amount,
                    status: 'pending',
                    submittedAt: DateTime.now(),
                    notes: notes.isNotEmpty ? notes : null,
                  );

                  Navigator.pop(context);
                  
                  try {
                    await _firestoreService.submitCodSettlement(request);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Submission request for ₹${amount.toStringAsFixed(0)} sent to owner!'),
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

