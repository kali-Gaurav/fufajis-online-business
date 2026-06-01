import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  final UserService _userService = UserService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Digital Khata Ledger'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _buildCustomerList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search customer by name or phone...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppTheme.grey50,
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    // In a real app, this would be a StreamBuilder filtering customers with non-zero creditBalance
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Demo items
      itemBuilder: (context, index) {
        final List<Map<String, dynamic>> demoCustomers = [
          {'name': 'Rajesh Kumar', 'phone': '9876543210', 'balance': 1250.0, 'limit': 5000.0},
          {'name': 'Suresh Singh', 'phone': '9988776655', 'balance': 450.0, 'limit': 2000.0},
          {'name': 'Amit Sharma', 'phone': '9122334455', 'balance': 0.0, 'limit': 5000.0},
        ];
        
        final customer = demoCustomers[index];
        if (_searchQuery.isNotEmpty && 
            !customer['name'].toLowerCase().contains(_searchQuery.toLowerCase()) &&
            !customer['phone'].contains(_searchQuery)) {
          return const SizedBox.shrink();
        }

        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final double balance = customer['balance'];
    final double limit = customer['limit'];
    final double usagePercent = balance / limit;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(customer['name'][0], style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(customer['phone'], style: TextStyle(color: AppTheme.grey500, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: balance > 0 ? AppTheme.error : AppTheme.success,
                    ),
                  ),
                  const Text('Outstanding', style: TextStyle(fontSize: 10, color: AppTheme.grey500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: usagePercent,
            backgroundColor: AppTheme.grey100,
            color: usagePercent > 0.8 ? AppTheme.error : AppTheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Limit: ₹${limit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.grey600)),
              Text('${(usagePercent * 100).toStringAsFixed(0)}% used', style: const TextStyle(fontSize: 11, color: AppTheme.grey600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Send WhatsApp Reminder
                  },
                  icon: const Icon(Icons.message, size: 16),
                  label: const Text('Reminder'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Settle balance
                  },
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Settle'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

