import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group_order_model.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../services/group_buy_service.dart';
import '../utils/app_theme.dart';

class GroupBuyWidget extends StatelessWidget {
  final ProductModel product;
  final GroupBuyService _groupBuyService = GroupBuyService();

  GroupBuyWidget({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.isGroupBuyEligible) return const SizedBox.shrink();

    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || user.district == null || user.village == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<GroupOrderModel>>(
      stream: _groupBuyService.getVillagePools(user.district!, user.village!),
      builder: (context, snapshot) {
        final pools = snapshot.data ?? [];
        final productPools = pools.where((p) => p.shopId == product.shopId).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups, color: AppTheme.warning, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Neighborhood Group Buy',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Buy with neighbors to unlock 20% off!',
                          style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (productPools.isEmpty)
                _buildCreatePool(context, user)
              else
                ...productPools.map((pool) => _buildPoolItem(context, pool, user)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreatePool(BuildContext context, user) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _groupBuyService.createPool(
          userId: user.id,
          shopId: product.shopId,
          district: user.district!,
          village: user.village!,
          initialContribution: product.price.toDouble(),
          goalAmount: (product.price * 5).toDouble(), // Goal of 5 units
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Start a New Pool'),
      ),
    );
  }

  Widget _buildPoolItem(BuildContext context, GroupOrderModel pool, user) {
    final bool isMember = pool.memberIds.contains(user.id);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pool.memberIds.length} neighbors joined',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '₹${pool.goalAmount.round() - pool.totalAmount.round()} more to go',
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pool.progress,
              backgroundColor: AppTheme.grey200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warning),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isMember
                  ? null
                  : () => _groupBuyService.joinPool(pool.id, user.id, product.price.toDouble()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warning,
                side: const BorderSide(color: AppTheme.warning),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isMember ? 'Joined ✅' : 'Join Pool'),
            ),
          ),
        ],
      ),
    );
  }
}
