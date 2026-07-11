import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

enum TransactionFilterType { all, income, expense, refund }

class WalletPaymentDashboardScreen extends StatefulWidget {
  const WalletPaymentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WalletPaymentDashboardScreen> createState() => _WalletPaymentDashboardScreenState();
}

class _WalletPaymentDashboardScreenState extends State<WalletPaymentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransactionFilterType _currentFilter = TransactionFilterType.all;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await walletProvider.fetchTransactions(authProvider.currentUser!.id);
    }
  }

  List<dynamic> _getFilteredTransactions(List<dynamic> transactions) {
    List<dynamic> filtered = transactions;

    // Filter by type
    switch (_currentFilter) {
      case TransactionFilterType.income:
        filtered = filtered.where((t) => t.amount > 0).toList();
        break;
      case TransactionFilterType.expense:
        filtered = filtered.where((t) => t.amount < 0).toList();
        break;
      case TransactionFilterType.refund:
        filtered = filtered
            .where((t) => t.description?.contains('Refund') ?? false)
            .toList();
        break;
      default:
        break;
    }

    // Filter by date range
    if (_selectedStartDate != null && _selectedEndDate != null) {
      filtered = filtered.where((t) {
        final txDate = t.timestamp;
        return txDate.isAfter(_selectedStartDate!) &&
            txDate.isBefore(_selectedEndDate!.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          _selectedStartDate != null && _selectedEndDate != null
              ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
              : DateTimeRange(start: thirtyDaysAgo, end: now),
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Wallet & Payments', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          onTap: (index) {
            setState(() {
              _currentFilter = TransactionFilterType.values[index];
            });
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Income'),
            Tab(text: 'Spending'),
            Tab(text: 'Refunds'),
          ],
        ),
      ),
      body: Consumer2<WalletProvider, AuthProvider>(
        builder: (context, walletProvider, authProvider, _) {
          final userId = authProvider.currentUser?.id ?? '';
          final transactions = _getFilteredTransactions(walletProvider.transactions);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Balance Card
                _buildBalanceCard(walletProvider),

                // Stats Cards
                _buildStatsCards(walletProvider, transactions),

                // Filter Section
                _buildFilterSection(),

                // Transactions List
                if (walletProvider.isLoading)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else if (transactions.isEmpty)
                  _buildEmptyState()
                else
                  _buildTransactionsList(transactions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(WalletProvider walletProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹ ${0}', // Placeholder, update with actual balance
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/customer/my-wallet'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Money to Wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(WalletProvider walletProvider, List<dynamic> transactions) {
    final totalIncome =
        transactions.where((t) => t.amount > 0).fold(0.0, (s, t) => s + t.amount);
    final totalExpense =
        transactions.where((t) => t.amount < 0).fold(0.0, (s, t) => s + t.amount.abs());
    final transactionCount = transactions.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'Total Added',
              value: '₹${totalIncome.toStringAsFixed(0)}',
              icon: Icons.arrow_downward,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              label: 'Total Spent',
              value: '₹${totalExpense.toStringAsFixed(0)}',
              icon: Icons.arrow_upward,
              color: AppTheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              label: 'Transactions',
              value: transactionCount.toString(),
              icon: Icons.receipt_long,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showFilters) ...[
            const Text(
              'Filter by Date',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedStartDate != null && _selectedEndDate != null
                          ? '${DateFormat('MMM d').format(_selectedStartDate!)} - ${DateFormat('MMM d').format(_selectedEndDate!)}'
                          : 'Select Date Range',
                    ),
                  ),
                ),
                if (_selectedStartDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.clear, color: AppTheme.error),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_list),
              label: Text(_showFilters ? 'Hide Filters' : 'Show Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<dynamic> transactions) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionTile(transaction);
      },
    );
  }

  Widget _buildTransactionTile(dynamic transaction) {
    final isIncome = transaction.amount > 0;
    final amount = transaction.amount.abs();
    final date = transaction.timestamp;
    final formattedDate = DateFormat('MMM d, yyyy').format(date);
    final formattedTime = DateFormat('hh:mm a').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isIncome ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? AppTheme.success : AppTheme.error,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ?? (isIncome ? 'Money Added' : 'Payment'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedDate • $formattedTime',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isIncome ? '+₹${amount.toStringAsFixed(0)}' : '-₹${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isIncome ? AppTheme.success : AppTheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getStatusLabel(transaction),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.grey600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 40,
                color: AppTheme.grey400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Transactions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.grey800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No transactions found for the selected filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(dynamic transaction) {
    if (transaction.status == 'completed') {
      return 'Completed';
    } else if (transaction.status == 'pending') {
      return 'Pending';
    } else if (transaction.status == 'failed') {
      return 'Failed';
    }
    return transaction.status ?? 'Unknown';
  }
}
