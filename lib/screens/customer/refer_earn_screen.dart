import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/referral_service.dart';
import '../../utils/app_theme.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  final ReferralService _service = ReferralService();

  String? _code;
  bool _loading = true;
  List<ReferredFriend> _friends = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final code = await _service.ensureReferralCode(user);
    final friends = await _service.getReferredFriends(user.id);
    if (!mounted) return;
    setState(() {
      _code = code;
      _friends = friends;
      _loading = false;
    });
  }

  String get inviteText =>
      'Shop at Fufaji\'s Online — Baran\'s fastest grocery delivery! 🛒\n'
      'Use my code *${_code ?? ''}* at signup and get ₹50 off your first order. '
      'I get ₹50 too. 🎉\n'
      'Download the app and start saving!';

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied!'), duration: Duration(seconds: 2)),
    );
  }

  void _share() {
    if (_code == null) return;
    SharePlus.instance.share(ShareParams(
      text: inviteText,
      subject: 'Fufaji\'s Online Referral',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.grey50,
      appBar: AppBar(
        title: const Text('Refer & Earn', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : AppTheme.cream,
        foregroundColor: isDark ? Colors.white : AppTheme.grey900,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildHero(),
                  const SizedBox(height: 20),
                  _buildCodeCard(),
                  const SizedBox(height: 20),
                  _buildStats(user),
                  const SizedBox(height: 24),
                  _buildHowItWorks(),
                  const SizedBox(height: 24),
                  _buildFriendsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            'Invite friends, earn ₹50 each',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'You both get ₹50 in your wallet when they complete their first order.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral code',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.grey600),
          ),
          const SizedBox(height: 10),
          DottedCodeBox(code: _code ?? '——', onCopy: _copyCode),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(UserModel? user) {
    final invited = user?.referralCount ?? _friends.where((f) => f.completed).length;
    final earned = user?.referralEarnings ?? 0.0;
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.group_rounded,
            label: 'Friends joined',
            value: '$invited',
            color: AppTheme.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Earned',
            value: '₹${earned.toStringAsFixed(0)}',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.grey600)),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    final steps = [
      (
        '1',
        Icons.share_rounded,
        'Share your code',
        'Send your code to friends and family on WhatsApp.',
      ),
      (
        '2',
        Icons.person_add_alt_1_rounded,
        'They sign up',
        'Your friend enters your code while creating their account.',
      ),
      (
        '3',
        Icons.celebration_rounded,
        'You both earn ₹50',
        'When they complete their first order, ₹50 lands in each wallet.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 14),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.$2, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$3,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.grey900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.$4,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Friends you invited',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.grey900),
          ),
          const SizedBox(height: 12),
          if (_friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.group_add_rounded, size: 40, color: AppTheme.grey400),
                    SizedBox(height: 8),
                    Text(
                      'No invites yet',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Share your code to start earning.',
                      style: TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._friends.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withOpacity(0.12),
                      child: Text(
                        f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (f.completed ? AppTheme.info : AppTheme.warning).withOpacity(0.12,),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f.completed ? '₹50 earned' : 'Pending',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: f.completed ? AppTheme.secondaryDark : AppTheme.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DottedCodeBox extends StatelessWidget {
  const DottedCodeBox({super.key, required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onCopy,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.primary.withOpacity(0.15) : AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: AppTheme.primary,
              ),
            ),
            const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
