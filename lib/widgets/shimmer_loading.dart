import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Reusable shimmer loading widget using pure Flutter animations.
/// Usage: FjShimmer(child: Container(width: 200, height: 20, color: Colors.white))
class FjShimmer extends StatefulWidget {
  final Widget child;
  const FjShimmer({super.key, required this.child});

  @override
  State<FjShimmer> createState() => _FjShimmerState();
}

class _FjShimmerState extends State<FjShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: const [
              AppTheme.shimmerBase,
              AppTheme.shimmerHighlight,
              AppTheme.shimmerBase,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
          ).createShader(bounds),
          child: widget.child,
        );
      },
    );
  }
}

// ── Pre-built skeleton shapes ────────────────────────────────────────────────

/// Rectangular skeleton block
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return FjShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Circular skeleton (avatar)
class ShimmerCircle extends StatelessWidget {
  final double size;
  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return FjShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppTheme.shimmerBase,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Full-screen skeleton layouts ────────────────────────────────────────────

/// Product grid loading skeleton (2-column)
class ProductGridSkeleton extends StatelessWidget {
  final int count;
  const ProductGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const _ProductCardSkeleton(),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadows,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            width: double.infinity,
            height: 130,
            radius: 0,
          ),
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 12),
                SizedBox(height: 6),
                ShimmerBox(width: 80, height: 10),
                SizedBox(height: 10),
                ShimmerBox(width: 60, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Order list loading skeleton
class OrderListSkeleton extends StatelessWidget {
  final int count;
  const OrderListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _OrderCardSkeleton(),
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadows,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 14),
              ShimmerBox(width: 70, height: 24, radius: 8),
            ],
          ),
          SizedBox(height: 12),
          Divider(height: 1),
          SizedBox(height: 12),
          Row(
            children: [
              ShimmerBox(width: 50, height: 50, radius: 8),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 150, height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(width: 100, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 80, height: 20),
              ShimmerBox(width: 120, height: 36, radius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transaction list skeleton
class TransactionListSkeleton extends StatelessWidget {
  final int count;
  const TransactionListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadows,
          ),
          child: const Row(
            children: [
              ShimmerCircle(size: 42),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 160, height: 12),
                    SizedBox(height: 6),
                    ShimmerBox(width: 100, height: 10),
                  ],
                ),
              ),
              ShimmerBox(width: 60, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic list tile skeleton
class ListTileSkeleton extends StatelessWidget {
  final bool hasSubtitle;
  const ListTileSkeleton({super.key, this.hasSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const ShimmerCircle(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 180, height: 13),
                if (hasSubtitle) ...[
                  const SizedBox(height: 6),
                  const ShimmerBox(width: 120, height: 11),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
