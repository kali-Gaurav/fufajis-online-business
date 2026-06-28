import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../providers/product_provider_extensions.dart';
import '../utils/app_theme.dart';

class InventoryHealthScoreWidget extends StatefulWidget {
  const InventoryHealthScoreWidget({super.key});

  @override
  State<InventoryHealthScoreWidget> createState() => _InventoryHealthScoreWidgetState();
}

class _InventoryHealthScoreWidgetState extends State<InventoryHealthScoreWidget> {
  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final health = productProvider.inventoryHealth;

    if (health == null) return const SizedBox.shrink();

    final score = health['score'] as int;
    final status = health['status'] as String;
    
    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppTheme.success;
    } else if (score >= 60) {
      scoreColor = AppTheme.warning;
    } else {
      scoreColor = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inventory Health',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              GestureDetector(
                onTap: () => productProvider.refreshProducts(),
                child: const Icon(Icons.refresh, size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Low', health['lowStockCount'].toString(), AppTheme.warning),
              _buildMiniStat('Out', health['outOfStockCount'].toString(), AppTheme.error),
              _buildMiniStat('Healthy', health['healthyCount'].toString(), AppTheme.success),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/owner/inventory-alerts'),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('View Alerts', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class LowStockAlertWidget extends StatelessWidget {
  const LowStockAlertWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = productProvider.products.where((p) => p.stockQuantity <= (p.minimumStock)).toList();

    if (products.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Low Stock Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${products.length}', style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length > 3 ? 3 : products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: AppTheme.error.withValues(alpha: 0.1), child: const Icon(Icons.warning, color: AppTheme.error, size: 16)),
                title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text('Only ${p.stockQuantity} ${p.unit} left', style: const TextStyle(fontSize: 11)),
                trailing: TextButton(onPressed: () => context.push('/owner/inventory-alerts'), child: const Text('Restock', style: TextStyle(fontSize: 11))),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ExpiringSoonWidget extends StatelessWidget {
  const ExpiringSoonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final now = DateTime.now();
    final expiring = productProvider.products.where((p) {
      if (p.expiryDate == null) return false;
      final diff = p.expiryDate!.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    if (expiring.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expiring Soon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: AppTheme.primary, size: 20),
                onPressed: () => context.push('/owner/expiry-tracking'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...expiring.take(3).map((p) {
            final days = p.expiryDate!.difference(now).inDays;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text('Expires in $days days', style: TextStyle(fontSize: 11, color: days < 3 ? AppTheme.error : AppTheme.warning)),
              trailing: p.isOnSale 
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: const Text('ON SALE', style: TextStyle(fontSize: 9, color: AppTheme.success, fontWeight: FontWeight.bold)))
                : TextButton(onPressed: () => context.push('/owner/pending-price-changes'), child: const Text('Apply Discount', style: TextStyle(fontSize: 11))),
            );
          }),
        ],
      ),
    );
  }
}

class PendingPriceChangesWidget extends StatelessWidget {
  const PendingPriceChangesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<ProductProvider>().getPendingPriceChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final changes = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Price Recommendations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(Icons.trending_up, color: AppTheme.primary, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              ...changes.take(2).map((c) {
                final diff = c['changePercentage'] as int;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['productName'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('₹${c['currentPrice']} → ₹${c['newPrice']}', style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: diff < 0 ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${diff > 0 ? "+" : ""}$diff%',
                      style: TextStyle(fontSize: 10, color: diff < 0 ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/owner/pending-price-changes'), 
                  child: const Text('Review All Changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

