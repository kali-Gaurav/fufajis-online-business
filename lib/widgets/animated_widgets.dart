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
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _offsetAnim = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: AppTheme.curveEntrance),
    );

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
          child: FractionalTranslation(
            translation: _offsetAnim.value,
            child: widget.child,
          ),
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

  const ScaleBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
  });

  @override
  State<ScaleBounce> createState() => _ScaleBounceState();
}

class _ScaleBounceState extends State<ScaleBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );
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
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _alignAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
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
              colors: const [
                AppTheme.shimmerBase,
                AppTheme.shimmerHighlight,
                AppTheme.shimmerBase,
              ],
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
        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
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
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
    _glowAnim = Tween<double>(begin: 0.0, end: widget.maxRadius).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
                color: widget.glowColor.withValues(
                  alpha: (1.0 - _controller.value) * 0.4,
                ),
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
    _controller = AnimationController(
      vsync: this,
      duration: widget.speed * widget.text.length,
    );

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

/// A Staggered entrance anim list helper
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration delayStep;
  final Duration itemDuration;
  final Axis scrollDirection;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const StaggeredList({
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
        return fallbackBuilder != null 
            ? fallbackBuilder!(context) 
            : const SizedBox.shrink();
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
            transform: Matrix4.translationValues(
                0, -widget.bounceHeight * bounce, 0),
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
    this.gradientColors = const [
      Color(0xFFFF6B00),
      Color(0xFFFFB347),
      Color(0xFFFF6B00),
    ],
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
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _shiftAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
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
      animation: _ctrl,
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment(_shiftAnim.value - 1, 0),
          end: Alignment(_shiftAnim.value + 1, 0),
        ).createShader(bounds),
        child: Text(
          widget.text,
          style: (widget.baseStyle ?? const TextStyle()).copyWith(
            color: Colors.white,
          ),
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

class _SlideUpFadeState extends State<SlideUpFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _offset = Tween<double>(begin: widget.slideDistance, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

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
        child: Transform.translate(
          offset: Offset(0, _offset.value),
          child: child,
        ),
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

class _RippleTapState extends State<RippleTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusMd),
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

  const _RipplePainter({
    required this.position,
    required this.progress,
    required this.color,
  });

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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
            borderRadius:
                widget.label != null ? BorderRadius.circular(30) : null,
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
          padding: EdgeInsets.symmetric(
            horizontal: widget.label != null ? 20 : 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color,
                Color.lerp(widget.color, Colors.black, 0.15) ?? widget.color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: widget.label == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.label != null ? BorderRadius.circular(30) : null,
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

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _previousValue = old.value;
      _anim = Tween<double>(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuad),
      );
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
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
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
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0, 0.6, curve: Curves.elasticOut)),
    );
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
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
            painter: _CheckPainter(
              progress: _checkProgress.value,
              color: widget.color,
            ),
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
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress;
}

