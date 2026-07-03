import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/khata_transaction.dart';
import '../../services/khata_service.dart';
import '../../services/whatsapp_notification_service.dart';

class BahiKhataScreen extends StatefulWidget {
  const BahiKhataScreen({super.key});

  @override
  State<BahiKhataScreen> createState() => _BahiKhataScreenState();
}

class _BahiKhataScreenState extends State<BahiKhataScreen> {
  final TextEditingController _searchController = TextEditingController();
  final KhataService _khataService = KhataService();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Bahi-Khata', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () => _showKhataInfo()),
        ],
      ),
      body: Column(
        children: [
          // Total Credit Overview
          _buildSummaryHeader(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // Customer List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('creditBalance', isGreaterThan: 0)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.ownerAccent),
                  );
                }

                final users = snapshot.data!.docs
                    .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                    .where(
                      (user) =>
                          user.name?.toLowerCase().contains(_searchQuery) == true ||
                          user.phoneNumber.contains(_searchQuery),
                    )
                    .toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No customers with outstanding credit.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) => _buildCustomerCreditCard(users[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualCredit,
        icon: const Icon(Icons.add),
        label: const Text('Add Transaction'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('creditBalance', isGreaterThan: 0)
            .snapshots(),
        builder: (context, snapshot) {
          double total = 0;
          int count = 0;
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              total += (doc.data() as Map<String, dynamic>)['creditBalance'] ?? 0.0;
              count++;
            }
          }
          return Column(
            children: [
              const Text(
                'Total Outstanding Credit',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'from $count customers',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomerCreditCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.info.withValues(alpha: 0.1),
          child: Text(
            user.name?[0].toUpperCase() ?? '?',
            style: const TextStyle(color: AppTheme.info, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.phoneNumber),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Owes', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
            Text(
              '₹${user.creditBalance}',
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        onTap: () => _showCreditDetail(user),
      ),
    );
  }

  void _showCreditDetail(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.name ?? 'Customer',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Outstanding: ₹${user.creditBalance}',
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showPaymentDialog(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('RECORD PAYMENT'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final success = await WhatsAppNotificationService.sendLedgerReminder(
                        phoneNumber: user.phoneNumber,
                        customerName: user.name ?? 'Customer',
                        outstandingAmount: user.creditBalance,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Reminder sent via WhatsApp!'
                                  : 'Failed to send WhatsApp reminder.',
                            ),
                            backgroundColor: success ? AppTheme.success : AppTheme.error,
                          ),
                        );
                      }
                    },
                    child: const Text('REMIND'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Recent Khata History', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<KhataTransaction>>(
                stream: _khataService.getCustomerKhataStream(user.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.ownerAccent),
                    );
                  }
                  final txs = snapshot.data!;
                  if (txs.isEmpty) {
                    return const Center(child: Text('No transaction history.'));
                  }

                  return ListView.builder(
                    itemCount: txs.length,
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final isCredit = tx.type == KhataTransactionType.credit;
                      return ListTile(
                        leading: Icon(
                          isCredit ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          color: isCredit ? AppTheme.error : AppTheme.success,
                        ),
                        title: Text(isCredit ? 'Credit Added' : 'Payment Received'),
                        subtitle: Text(tx.timestamp.toString().substring(0, 16)),
                        trailing: Text(
                          '₹${tx.amount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCredit ? AppTheme.error : AppTheme.success,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog(UserModel user) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount Paid (₹)', prefixText: '₹'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              double paid = double.tryParse(amountController.text) ?? 0;
              if (paid > 0) {
                final tx = KhataTransaction(
                  id: 'khata_${DateTime.now().millisecondsSinceEpoch}',
                  userId: user.id,
                  shopId: 'shop_001',
                  amount: paid,
                  type: KhataTransactionType.payment,
                  timestamp: DateTime.now(),
                  note: 'Manual payment record',
                );
                await _khataService.addKhataTransaction(tx);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context); // Close bottom sheet too
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddManualCredit() {
    showDialog(
      context: context,
      builder: (context) {
        UserModel? selectedUser;
        final amountController = TextEditingController();
        final noteController = TextEditingController();
        bool isCredit = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add Manual Transaction',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Transaction Type toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Credit (Udhaar)'),
                          selected: isCredit,
                          selectedColor: AppTheme.error.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isCredit ? AppTheme.error : AppTheme.grey700,
                            fontWeight: isCredit ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => isCredit = true);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Payment'),
                          selected: !isCredit,
                          selectedColor: AppTheme.success.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: !isCredit ? AppTheme.success : AppTheme.grey700,
                            fontWeight: !isCredit ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => isCredit = false);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // User Selector
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .where('roles', arrayContains: 'UserRole.customer')
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        final users = snapshot.data!.docs
                            .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
                            .toList();

                        if (users.isEmpty) {
                          return const Text('No registered customers found.');
                        }

                        return DropdownButtonFormField<UserModel>(
                          decoration: const InputDecoration(
                            labelText: 'Select Customer',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedUser,
                          items: users.map((u) {
                            return DropdownMenuItem(value: u, child: Text(u.name ?? u.phoneNumber));
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedUser = val;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixText: '₹',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note / Bill Reference',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUser == null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
                      return;
                    }
                    double amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                      return;
                    }

                    final tx = KhataTransaction(
                      id: 'khata_${DateTime.now().millisecondsSinceEpoch}',
                      userId: selectedUser!.id,
                      shopId: 'shop_001',
                      amount: amount,
                      type: isCredit ? KhataTransactionType.credit : KhataTransactionType.payment,
                      timestamp: DateTime.now(),
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : (isCredit ? 'Manual Credit Entry' : 'Manual Payment Entry'),
                    );

                    await _khataService.addKhataTransaction(tx);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Transaction recorded successfully!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showKhataInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'Fufaji Bahi-Khata',
      children: [
        const Text(
          'This digital ledger replaces physical notebooks. '
          'Credit is automatically added when customers choose "Khata" at checkout. '
          'Riders can also collect credit payments during delivery.',
        ),
      ],
    );
  }
}
