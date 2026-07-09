import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../utils/app_theme.dart';

/// Staggered Fade + Slide entrance animation for lists and details
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = AppTheme.durationMedium,
    this.delay = Duration.zero,
    this.offset = const Offset(0.0, 0.25),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacityAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _offsetAnim = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: AppTheme.curveEntrance));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: FractionalTranslation(translation: _offsetAnim.value, child: widget.child),
        );
      },
    );
  }
}

/// Tap-to-bounce scale wrapper for interactive components (buttons, chips, cards)
class ScaleBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const ScaleBounce({super.key, required this.child, this.onTap, this.scaleFactor = 0.95});

  @override
  State<ScaleBounce> createState() => _ScaleBounceState();
}

class _ScaleBounceState extends State<ScaleBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

/// Shimmer Loading Placeholder
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _alignAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();

    _alignAnim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [AppTheme.shimmerBase, AppTheme.shimmerHighlight, AppTheme.shimmerBase],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(_alignAnim.value - 1, -0.3),
              end: Alignment(_alignAnim.value + 1, 0.3),
            ),
          ),
        );
      },
    );
  }
}

/// Animated Counter for smooth number changes (KPIs, Cart quantities)
class AnimatedCounter extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppTheme.durationMedium,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutQuad,
      builder: (context, animValue, child) {
        final formatted = animValue % 1 == 0
            ? animValue.toInt().toString()
            : animValue.toStringAsFixed(1);
        return Text('$prefix$formatted$suffix', style: style);
      },
    );
  }
}

/// Glassmorphic frosted card container
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color tint;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blur = 15.0,
    this.tint = const Color(0x0DFFFFFF),
    this.borderColor = const Color(0x1BFFFFFF),
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pulsing glow ring animation for badges, indicators, and focus points
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxRadius;
  final Duration duration;

  const PulseGlow({
    super.key,
    required this.child,
    this.glowColor = AppTheme.primary,
    this.maxRadius = 8.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: widget.maxRadius,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: (1.0 - _controller.value) * 0.4),
                blurRadius: _glowAnim.value * 2,
                spreadRadius: _glowAnim.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Typewriter text typing animation for splash screen and hero text
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 60),
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _charCount;
  bool _cursorVisible = true;

  @override
  void initState() {
    super.initState();
    _charCount = 0;
    _controller = AnimationController(vsync: this, duration: widget.speed * widget.text.length);

    _controller.addListener(() {
      final newCount = (_controller.value * widget.text.length).round();
      if (newCount != _charCount) {
        setState(() {
          _charCount = newCount;
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (widget.onComplete != null) widget.onComplete!();
      }
    });

    _controller.forward();

    // Toggle cursor visibility
    _blinkCursor();
  }

  void _blinkCursor() async {
    while (mounted && _controller.value < 1.0) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _cursorVisible = !_cursorVisible;
        });
      }
    }
    if (mounted) {
      setState(() {
        _cursorVisible = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayedText = widget.text.substring(0, _charCount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(displayedText, style: widget.style),
        Opacity(
          opacity: _cursorVisible ? 1.0 : 0.0,
          child: Text(
            '|',
            style: widget.style?.copyWith(
              color: widget.style?.color ?? AppTheme.primary,
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      ],
    );
  }
}

/// A Staggered entrance anim LIST (scrollable) — for horizontal/vertical scroll lists
class StaggeredScrollList extends StatelessWidget {
  final List<Widget> children;
  final Duration delayStep;
  final Duration itemDuration;
  final Axis scrollDirection;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const StaggeredScrollList({
    super.key,
    required this.children,
    this.delayStep = const Duration(milliseconds: 80),
    this.itemDuration = AppTheme.durationMedium,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      scrollDirection: scrollDirection,
      padding: padding,
      itemCount: children.length,
      itemBuilder: (context, index) {
        return FadeSlideIn(
          duration: itemDuration,
          delay: delayStep * index,
          offset: scrollDirection == Axis.vertical
              ? const Offset(0.0, 0.15)
              : const Offset(0.15, 0.0),
          child: children[index],
        );
      },
    );
  }
}

/// Safe Lottie Asset widget with custom error handling & fallback
class SafeLottieAsset extends StatelessWidget {
  final String assetPath;
  final AnimationController? controller;
  final bool repeat;
  final BoxFit fit;
  final Widget Function(BuildContext context)? fallbackBuilder;

  const SafeLottieAsset({
    super.key,
    required this.assetPath,
    this.controller,
    this.repeat = true,
    this.fit = BoxFit.contain,
    this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      controller: controller,
      repeat: repeat,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('SafeLottieAsset: Failed to load $assetPath. Using fallback.');
        return fallbackBuilder != null ? fallbackBuilder!(context) : const SizedBox.shrink();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  NEW PREMIUM ANIMATION WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Public bouncing-dots loader — 3 dots that bounce in a wave sequence.
/// Use on any loading state where a full spinner feels too heavy.
class BouncingDotsLoader extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double bounceHeight;

  const BouncingDotsLoader({
    super.key,
    this.color = AppTheme.primary,
    this.dotSize = 9,
    this.bounceHeight = 10,
  });

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value + 1.0 - i / 3.0) % 1.0;
          final bounce = math.sin(phase * math.pi).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: widget.dotSize,
            height: widget.dotSize,
            transform: Matrix4.translationValues(0, -widget.bounceHeight * bounce, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.60 + 0.40 * bounce),
            ),
          );
        }),
      ),
    );
  }
}

/// Animated gradient text — text rendered with a sweeping gradient shimmer.
/// Great for hero headings, prices, and KPI labels.
class AnimatedGradientText extends StatefulWidget {
  final String text;
  final TextStyle? baseStyle;
  final List<Color> gradientColors;
  final Duration duration;

  const AnimatedGradientText({
    super.key,
    required this.text,
    this.baseStyle,
    this.gradientColors = const [Color(0xFFFF6B00), Color(0xFFFFB347), Color(0xFFFF6B00)],
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shiftAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
    _shiftAnim = Tween<double>(
      begin: -1.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment(_shiftAnim.value - 1, 0),
          end: Alignment(_shiftAnim.value + 1, 0),
        ).createShader(bounds),
        child: Text(
          widget.text,
          style: (widget.baseStyle ?? const TextStyle()).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Slide-up-and-fade entrance. Cleaner than FadeSlideIn for vertical lists.
class SlideUpFade extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideDistance;

  const SlideUpFade({
    super.key,
    required this.child,
    this.duration = AppTheme.durationMedium,
    this.delay = Duration.zero,
    this.slideDistance = 24.0,
  });

  @override
  State<SlideUpFade> createState() => _SlideUpFadeState();
}

class _SlideUpFadeState extends State<SlideUpFade> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _offset = Tween<double>(
      begin: widget.slideDistance,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: Offset(0, _offset.value), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Ripple tap effect — shows a ripple emanating from tap point.
/// Wrap any interactive element for premium touch feedback.
class RippleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;
  final BorderRadius? borderRadius;

  const RippleTap({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor = AppTheme.primaryLight,
    this.borderRadius,
  });

  @override
  State<RippleTap> createState() => _RippleTapState();
}

class _RippleTapState extends State<RippleTap> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (d) {
        _tapPos = d.localPosition;
        _ctrl.forward(from: 0);
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(
          foregroundPainter: _RipplePainter(
            position: _tapPos,
            progress: _ctrl.value,
            color: widget.rippleColor,
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset position;
  final double progress;
  final Color color;

  const _RipplePainter({required this.position, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final maxR = size.longestSide * 1.2;
    canvas.drawCircle(
      position,
      maxR * progress,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * 0.22)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.position != position;
}

/// Floating action bubble that pulses with a glow — great for CTAs.
class GlowFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String? label;

  const GlowFAB({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.primary,
    this.label,
  });

  @override
  State<GlowFAB> createState() => _GlowFABState();
}

class _GlowFABState extends State<GlowFAB> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleBounce(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            shape: widget.label == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.label != null ? BorderRadius.circular(30) : null,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _glow.value * 0.50),
                blurRadius: 20 * _glow.value,
                spreadRadius: 3 * _glow.value,
              ),
            ],
          ),
          child: child,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.label != null ? 20 : 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.15) ?? widget.color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: widget.label == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.label != null ? BorderRadius.circular(30) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 24),
              if (widget.label != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated number counter that smoothly transitions between values.
/// Drop-in replacement for Text when displaying changing numbers.
class CountUpText extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle? style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _anim = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad));
      _ctrl.forward(from: 0);
    }
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
      builder: (_, __) {
        final v = _anim.value;
        final formatted = widget.decimals == 0
            ? v.round().toString()
            : v.toStringAsFixed(widget.decimals);
        return Text('${widget.prefix}$formatted${widget.suffix}', style: widget.style);
      },
    );
  }
}

/// Animated check-mark success state — expands from center with a spring.
class AnimatedSuccessMark extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onComplete;

  const AnimatedSuccessMark({
    super.key,
    this.size = 80,
    this.color = AppTheme.success,
    this.onComplete,
  });

  @override
  State<AnimatedSuccessMark> createState() => _AnimatedSuccessMarkState();
}

class _AnimatedSuccessMarkState extends State<AnimatedSuccessMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.15),
            border: Border.all(color: widget.color, width: 2.5),
          ),
          child: CustomPaint(
            painter: _CheckPainter(progress: _checkProgress.value, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final p1 = Offset(cx - size.width * 0.22, cy);
    final p2 = Offset(cx - size.width * 0.04, cy + size.height * 0.18);
    final p3 = Offset(cx + size.width * 0.25, cy - size.height * 0.14);

    if (progress < 0.5) {
      final t = progress / 0.5;
      canvas.drawLine(p1, Offset.lerp(p1, p2, t)!, p);
    } else {
      canvas.drawLine(p1, p2, p);
      final t = (progress - 0.5) / 0.5;
      canvas.drawLine(p2, Offset.lerp(p2, p3, t)!, p);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

// ============================================================================
//  FUFAJI ANIMATION SYSTEM v2 — Added June 2026
//  Widgets: FufajiShimmerCard, FufajiSkeleton, SparkleOverlay, FloatingSparkles,
//           FufajiConfetti, StaggeredList, FufajiGlowButton, BounceIn,
//           PulsingDot, ScaleInFade, AnimatedTabIndicator, CartBounce,
//           GlowContainer, WaveDivider, FufajiLoadingDots
// ============================================================================

// ── Shimmer skeleton — branded orange-tinted loading placeholder ─────────────
class FufajiSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const FufajiSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerWidget(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Branded shimmer wrapper — wraps any widget in an orange shimmer effect
class _ShimmerWidget extends StatefulWidget {
  final Widget child;
  const _ShimmerWidget({required this.child});

  @override
  State<_ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<_ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _anim = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFFFF3E8),
              Color(0xFFFFE0C0),
              Color(0xFFFFF3E8),
              Color(0xFFE8E8E8),
            ],
            stops: [
              0.0,
              (_anim.value - 0.3).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.3).clamp(0.0, 1.0),
              1.0,
            ],
          ).createShader(bounds),
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// Full product-card skeleton for loading states
class FufajiShimmerCard extends StatelessWidget {
  final bool isCompact;
  const FufajiShimmerCard({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWidget(
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: isCompact ? 90 : 130,
              decoration: const BoxDecoration(
                color: Color(0xFFE8E8E8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 28,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer grid of skeleton cards for the product grid loading state
class FufajiShimmerGrid extends StatelessWidget {
  final int count;
  final int crossAxisCount;
  final bool compact;

  const FufajiShimmerGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: compact ? 0.75 : 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: count,
      itemBuilder: (_, i) => FufajiShimmerCard(isCompact: compact),
    );
  }
}

// ── Sparkle overlay — same sparkle art as splash screen ─────────────────────

class _SparklePainterV2 extends CustomPainter {
  final double opacity;
  final double size;
  final Color color;

  const _SparklePainterV2({required this.opacity, this.size = 8, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size s) {
    if (opacity <= 0) return;
    final cx = s.width / 2;
    final cy = s.height / 2;
    final stroke = Paint()
      ..color = color.withValues(alpha: opacity * 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * size, cy + math.sin(a) * size),
        stroke,
      );
    }
    canvas.drawCircle(
      Offset(cx, cy),
      size * 0.28,
      Paint()..color = color.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklePainterV2 old) => old.opacity != opacity;
}

/// A single animated sparkle. Fades in/out on a loop with the given phase offset.
class AnimatedSparkle extends StatefulWidget {
  final double size;
  final Color color;
  final double phaseOffset;

  const AnimatedSparkle({
    super.key,
    this.size = 8,
    this.color = Colors.white,
    this.phaseOffset = 0.0,
  });

  @override
  State<AnimatedSparkle> createState() => _AnimatedSparkleState();
}

class _AnimatedSparkleState extends State<AnimatedSparkle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final phase = (_ctrl.value + widget.phaseOffset) % 1.0;
        final opacity = (math.sin(phase * math.pi * 2) * 0.5 + 0.5).clamp(0.0, 1.0);
        return CustomPaint(
          size: Size(widget.size * 2, widget.size * 2),
          painter: _SparklePainterV2(opacity: opacity, size: widget.size, color: widget.color),
        );
      },
    );
  }
}

/// Drop several sparkles onto any widget using a Stack + Positioned
class SparkleOverlay extends StatelessWidget {
  final Widget child;
  final int count;
  final Color sparkleColor;

  const SparkleOverlay({
    super.key,
    required this.child,
    this.count = 5,
    this.sparkleColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final positions = [
      const Offset(0.10, 0.12),
      const Offset(0.88, 0.10),
      const Offset(0.50, 0.05),
      const Offset(0.06, 0.55),
      const Offset(0.92, 0.52),
      const Offset(0.75, 0.85),
      const Offset(0.22, 0.80),
    ];
    return RepaintBoundary(
      child: Stack(
        children: [
          child,
          ...List.generate(count.clamp(0, positions.length), (i) {
            return Positioned(
              left: positions[i].dx * 300,
              top: positions[i].dy * 200,
              child: AnimatedSparkle(
                size: 7 + (i % 3) * 2.0,
                color: sparkleColor,
                phaseOffset: i / count,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── BounceIn — elastic entrance from any direction ────────────────────────────

class BounceIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double beginScale;
  final Offset? beginOffset;

  const BounceIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.beginScale = 0.0,
    this.beginOffset,
  });

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  Animation<Offset>? _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    if (widget.beginOffset != null) {
      _offset = Tween<Offset>(
        begin: widget.beginOffset!,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    }
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        Widget w = Transform.scale(scale: _scale.value, child: child);
        if (_offset != null) {
          w = FractionalTranslation(translation: _offset!.value, child: w);
        }
        return Opacity(opacity: _opacity.value, child: w);
      },
      child: widget.child,
    );
  }
}

// ── ScaleInFade — zoom-in from centre, fades in ───────────────────────────────

class ScaleInFade extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double beginScale;

  const ScaleInFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.beginScale = 0.85,
  });

  @override
  State<ScaleInFade> createState() => _ScaleInFadeState();
}

class _ScaleInFadeState extends State<ScaleInFade> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ── StaggeredList — staggered entrance for any list of children ───────────────

class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final Offset slideOffset;

  const StaggeredList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = AppTheme.durationMedium,
    this.slideOffset = const Offset(0.0, 0.18),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (i) {
        return FadeSlideIn(
          delay: itemDelay * i,
          duration: itemDuration,
          offset: slideOffset,
          child: children[i],
        );
      }),
    );
  }
}

// ── PulsingDot — live indicator dot ──────────────────────────────────────────

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, this.color = AppTheme.primary, this.size = 10});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _pulse.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _pulse.value * 0.5),
              blurRadius: widget.size * _pulse.value,
              spreadRadius: widget.size * 0.2 * _pulse.value,
            ),
          ],
        ),
      ),
    );
  }
}

// ── GlowContainer — pulsing glow border for highlighted cards ─────────────────

class GlowContainer extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double borderRadius;
  final double maxGlowRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppTheme.primary,
    this.borderRadius = 16,
    this.maxGlowRadius = 16,
  });

  @override
  State<GlowContainer> createState() => _GlowContainerState();
}

class _GlowContainerState extends State<GlowContainer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: _glow.value * 0.45),
              blurRadius: widget.maxGlowRadius * _glow.value,
              spreadRadius: 2 * _glow.value,
            ),
          ],
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: widget.child,
      ),
    );
  }
}

// ── FufajiGlowButton — pulsing CTA button ────────────────────────────────────

class FufajiGlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? color;
  final IconData? icon;
  final double height;

  const FufajiGlowButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.color,
    this.icon,
    this.height = 52,
  });

  @override
  State<FufajiGlowButton> createState() => _FufajiGlowButtonState();
}

class _FufajiGlowButtonState extends State<FufajiGlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.color ?? AppTheme.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: col.withValues(alpha: _glow.value * 0.6),
                blurRadius: 18 * _glow.value,
                spreadRadius: 2 * _glow.value,
              ),
            ],
          ),
          child: Material(
            color: col,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.isLoading ? null : widget.onTap,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── FufajiConfetti — canvas-drawn confetti celebration ────────────────────────

class _ConfettiParticle {
  Offset position;
  Offset velocity;
  Color color;
  double rotation;
  double rotationSpeed;
  double size;
  double opacity;

  _ConfettiParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    this.opacity = 1.0,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  const _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

class FufajiConfetti extends StatefulWidget {
  final bool play;
  final Widget child;

  const FufajiConfetti({super.key, required this.child, this.play = true});

  @override
  State<FufajiConfetti> createState() => _FufajiConfettiState();
}

class _FufajiConfettiState extends State<FufajiConfetti> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];
  final _rng = math.Random();

  static const _colors = [
    Color(0xFFFF6B00),
    Color(0xFFFFB347),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFFFFEB3B),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tick);
    if (widget.play) _launch();
  }

  @override
  void didUpdateWidget(FufajiConfetti old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _launch();
  }

  void _launch() {
    _particles.clear();
    for (int i = 0; i < 80; i++) {
      _particles.add(
        _ConfettiParticle(
          position: Offset(100 + _rng.nextDouble() * 200, -20 - _rng.nextDouble() * 40),
          velocity: Offset((_rng.nextDouble() - 0.5) * 6, 3 + _rng.nextDouble() * 5),
          color: _colors[_rng.nextInt(_colors.length)],
          rotation: _rng.nextDouble() * math.pi * 2,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 0.18,
          size: 8 + _rng.nextDouble() * 8,
          opacity: 1.0,
        ),
      );
    }
    _ctrl.repeat();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _ctrl.stop();
    });
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.position += p.velocity;
        p.velocity = Offset(p.velocity.dx * 0.99, p.velocity.dy + 0.12);
        p.rotation += p.rotationSpeed;
        if (p.position.dy > 700) p.opacity = (p.opacity - 0.04).clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          widget.child,
          if (widget.play)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_particles))),
            ),
        ],
      ),
    );
  }
}

// ── FufajiLoadingDots — 3 bouncing dots (reusable, not locked to splash) ─────

class FufajiLoadingDots extends StatefulWidget {
  final Color color;
  final double dotSize;

  const FufajiLoadingDots({super.key, this.color = AppTheme.primary, this.dotSize = 8});

  @override
  State<FufajiLoadingDots> createState() => _FufajiLoadingDotsState();
}

class _FufajiLoadingDotsState extends State<FufajiLoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value + 1.0 - i / 3.0) % 1.0;
          final bounce = math.sin(phase * math.pi).clamp(0.0, 1.0);
          return Container(
            margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.4),
            width: widget.dotSize,
            height: widget.dotSize,
            transform: Matrix4.translationValues(0, -widget.dotSize * 1.2 * bounce, 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.55 + 0.45 * bounce),
            ),
          );
        }),
      ),
    );
  }
}

// ── AnimatedTabItem — bottom nav tab with animated scale + indicator ──────────

class AnimatedTabItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const AnimatedTabItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<AnimatedTabItem> createState() => _AnimatedTabItemState();
}

class _AnimatedTabItemState extends State<AnimatedTabItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _indicatorWidth;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.18,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _indicatorWidth = Tween<double>(
      begin: 0,
      end: 24,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.isSelected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedTabItem old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _ctrl.forward(from: 0);
    } else if (!widget.isSelected && old.isSelected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active dot indicator
            Container(
              width: _indicatorWidth.value,
              height: 3,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            // Icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: _scale.value,
                  child: Icon(
                    widget.isSelected ? widget.activeIcon : widget.icon,
                    color: widget.isSelected ? AppTheme.primary : Colors.grey[500],
                    size: 24,
                  ),
                ),
                if (widget.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        widget.badgeCount > 99 ? '99+' : widget.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w400,
                color: widget.isSelected ? AppTheme.primary : Colors.grey[500],
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CartAddBurst — quick scale-up burst when item added to cart ───────────────

class CartAddBurst extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const CartAddBurst({super.key, required this.child, required this.trigger});

  @override
  State<CartAddBurst> createState() => _CartAddBurstState();
}

class _CartAddBurstState extends State<CartAddBurst> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(CartAddBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}

// ── SlideUpReveal — for bottom sheets and modal-style cards ──────────────────

class SlideUpReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const SlideUpReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
  });

  @override
  State<SlideUpReveal> createState() => _SlideUpRevealState();
}

class _SlideUpRevealState extends State<SlideUpReveal> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _fade.value,
        child: FractionalTranslation(translation: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ── FloatingSparklesBackground — orange-bg sparkle field (for auth/onboarding)─

class FloatingSparklesBackground extends StatefulWidget {
  final Widget child;
  final Color bgColor;
  final int sparkleCount;

  const FloatingSparklesBackground({
    super.key,
    required this.child,
    this.bgColor = const Color(0xFFFF6B00),
    this.sparkleCount = 8,
  });

  @override
  State<FloatingSparklesBackground> createState() => _FloatingSparklesBackgroundState();
}

class _FloatingSparklesBackgroundState extends State<FloatingSparklesBackground> {
  final _rng = math.Random(42);

  late final List<double> _xFracs;
  late final List<double> _yFracs;
  late final List<double> _sizes;

  @override
  void initState() {
    super.initState();
    _xFracs = List.generate(widget.sparkleCount, (_) => _rng.nextDouble());
    _yFracs = List.generate(widget.sparkleCount, (_) => _rng.nextDouble());
    _sizes = List.generate(widget.sparkleCount, (_) => 6 + _rng.nextDouble() * 6);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: widget.bgColor)),
              ...List.generate(widget.sparkleCount, (i) {
                return Positioned(
                  left: _xFracs[i] * constraints.maxWidth,
                  top: _yFracs[i] * constraints.maxHeight,
                  child: AnimatedSparkle(size: _sizes[i], phaseOffset: i / widget.sparkleCount),
                );
              }),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

// ── ConfettiShower — stateful widget with GlobalKey<ConfettiShowerState>.play()
//    API matches usage in order_confirmation_screen.dart:
//      ConfettiShower(key: _key, count: 70, autoPlay: false, child: ...)
//      _key.currentState?.play()
// ─────────────────────────────────────────────────────────────────────────────

class ConfettiShower extends StatefulWidget {
  final Widget child;
  final int count;
  final bool autoPlay;
  final Duration duration;

  const ConfettiShower({
    super.key,
    required this.child,
    this.count = 60,
    this.autoPlay = true,
    this.duration = const Duration(seconds: 4),
  });

  @override
  ConfettiShowerState createState() => ConfettiShowerState();
}

class ConfettiShowerState extends State<ConfettiShower> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];
  final _rng = math.Random();
  bool _playing = false;

  static const _colors = [
    Color(0xFFFF6B00),
    Color(0xFFFFB347),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFFFFEB3B),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_tick);
    if (widget.autoPlay) play();
  }

  /// Call via GlobalKey: `_confettiKey.currentState?.play()`
  void play() {
    if (_playing) return;
    _playing = true;
    _particles.clear();
    // Spawn particles across screen width
    for (int i = 0; i < widget.count; i++) {
      _particles.add(
        _ConfettiParticle(
          position: Offset(50 + _rng.nextDouble() * 300, -30 - _rng.nextDouble() * 60),
          velocity: Offset((_rng.nextDouble() - 0.5) * 7, 4 + _rng.nextDouble() * 6),
          color: _colors[_rng.nextInt(_colors.length)],
          rotation: _rng.nextDouble() * math.pi * 2,
          rotationSpeed: (_rng.nextDouble() - 0.5) * 0.2,
          size: 7 + _rng.nextDouble() * 9,
          opacity: 1.0,
        ),
      );
    }
    _ctrl.repeat();
    Future.delayed(widget.duration, stop);
  }

  void stop() {
    if (!mounted) return;
    _ctrl.stop();
    setState(() {
      _playing = false;
      _particles.clear();
    });
  }

  void _tick() {
    if (!mounted || !_playing) return;
    setState(() {
      for (final p in _particles) {
        p.position += p.velocity;
        p.velocity = Offset(p.velocity.dx * 0.99, p.velocity.dy + 0.14);
        p.rotation += p.rotationSpeed;
        if (p.position.dy > 750) {
          p.opacity = (p.opacity - 0.035).clamp(0.0, 1.0);
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          widget.child,
          if (_playing)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_particles))),
            ),
        ],
      ),
    );
  }
}

// ── SpringCard — spring-physics entrance for cards in rails/grids ─────────────
//    Usage: SpringCard(delay: Duration(ms: i*55), springDistance: 40, child: ...)

class SpringCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double springDistance;

  const SpringCard({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.springDistance = 32,
  });

  @override
  State<SpringCard> createState() => _SpringCardState();
}

class _SpringCardState extends State<SpringCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<double>(
      begin: widget.springDistance,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: Offset(0, _slide.value), child: child),
      ),
      child: widget.child,
    );
  }
}

// ── CountdownRing — circular progress ring for OTP resend timer ───────────────
//    Usage: CountdownRing(seconds: _timer, size: 44, ringColor: primary,
//             trackColor: primary.withValues(alpha:0.12), textStyle: ...,
//             onComplete: () { setState(()=>_canResend=true); })

class CountdownRing extends StatefulWidget {
  final int seconds;
  final double size;
  final Color ringColor;
  final Color trackColor;
  final TextStyle? textStyle;
  final VoidCallback? onComplete;

  const CountdownRing({
    super.key,
    required this.seconds,
    this.size = 48,
    required this.ringColor,
    required this.trackColor,
    this.textStyle,
    this.onComplete,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late int _maxSeconds;

  @override
  void initState() {
    super.initState();
    _maxSeconds = widget.seconds;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: _maxSeconds),
    )..forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds && widget.seconds > 0) {
      _maxSeconds = widget.seconds;
      _ctrl.duration = Duration(seconds: _maxSeconds);
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final remaining = (widget.seconds * (1.0 - _ctrl.value)).ceil();
        final progress = 1.0 - _ctrl.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: progress,
                  ringColor: widget.ringColor,
                  trackColor: widget.trackColor,
                  strokeWidth: widget.size * 0.08,
                ),
              ),
              Text(
                '$remaining',
                style:
                    widget.textStyle ??
                    TextStyle(
                      fontSize: widget.size * 0.3,
                      fontWeight: FontWeight.bold,
                      color: widget.ringColor,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final ringPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Track
    canvas.drawCircle(center, radius, trackPaint);
    // Ring arc — starts from 12 o'clock, shrinks as timer runs down
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor || old.trackColor != trackColor;
}

// ── ParticlesBurst — success particle explosion, triggered imperatively ───────
//    Usage: ParticlesBurst(key: _burstKey, radius: 120, child: ...)
//           _burstKey.currentState?.trigger()

class ParticlesBurst extends StatefulWidget {
  final Widget? child;
  final double radius;
  final int particleCount;
  final Color color;
  final List<Color>? colors;

  const ParticlesBurst({
    super.key,
    this.child,
    this.radius = 100,
    this.particleCount = 24,
    this.color = const Color(0xFFFF5722),
    this.colors,
  });

  @override
  ParticlesBurstState createState() => ParticlesBurstState();
}

class ParticlesBurstState extends State<ParticlesBurst> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_BurstParticle> _particles = [];
  bool _active = false;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (mounted) setState(() => _active = false);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void trigger() {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      final angle = 2 * math.pi * i / widget.particleCount;
      final speed = widget.radius * (0.5 + _rng.nextDouble() * 0.5);
      _particles.add(
        _BurstParticle(
          dx: math.cos(angle) * speed,
          dy: math.sin(angle) * speed,
          color: widget.colors != null && widget.colors!.isNotEmpty
              ? widget.colors![_rng.nextInt(widget.colors!.length)]
              : HSVColor.fromAHSV(
                  1.0,
                  _rng.nextDouble() * 60 + 10,
                  0.8 + _rng.nextDouble() * 0.2,
                  0.9 + _rng.nextDouble() * 0.1,
                ).toColor(),
          size: 4 + _rng.nextDouble() * 6,
        ),
      );
    }
    setState(() => _active = true);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.child != null) widget.child!,
        if (_active)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => CustomPaint(
                    painter: _BurstPainter(particles: _particles, progress: _ctrl.value),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BurstParticle {
  final double dx;
  final double dy;
  final Color color;
  final double size;
  const _BurstParticle({
    required this.dx,
    required this.dy,
    required this.color,
    required this.size,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_BurstParticle> particles;
  final double progress;

  _BurstPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ease = Curves.easeOut.transform(progress);
    final fade = 1.0 - Curves.easeIn.transform(progress);

    for (final p in particles) {
      final pos = center + Offset(p.dx * ease, p.dy * ease + 60 * ease * ease);
      final paint = Paint()
        ..color = p.color.withValues(alpha: fade)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1.0 - ease * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

// ── ImageFadeIn — fade-in animation for network images (300ms) ─────────────────
/// Smooth fade-in transition for images as they load
/// Usage: ImageFadeIn(imageUrl: '...', child: Image(...))

class ImageFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ImageFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<ImageFadeIn> createState() => _ImageFadeInState();
}

class _ImageFadeInState extends State<ImageFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (_, child) => Opacity(opacity: _fade.value, child: child),
      child: widget.child,
    );
  }
}

// ── ButtonHoverScale — hover scale effect for buttons (150ms) ──────────────────
/// Interactive scale-up animation on hover (desktop) or press (mobile)
/// Usage: ButtonHoverScale(onTap: () {...}, child: Button(...))

class ButtonHoverScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const ButtonHoverScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 1.05,
  });

  @override
  State<ButtonHoverScale> createState() => _ButtonHoverScaleState();
}

class _ButtonHoverScaleState extends State<ButtonHoverScale> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onHoverStart() {
    if (!_isHovered) {
      _isHovered = true;
      _ctrl.forward();
    }
  }

  void _onHoverEnd() {
    if (_isHovered) {
      _isHovered = false;
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverStart(),
      onExit: (_) => _onHoverEnd(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── SuccessPulse — pulsing glow animation for success states (500ms) ────────────
/// Repeating pulse animation with glow effect for success messages
/// Usage: SuccessPulse(child: Icon(...))

class SuccessPulse extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final Duration duration;

  const SuccessPulse({
    super.key,
    required this.child,
    this.glowColor = AppTheme.success,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<SuccessPulse> createState() => _SuccessPulseState();
}

class _SuccessPulseState extends State<SuccessPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.glowColor.withValues(alpha: _glow.value * 0.5),
              blurRadius: 20 * _glow.value,
              spreadRadius: 4 * _glow.value,
            ),
          ],
        ),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}
