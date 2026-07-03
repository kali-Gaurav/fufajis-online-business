import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/loyalty_membership_service.dart';
import '../../services/membership_tier_calculator.dart';
import '../../services/reward_system.dart';
import '../../utils/app_theme.dart';

/// Premium membership dashboard showing tier progress, streak tracking,
/// priority slot booking, benefits overview, and rewards balance.
class MembershipDashboardScreen extends StatefulWidget {
  const MembershipDashboardScreen({super.key});

  @override
  State<MembershipDashboardScreen> createState() => _MembershipDashboardScreenState();
}

class _MembershipDashboardScreenState extends State<MembershipDashboardScreen> {
  final LoyaltyMembershipService _loyaltyService = LoyaltyMembershipService();
  final MembershipTierCalculator _tierCalculator = MembershipTierCalculator();

  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _availableSlots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final data = await _loyaltyService.getMembershipDashboard(userId);
      final tier = data['tier'] as MembershipTier? ?? MembershipTier.bronze;
      final slots = await _loyaltyService.getAvailableSlots(date: DateTime.now(), userTier: tier);

      setState(() {
        _dashboardData = data;
        _availableSlots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          title: const Text('My Membership', style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: AppTheme.cream,
          foregroundColor: AppTheme.grey900,
          elevation: 0,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    final tier = _dashboardData['tier'] as MembershipTier? ?? MembershipTier.bronze;
    final tierName = _dashboardData['tierName'] as String? ?? 'Bronze';
    final progress = (_dashboardData['tierProgress'] as double?) ?? 0.0;
    final nextTierInfo = _dashboardData['nextTierInfo'] as Map<String, dynamic>? ?? {};
    final streakData = _dashboardData['streak'] as Map<String, dynamic>? ?? {};
    final points = _dashboardData['rewardPoints'] as int? ?? 0;
    final pointsValue = (_dashboardData['pointsValue'] as double?) ?? 0.0;
    final benefits = _dashboardData['benefits'] as Map<String, dynamic>? ?? {};

    final tierGradients = {
      MembershipTier.bronze: [const Color(0xFFCD7F32), const Color(0xFF8B5E3C)],
      MembershipTier.silver: [const Color(0xFFC0C0C0), const Color(0xFF808080)],
      MembershipTier.gold: [const Color(0xFFFFD700), const Color(0xFFDAA520)],
      MembershipTier.platinum: [const Color(0xFFE5E4E2), const Color(0xFF9E9E9E)],
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          // Membership Card Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tierGradients[tier] ?? tierGradients[MembershipTier.bronze]!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            _buildTierIcon(tier),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$tierName Member',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                ),
                                Text(
                                  'Fufaji Loyalty Program',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Progress to next tier
                        if (tier != MembershipTier.platinum) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tierName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                nextTierInfo['nextTier'] != null
                                    ? _tierCalculator.getTierDisplayName(
                                        nextTierInfo['nextTier'] as MembershipTier,
                                      )
                                    : '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: AppTheme.cream.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextTierInfo['spendingRequired'] != null
                                ? '₹${(nextTierInfo['spendingRequired'] as double).toStringAsFixed(0)} more to reach next tier'
                                : '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'You\'re at the top! Enjoy all benefits.',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildStatCard(
                        icon: Icons.star,
                        value: points.toString(),
                        label: 'Reward Points',
                        subValue: '= ₹${pointsValue.toStringAsFixed(0)}',
                        color: const Color(0xFFFFD700),
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        icon: Icons.local_fire_department,
                        value: '${streakData['currentStreak'] ?? 0}',
                        label: 'Order Streak',
                        subValue:
                            '${((streakData['bonusMultiplier'] as double?) ?? 1.0).toStringAsFixed(1)}x bonus',
                        color: const Color(0xFFFF6B6B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Benefits Section
                  const Text(
                    'Your Benefits',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitTile(
                    Icons.percent,
                    'Cashback',
                    '${benefits['cashbackPercentage'] ?? 0}% on every order',
                    const Color(0xFF4ECDC4),
                  ),
                  _buildBenefitTile(
                    Icons.local_shipping,
                    'Free Delivery',
                    'On orders above ₹${(benefits['freeDeliveryThreshold'] as double? ?? 500).toStringAsFixed(0)}',
                    const Color(0xFF6C63FF),
                  ),
                  _buildBenefitTile(
                    Icons.stars,
                    'Points Multiplier',
                    '${benefits['pointsMultiplier'] ?? 1}x points on every order',
                    const Color(0xFFFFD93D),
                  ),
                  if (_dashboardData['hasEarlyAccess'] == true)
                    _buildBenefitTile(
                      Icons.flash_on,
                      'Early Access',
                      'Get exclusive deals before everyone else',
                      const Color(0xFFFF6B6B),
                    ),

                  const SizedBox(height: 24),

                  // Streak Section
                  _buildStreakSection(streakData),

                  const SizedBox(height: 24),

                  // Priority Slots Section
                  const Text(
                    'Priority Delivery Slots',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Higher tiers get access to reserved slots',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ..._availableSlots.map((slot) => _buildSlotTile(slot, tier)),

                  const SizedBox(height: 24),

                  // Redeem Points Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: points > 0 ? () => _showRedeemDialog(points) : null,
                      icon: const Icon(Icons.redeem, color: Colors.white),
                      label: Text(
                        'Redeem $points Points (₹${pointsValue.toStringAsFixed(0)})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        disabledBackgroundColor: const Color(0xFF2D2B55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierIcon(MembershipTier tier) {
    final icons = {
      MembershipTier.bronze: Icons.shield,
      MembershipTier.silver: Icons.shield,
      MembershipTier.gold: Icons.workspace_premium,
      MembershipTier.platinum: Icons.diamond,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icons[tier], size: 36, color: Colors.white),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required String subValue,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Text(subValue, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 20),
        ],
      ),
    );
  }

  Widget _buildStreakSection(Map<String, dynamic> streakData) {
    final currentStreak = streakData['currentStreak'] as int? ?? 0;
    final longestStreak = streakData['longestStreak'] as int? ?? 0;
    final multiplier = (streakData['bonusMultiplier'] as double?) ?? 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2D2B55), Color(0xFF1A1A2E)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Color(0xFFFF6B6B), size: 24),
              const SizedBox(width: 8),
              const Text(
                'Order Streak',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${multiplier}x',
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStreakStat('Current', currentStreak),
              const SizedBox(width: 24),
              _buildStreakStat('Longest', longestStreak),
            ],
          ),
          const SizedBox(height: 12),
          // Streak visual (flame icons)
          Row(
            children: List.generate(
              7,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.local_fire_department,
                  color: i < currentStreak.clamp(0, 7)
                      ? const Color(0xFFFF6B6B)
                      : Colors.white.withValues(alpha: 0.1),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentStreak >= 5
                ? '🔥 On fire! Keep ordering weekly for bonus points!'
                : currentStreak >= 3
                ? '💪 Great streak! 2 more weeks for 50% bonus!'
                : 'Order weekly to build your streak & earn bonus points!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildSlotTile(Map<String, dynamic> slot, MembershipTier userTier) {
    final isAvailable = slot['isAvailable'] as bool? ?? false;
    final isPriority = slot['isPriority'] as bool? ?? false;
    final fillPct = (slot['fillPercentage'] as double? ?? 0.0);
    final slotLabel = slot['slotLabel'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPriority
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : isAvailable
              ? Colors.transparent
              : const Color(0xFFFF6B6B).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: isAvailable ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B6B),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      slotLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isPriority) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRIORITY',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fillPct,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      fillPct > 0.8
                          ? const Color(0xFFFF6B6B)
                          : fillPct > 0.5
                          ? const Color(0xFFFFD93D)
                          : const Color(0xFF4ECDC4),
                    ),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isAvailable ? 'Available' : 'Full',
            style: TextStyle(
              color: isAvailable ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B6B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showRedeemDialog(int points) {
    final redeemController = TextEditingController(text: points.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Redeem Points', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have $points points (₹${(points * 0.01).toStringAsFixed(0)} value)',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: redeemController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Points to redeem',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                filled: true,
                fillColor: const Color(0xFF0F0F1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null) return;
              Navigator.pop(context);

              final redeemPoints = int.tryParse(redeemController.text) ?? 0;
              if (redeemPoints <= 0 || redeemPoints > points) return;

              final result = await RewardSystem().redeemPoints(
                userId: userId,
                pointsToRedeem: redeemPoints,
              );

              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('₹${result.toStringAsFixed(0)} added to your wallet!'),
                    backgroundColor: const Color(0xFF4ECDC4),
                  ),
                );
                _loadDashboard();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
