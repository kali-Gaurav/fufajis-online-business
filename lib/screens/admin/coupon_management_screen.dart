import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/coupon.dart';

class CouponManagementScreen extends StatefulWidget {
  const CouponManagementScreen({super.key});

  @override
  State<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends State<CouponManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCoupons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.grey50,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCouponDialog(context, adminProvider),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount Coupon Hub', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => adminProvider.fetchCoupons(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: adminProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adminProvider.coupons.isEmpty
                      ? const Center(child: Text('No coupons created yet.'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: adminProvider.coupons.length,
                          itemBuilder: (context, index) {
                            final coupon = adminProvider.coupons[index];
                            return _buildCouponCard(context, coupon, adminProvider);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, Coupon coupon, AdminProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coupon.code,
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => provider.deleteCoupon(coupon.id),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(coupon.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(coupon.description, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  coupon.discountType == 'percentage'
                      ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
                      : '₹${coupon.discountValue.toStringAsFixed(0)} OFF',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text(
                  'Min Order: ₹${coupon.minimumOrderAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCouponDialog(BuildContext context, AdminProvider provider) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final valueController = TextEditingController();
    final minOrderController = TextEditingController();
    final maxDiscountController = TextEditingController();
    String discountType = 'percentage';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Discount Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Promo Code (e.g. SAVE20)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: discountType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (₹)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => discountType = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount Value', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Min Order Amount (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxDiscountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max Discount Limit (₹)', border: OutlineInputBorder()),
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
              onPressed: () {
                if (codeController.text.isNotEmpty && valueController.text.isNotEmpty) {
                  final newCoupon = Coupon(
                    id: '',
                    code: codeController.text.toUpperCase(),
                    name: nameController.text,
                    description: descController.text,
                    discountType: discountType,
                    discountValue: double.tryParse(valueController.text) ?? 0.0,
                    minimumOrderAmount: double.tryParse(minOrderController.text) ?? 0.0,
                    maximumDiscountAmount: double.tryParse(maxDiscountController.text) ?? 0.0,
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  provider.createCoupon(newCoupon);
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
