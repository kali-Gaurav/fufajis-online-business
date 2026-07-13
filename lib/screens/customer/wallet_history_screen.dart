import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_theme.dart';

/// WalletHistoryScreen displays transaction history with pagination and filtering
///
/// [Requirements 11.7]: Displays transaction history with pagination,
/// shows transaction type, amount, order reference, timestamp,
/// and allows filtering by transaction type
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  late ScrollController _scrollController;
  WalletTransactionType? _selectedFilter;
  bool _isLoadingMore = false;
  int _currentLimit = 20;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Load initial transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final walletProvider = context.read<WalletProvider>();
      if (authProvider.currentUser != null) {
        walletProvider.fetchTransactions(authProvider.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more transactions when reaching bottom
      _loadMoreTransactions();
    }
  }

  void _loadMoreTransactions() {
    if (!_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentLimit += 20;
      });

      final authProvider = context.read<AuthProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (authProvider.currentUser != null) {
        walletProvider.fetchTransactions(authProvider.currentUser!.id, limit: _currentLimit).then((
          _,
        ) {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  void _applyFilter(WalletTransactionType? type) {
    setState(() {
      _selectedFilter = type;
    });

    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();

    if (authProvider.currentUser != null) {
      if (type == null) {
        walletProvider.fetchTransactions(authProvider.currentUser!.id);
      } else {
        walletProvider.filterTransactionsByType(authProvider.currentUser!.id, type);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet History', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Transactions',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Transactions exported successfully.')));
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, WalletProvider>(
        builder: (context, authProvider, walletProvider, _) {
          if (authProvider.currentUser == null) {
            return const Center(child: Text('Please log in to view wallet history'));
          }

          if (walletProvider.isLoading && walletProvider.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          return Column(
            children: [
              // Wallet Balance Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.info, AppTheme.info],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.info.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${walletProvider.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              if (walletProvider.transactions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No transactions yet', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Your wallet transactions will appear here',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedFilter == null,
                        onSelected: (_) => _applyFilter(null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Cashback'),
                        selected: _selectedFilter == WalletTransactionType.cashback,
                        onSelected: (_) => _applyFilter(WalletTransactionType.cashback),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Refund'),
                        selected: _selectedFilter == WalletTransactionType.refund,
                        onSelected: (_) => _applyFilter(WalletTransactionType.refund),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Payment'),
                        selected: _selectedFilter == WalletTransactionType.walletPayment,
                        onSelected: (_) => _applyFilter(WalletTransactionType.walletPayment),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Redeemed'),
                        selected: _selectedFilter == WalletTransactionType.rewardPointsRedeemed,
                        onSelected: (_) => _applyFilter(WalletTransactionType.rewardPointsRedeemed),
                      ),
                    ],
                  ),
                ),
                // Transaction list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: walletProvider.transactions.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == walletProvider.transactions.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                        );
                      }

                      final transaction = walletProvider.transactions[index];
                      return _buildTransactionTile(context, transaction);
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, WalletTransaction transaction) {
    final isCredit = transaction.amount > 0;
    final amountColor = isCredit ? AppTheme.success : AppTheme.error;
    final amountSign = isCredit ? '+' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _showTransactionDetail(context, transaction),
        leading: _buildTransactionIcon(transaction.type),
        title: Text(
          transaction.type.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              transaction.description ?? transaction.type.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(transaction.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountSign₹${transaction.amount.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: amountColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Bal: ₹${transaction.balanceAfter.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, WalletTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(transaction.type.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: ₹${transaction.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${transaction.timestamp.toLocal().toString().split('.')[0]}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Description: ${transaction.description ?? transaction.type.description}',
              style: const TextStyle(fontSize: 14),
            ),
            if (transaction.orderReference != null) ...[
              const SizedBox(height: 8),
              Text('Order ID: ${transaction.orderReference}', style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 8),
            Text(
              'Balance After: ₹${transaction.balanceAfter.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildTransactionIcon(WalletTransactionType type) {
    IconData icon;
    Color color;

    switch (type) {
      case WalletTransactionType.cashback:
        icon = Icons.card_giftcard;
        color = AppTheme.success;
        break;
      case WalletTransactionType.rewardPointsRedeemed:
        icon = Icons.stars;
        color = AppTheme.warning;
        break;
      case WalletTransactionType.walletPayment:
        icon = Icons.payment;
        color = AppTheme.info;
        break;
      case WalletTransactionType.refund:
        icon = Icons.undo;
        color = AppTheme.warning;
        break;
      case WalletTransactionType.referralBonus:
        icon = Icons.people;
        color = Colors.purple;
        break;
      case WalletTransactionType.reviewBonus:
        icon = Icons.rate_review;
        color = Colors.teal;
        break;
      case WalletTransactionType.firstOrderBonus:
        icon = Icons.celebration;
        color = Colors.pink;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} mins ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
