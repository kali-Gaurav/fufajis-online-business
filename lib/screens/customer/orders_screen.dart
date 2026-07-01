import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../providers/order_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/order_model.dart';
import '../../widgets/scratch_card_widget.dart';
import '../../services/reorder_service.dart';
import '../../utils/app_theme.dart';
import '../../constants/order_status.dart';
import '../../widgets/fj_empty_state.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late ScrollController _scrollController;
  int _selectedTab = 0;
  final List<String> _tabs = ['All', 'Active', 'Completed', 'Cancelled'];
  Set<String> _claimedRewards = {};
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadClaimedRewards();
    
    // Load initial orders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.fetchOrders();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore) return;
    
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    if (!orderProvider.hasMoreOrders) return;

    setState(() => _isLoadingMore = true);
    await orderProvider.fetchOrders(page: orderProvider.ordersPage + 1);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadClaimedRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('claimed_rewards') ?? [];
    setState(() {
      _claimedRewards = list.toSet();
    });
  }

  Future<void> _markRewardClaimed(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _claimedRewards.add(orderId);
    });
    await prefs.setStringList('claimed_rewards', _claimedRewards.toList());
  }

  /// Filters orders based on selected tab
  List<OrderModel> _getFilteredOrders(List<OrderModel> allOrders) {
    switch (_selectedTab) {
      case 1: // Active
        return allOrders.where((order) => order.status.isActive).toList();
      case 2: // Completed
        return allOrders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();
      case 3: // Cancelled
        return allOrders
            .where((order) =>
                order.status == OrderStatus.cancelled ||
                order.status == OrderStatus.returned)
            .toList();
      default: // All
        return allOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);
    final filteredOrders = _getFilteredOrders(orderProvider.orders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
      ),
      body: Column(
        children: [
          // Status Filter Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
                children: List.generate(_tabs.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTab == index
                              ? AppTheme.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedTab == index
                              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                              : null,
                        ),
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTab == index
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: _selectedTab == index
                                ? Colors.white
                                : AppTheme.grey700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ),
          // Orders List with Pagination
          Expanded(
            child: orderProvider.isLoading && filteredOrders.isEmpty
                ? const OrderListSkeleton(count: 4)
                : filteredOrders.isEmpty
                    ? _buildEmptyOrders()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length +
                            (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filteredOrders.length) {
                            return _buildLoadingIndicator();
                          }
                          final order = filteredOrders[index];
                          return SpringCard(
                            delay: Duration(milliseconds: index * 55),
                            springDistance: 40,
                            child: _buildOrderCard(order),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return FjEmptyState(
      icon: Icons.shopping_bag_outlined,
      title: 'No orders yet',
      subtitle: 'Start shopping to see your orders here',
      buttonLabel: 'Start Shopping',
      onButtonTap: () => context.go('/customer/home'),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = order.status.color;
    final statusText = order.status.displayName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      order.status.icon,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          // Items Preview
          ...order.items.take(2).map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.grey100,
                    ),
                    child: item.productImage.isNotEmpty
                        ? Image.network(
                            item.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image_not_supported);
                            },
                          )
                        : const Icon(Icons.shopping_bag),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} x ${item.unit} @ ₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (order.items.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${order.items.length - 2} more items',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          // Order Footer with Total and Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Reorder Button (delivered orders)
                    if (order.status == OrderStatus.delivered)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _handleReorder(order),
                          icon: const Icon(Icons.replay, size: 14),
                          label: const Text(
                            'Reorder',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    // Claim Reward Button
                    if (order.status == OrderStatus.delivered &&
                        !_claimedRewards.contains(order.id))
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () => _openScratchCardDialog(order),
                          icon: const Icon(Icons.card_giftcard, size: 14),
                          label: const Text(
                            'Claim',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    // Track Order Button
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push('/customer/track/${order.id}'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Track',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // View Details Button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.push('/customer/order-detail/${order.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Handle reorder: populate cart from previous order with validation feedback
  Future<void> _handleReorder(OrderModel order) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );

    final result = await ReorderService().populateCartFromOrder(
      order: order,
      cartProvider: cartProvider,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (result.success) {
      // Show feedback with details
      String message = result.summaryMessage;
      
      if (result.hasUnavailableItems) {
        message += '\nUnavailable: ${result.unavailableItems.join(", ")}';
      }
      if (result.hasPriceChanges) {
        message += '\nPrices updated for: ${result.priceChangedItems.length} items';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.hasUnavailableItems ? AppTheme.warning : AppTheme.success,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'VIEW CART',
            textColor: Colors.white,
            onPressed: () => context.push('/customer/cart'),
          ),
        ),
      );

      // Navigate to cart
      context.push('/customer/cart');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summaryMessage),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _openScratchCardDialog(dynamic order) {
    final random = Random();
    // Cashback amount between 5 and 50
    final rewardAmount = (random.nextInt(46) + 5).toDouble();
    bool rewardCredited = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            child: ScratchCardWidget(
              onThresholdReached: () {
                if (!rewardCredited) {
                  rewardCredited = true;
                  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                  orderProvider.addToWallet(rewardAmount);
                  _markRewardClaimed(order.id);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Congratulations! ₹${rewardAmount.round()} cashback added to your wallet!'),
                      backgroundColor: AppTheme.success,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.stars,
                    color: AppTheme.primary,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'YOU WON CASHBACK!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.grey600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${rewardAmount.round()}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Credited to Wallet',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
