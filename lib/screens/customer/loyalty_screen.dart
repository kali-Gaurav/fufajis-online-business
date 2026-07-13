import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rewards & Loyalty')),
        body: const Center(child: Text('Please log in to view rewards')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards & Loyalty', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTierHeader(user),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildPointsCard(context, user),
                  const SizedBox(height: 16),
                  _buildTierBenefits(user.membershipTier),
                  const SizedBox(height: 16),
                  _buildReferralCard(context, user),
                  const SizedBox(height: 16),
                  _buildPointsHistory(user.uid),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierHeader(UserModel user) {
    final tierData = _getTierData(user.membershipTier);
    final nextTierData = _getNextTierData(user.membershipTier);
    final progress = _getTierProgress(user.rewardPoints, user.membershipTier);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierData['color'] as Color, (tierData['color'] as Color).withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(tierData['icon'] as IconData, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierData['name'] as String,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${user.rewardPoints} points',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextTierData != null) ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress to ${nextTierData['name']}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_getPointsToNextTier(user.rewardPoints, user.membershipTier)} more points to ${nextTierData['name']}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Points',
                      style: TextStyle(fontSize: 14, color: AppTheme.grey600),
                    ),
                    SizedBox(height: 4),
                    Text('Points value', style: TextStyle(fontSize: 12, color: AppTheme.grey400)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user.rewardPoints}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  Text(
                    '= ₹${(user.rewardPoints / 10).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.grey600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.grey400),
              SizedBox(width: 6),
              Text(
                '₹1 = 10 points · Min 100 points to redeem',
                style: TextStyle(fontSize: 12, color: AppTheme.grey500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: user.rewardPoints >= 100 ? () => _showRedeemDialog(context, user) : null,
              icon: const Icon(Icons.redeem),
              label: Text(
                user.rewardPoints >= 100
                    ? 'Redeem Points'
                    : 'Need ${100 - user.rewardPoints} more points to redeem',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.grey200,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBenefits(MembershipTier tier) {
    final benefits = _getTierBenefits(tier);
    final tierData = _getTierData(tier);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tierData['icon'] as IconData, color: tierData['color'] as Color),
              const SizedBox(width: 8),
              Text(
                '${tierData['name']} Benefits',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.grey900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: AppTheme.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(fontSize: 14, color: AppTheme.grey700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _buildAllTiersBadges(),
        ],
      ),
    );
  }

  Widget _buildAllTiersBadges() {
    final tiers = [
      MembershipTier.bronze,
      MembershipTier.silver,
      MembershipTier.gold,
      MembershipTier.platinum,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: tiers.map((t) {
        final data = _getTierData(t);
        return Column(
          children: [
            Icon(data['icon'] as IconData, color: data['color'] as Color, size: 28),
            const SizedBox(height: 4),
            Text(
              data['name'] as String,
              style: const TextStyle(fontSize: 10, color: AppTheme.grey600),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildReferralCard(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share & Earn ₹50',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'Invite friends to Fufaji\'s. You both get ₹50 on their first order!',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _shareReferral(context, user),
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Invite'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cream,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHistory(String uid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('pointsHistory')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No points activity yet.\nStart shopping to earn points!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.grey500),
                    ),
                  ),
                );
              }

              return Column(
                children: snap.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final points = (data['points'] as num?)?.toInt() ?? 0;
                  final isEarned = points > 0;
                  final description = data['description'] as String? ?? 'Transaction';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final dateStr = createdAt != null ? _formatDate(createdAt.toDate()) : '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isEarned ? AppTheme.success : AppTheme.error).withOpacity(0.1,),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEarned ? Icons.add : Icons.remove,
                            color: isEarned ? AppTheme.success : AppTheme.error,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                description,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              if (dateStr.isNotEmpty)
                                Text(
                                  dateStr,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.grey500),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${isEarned ? '+' : ''}$points pts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isEarned ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context, UserModel user) {
    final maxRedeemable = (user.rewardPoints / 10).floor();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem Points', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have ${user.rewardPoints} points = ₹$maxRedeemable'),
            const SizedBox(height: 8),
            const Text('Enter amount to redeem (₹):', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Max ₹$maxRedeemable',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '₹1 = 10 points. Will be applied as wallet credit.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey500),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(controller.text) ?? 0;
              if (amount > 0 && amount <= maxRedeemable) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('₹$amount redeemed as wallet credit!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  void _shareReferral(BuildContext context, UserModel user) {
    SharePlus.instance.share(ShareParams(
      text: 'Shop at Fufaji\'s Online — Baran\'s fastest grocery delivery! '
          'Use my referral and get ₹50 off your first order. '
          'Download the app and enter code: ${user.uid.substring(0, 8).toUpperCase()}',
      subject: 'Get ₹50 off at Fufaji\'s Online!',
    ));
  }

  Map<String, dynamic> _getTierData(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return {
          'name': 'Bronze',
          'color': const Color(0xFFCD7F32),
          'icon': Icons.workspace_premium,
        };
      case MembershipTier.silver:
        return {'name': 'Silver', 'color': const Color(0xFF9E9E9E), 'icon': Icons.military_tech};
      case MembershipTier.gold:
        return {'name': 'Gold', 'color': const Color(0xFFFFD700), 'icon': Icons.emoji_events};
      case MembershipTier.platinum:
        return {'name': 'Platinum', 'color': const Color(0xFF4FC3F7), 'icon': Icons.diamond};
    }
  }

  Map<String, dynamic>? _getNextTierData(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return _getTierData(MembershipTier.silver);
      case MembershipTier.silver:
        return _getTierData(MembershipTier.gold);
      case MembershipTier.gold:
        return _getTierData(MembershipTier.platinum);
      case MembershipTier.platinum:
        return null;
    }
  }

  double _getTierProgress(int points, MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return (points / 500).clamp(0.0, 1.0);
      case MembershipTier.silver:
        return ((points - 500) / 1500).clamp(0.0, 1.0);
      case MembershipTier.gold:
        return ((points - 2000) / 3000).clamp(0.0, 1.0);
      case MembershipTier.platinum:
        return 1.0;
    }
  }

  int _getPointsToNextTier(int points, MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return (500 - points).clamp(0, 500);
      case MembershipTier.silver:
        return (2000 - points).clamp(0, 2000);
      case MembershipTier.gold:
        return (5000 - points).clamp(0, 5000);
      case MembershipTier.platinum:
        return 0;
    }
  }

  List<String> _getTierBenefits(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.bronze:
        return [
          'Earn 1 point per ₹10 spent',
          'Birthday bonus 2x points',
          'Access to member-only deals',
        ];
      case MembershipTier.silver:
        return [
          'Earn 1.5 points per ₹10 spent',
          'Free delivery on orders above ₹299',
          'Priority customer support',
          'Birthday bonus 3x points',
          'Early access to flash sales',
        ];
      case MembershipTier.gold:
        return [
          'Earn 2 points per ₹10 spent',
          'Free delivery on all orders',
          'Dedicated support line',
          'Birthday bonus 5x points',
          'Exclusive Gold member deals',
          'First access to new products',
        ];
      case MembershipTier.platinum:
        return [
          'Earn 3 points per ₹10 spent',
          'Free delivery always',
          'Personal shopping assistant',
          'Birthday bonus 10x points',
          'Platinum-only pricing',
          'Complimentary gift wrapping',
          'Priority dispatch',
        ];
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
