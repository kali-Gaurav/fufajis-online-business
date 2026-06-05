import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Gamified Loyalty Points Card
///
/// Shows:
/// - Current points balance with animated counter
/// - Tier badge (Bronze → Silver → Gold → Platinum)
/// - Points expiry countdown
/// - Progress bar to next tier
/// - "How to earn" quick guide
class LoyaltyPointsCard extends StatefulWidget {
  final int points;
  final String userName;
  final DateTime? pointsExpiry;
  final VoidCallback? onRedeem;

  const LoyaltyPointsCard({
    super.key,
    required this.points,
    required this.userName,
    this.pointsExpiry,
    this.onRedeem,
  });

  @override
  State<LoyaltyPointsCard> createState() => _LoyaltyPointsCardState();
}

class _LoyaltyPointsCardState extends State<LoyaltyPointsCard>
    with TickerProviderStateMixin {
  late final AnimationController _counter;
  late final Animation<int> _counterAnim;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _counter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _counterAnim = IntTween(begin: 0, end: widget.points).animate(
      CurvedAnimation(parent: _counter, curve: Curves.easeOutCubic),
    );
    _counter.forward();

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _counter.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  LoyaltyTier get _tier {
    if (widget.points >= 5000) return LoyaltyTier.platinum;
    if (widget.points >= 2000) return LoyaltyTier.gold;
    if (widget.points >= 500) return LoyaltyTier.silver;
    return LoyaltyTier.bronze;
  }

  LoyaltyTier? get _nextTier {
    switch (_tier) {
      case LoyaltyTier.bronze:
        return LoyaltyTier.silver;
      case LoyaltyTier.silver:
        return LoyaltyTier.gold;
      case LoyaltyTier.gold:
        return LoyaltyTier.platinum;
      case LoyaltyTier.platinum:
        return null;
    }
  }

  int get _pointsToNextTier {
    switch (_tier) {
      case LoyaltyTier.bronze:
        return 500 - widget.points;
      case LoyaltyTier.silver:
        return 2000 - widget.points;
      case LoyaltyTier.gold:
        return 5000 - widget.points;
      case LoyaltyTier.platinum:
        return 0;
    }
  }

  double get _tierProgress {
    switch (_tier) {
      case LoyaltyTier.bronze:
        return widget.points / 500;
      case LoyaltyTier.silver:
        return (widget.points - 500) / 1500;
      case LoyaltyTier.gold:
        return (widget.points - 2000) / 3000;
      case LoyaltyTier.platinum:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _tier.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _tier.gradientColors.last.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: -30,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Text(
                          _tier.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_tier.label} Member',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.userName,
                              style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (widget.onRedeem != null)
                          GestureDetector(
                            onTap: widget.onRedeem,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'Redeem',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Animated points counter
                    AnimatedBuilder(
                      animation: _counterAnim,
                      builder: (_, __) => Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_counterAnim.value}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'FUFAJI COINS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Expiry
                    if (widget.pointsExpiry != null)
                      Text(
                        'Expires ${_formatExpiry(widget.pointsExpiry!)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Progress to next tier
                    if (_nextTier != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_pointsToNextTier pts to ${_nextTier!.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _nextTier!.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _tierProgress.clamp(0.0, 1.0),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                          minHeight: 6,
                        ),
                      ),
                    ] else
                      const Text(
                        '🏆 You\'ve reached the highest tier!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Earn guide chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _EarnChip('🛍️ Shop: +10 pts/₹100'),
                        _EarnChip('⭐ Review: +50 pts'),
                        _EarnChip('👥 Refer: +200 pts'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatExpiry(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.inDays > 30) return 'in ${diff.inDays ~/ 30} months';
    if (diff.inDays > 0) return 'in ${diff.inDays} days';
    return 'soon!';
  }
}

class _EarnChip extends StatelessWidget {
  final String label;
  const _EarnChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Loyalty tiers ────────────────────────────────────────────────────────────
enum LoyaltyTier { bronze, silver, gold, platinum }

extension LoyaltyTierExt on LoyaltyTier {
  String get label => ['Bronze', 'Silver', 'Gold', 'Platinum'][index];
  String get emoji => ['🥉', '🥈', '🥇', '💎'][index];
  List<Color> get gradientColors {
    switch (this) {
      case LoyaltyTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)];
      case LoyaltyTier.silver:
        return [const Color(0xFF9E9E9E), const Color(0xFF616161)];
      case LoyaltyTier.gold:
        return [const Color(0xFFFFD700), const Color(0xFFFF8C00)];
      case LoyaltyTier.platinum:
        return [const Color(0xFF00BCD4), const Color(0xFF0097A7)];
    }
  }
}
