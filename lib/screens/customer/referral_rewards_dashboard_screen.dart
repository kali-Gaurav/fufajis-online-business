import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/app_theme.dart';

class ReferralRewardsDashboardScreen extends StatefulWidget {
  const ReferralRewardsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReferralRewardsDashboardScreen> createState() =>
      _ReferralRewardsDashboardScreenState();
}

class _ReferralRewardsDashboardScreenState
    extends State<ReferralRewardsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _referralCode = 'FUFAJI2024ABC';
  int _referralCount = 12;
  double _rewardsBalance = 850.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareReferralCode() {
    Share.share(
      'Join me on Fufaji\'s Online and get ₹100 instant discount! Use my code: $_referralCode\n\nDownload now and enjoy daily essentials delivered to your door.',
      subject: 'Special offer from Fufaji\'s Online',
    );
  }

  void _copyReferralCode() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        title: const Text(
          'Rewards & Referrals',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.cream,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.grey600,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Referrals'),
            Tab(text: 'Rewards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildReferralsTab(),
          _buildRewardsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rewards Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rewards Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_rewardsBalance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Available to use on your next order',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                    ),
                    child: const Text('Redeem Rewards'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Referrals',
                  value: _referralCount.toString(),
                  icon: Icons.people,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'Total Earned',
                  value: '₹${_referralCount * 100}',
                  icon: Icons.trending_up,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tier Status
          _buildTierCard(),
          const SizedBox(height: 24),

          // How It Works
          _buildHowItWorksSection(),
        ],
      ),
    );
  }

  Widget _buildReferralsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Referral Code Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Referral Code',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _referralCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      GestureDetector(
                        onTap: _copyReferralCode,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.copy,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareReferralCode,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Referral Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Referral History
          const Text(
            'Recent Referrals',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildReferralHistory(),
        ],
      ),
    );
  }

  Widget _buildRewardsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reward Tiers
          const Text(
            'Reward Tiers',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildRewardTier(
            tier: 'Bronze',
            referrals: '0-5',
            rewardPerReferral: '₹100',
            isActive: _referralCount < 5,
            progress: _referralCount / 5,
          ),
          const SizedBox(height: 12),
          _buildRewardTier(
            tier: 'Silver',
            referrals: '6-15',
            rewardPerReferral: '₹150',
            isActive: _referralCount >= 6 && _referralCount < 15,
            progress: (_referralCount - 6) / 10,
          ),
          const SizedBox(height: 12),
          _buildRewardTier(
            tier: 'Gold',
            referrals: '16+',
            rewardPerReferral: '₹200',
            isActive: _referralCount >= 16,
            progress: 1.0,
          ),
          const SizedBox(height: 24),

          // Redemption Options
          const Text(
            'Redeem Your Rewards',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _buildRedemptionOption(
            title: 'Use on Orders',
            description: 'Use your balance directly on any purchase',
            icon: Icons.shopping_cart,
          ),
          const SizedBox(height: 12),
          _buildRedemptionOption(
            title: 'Wallet Credit',
            description: 'Transfer to your wallet for later use',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 12),
          _buildRedemptionOption(
            title: 'Gift Card',
            description: 'Convert to a gift card to share',
            icon: Icons.card_giftcard,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard() {
    final currentTier = _referralCount < 6 ? 'Bronze' : (_referralCount < 16 ? 'Silver' : 'Gold');
    final tierColor = currentTier == 'Gold'
        ? Colors.amber
        : (currentTier == 'Silver' ? Colors.grey : Colors.brown);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star,
              size: 32,
              color: tierColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Tier: $currentTier',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: tierColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentTier == 'Gold'
                      ? 'Keep enjoying premium rewards!'
                      : 'Refer more friends to unlock higher tier benefits',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How It Works',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        _buildHowItWorksStep(
          number: '1',
          title: 'Share Your Code',
          description: 'Share your unique referral code with friends',
        ),
        const SizedBox(height: 12),
        _buildHowItWorksStep(
          number: '2',
          title: 'They Sign Up',
          description: 'Your friend signs up using your code',
        ),
        const SizedBox(height: 12),
        _buildHowItWorksStep(
          number: '3',
          title: 'You Get Rewards',
          description: 'Earn rewards when they place their first order',
        ),
      ],
    );
  }

  Widget _buildHowItWorksStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grey600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildReferralHistory() {
    final referrals = [
      {'name': 'Rajesh Kumar', 'date': '2 days ago', 'reward': '₹100'},
      {'name': 'Priya Singh', 'date': '5 days ago', 'reward': '₹100'},
      {'name': 'Amit Patel', 'date': '1 week ago', 'reward': '₹100'},
      {'name': 'Neha Sharma', 'date': '2 weeks ago', 'reward': '₹150'},
    ];

    return referrals
        .map(
          (ref) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ref['name']![0],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          ref['date']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${ref['reward']!}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buildRewardTier({
    required String tier,
    required String referrals,
    required String rewardPerReferral,
    required bool isActive,
    required double progress,
  }) {
    return Card(
      color: isActive ? AppTheme.primary.withOpacity(0.05) : AppTheme.white,
      border: isActive
          ? Border.all(color: AppTheme.primary)
          : Border.all(color: AppTheme.grey200),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tier,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? AppTheme.primary : AppTheme.grey600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : AppTheme.grey200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'LOCKED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : AppTheme.grey600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Referrals: $referrals',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reward: $rewardPerReferral per referral',
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppTheme.grey200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isActive ? AppTheme.primary : AppTheme.grey400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionOption({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.grey400),
          ],
        ),
      ),
    );
  }
}
