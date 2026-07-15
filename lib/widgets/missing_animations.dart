import 'package:flutter/material.dart';

class LiquidProgressBar extends StatelessWidget {
  final double value;
  final double? width;
  final double? height;
  final Color? color;

  const LiquidProgressBar({super.key, required this.value, this.width, this.height, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? 10,
      child: LinearProgressIndicator(
        value: value,
        color: color ?? Theme.of(context).primaryColor,
        backgroundColor: (color ?? Theme.of(context).primaryColor).withOpacity(0.2),
      ),
    );
  }
}

class AnimatedCheck extends StatelessWidget {
  final Color? color;
  final double? size;

  const AnimatedCheck({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.check_circle, color: color ?? Colors.green, size: size ?? 64);
  }
}

class MorphNumber extends StatelessWidget {
  final num value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;

  const MorphNumber({super.key, required this.value, this.prefix, this.suffix, this.style});

  @override
  Widget build(BuildContext context) {
    return Text('${prefix ?? ''}$value${suffix ?? ''}', style: style);
  }
}

class FloatingBubbles extends StatelessWidget {
  final Color? color;
  final int? count;

  const FloatingBubbles({super.key, this.color, this.count});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class PulsingLive extends StatelessWidget {
  final Color? color;
  final double? size;
  final String? label;

  const PulsingLive({super.key, this.color, this.size, this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fiber_manual_record, color: color ?? Colors.red, size: size ?? 12),
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(label!, style: TextStyle(color: color ?? Colors.red)),
        ],
      ],
    );
  }
}

class WaveDivider extends StatelessWidget {
  final Color? color;
  final double? height;
  final double? speed;

  const WaveDivider({super.key, this.color, this.height, this.speed});

  @override
  Widget build(BuildContext context) {
    return Divider(color: color, height: height);
  }
}
