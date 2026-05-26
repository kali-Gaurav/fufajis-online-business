import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ScratchCardWidget extends StatefulWidget {
  final Widget child; // Revealed content
  final String title;
  final String subtitle;
  final VoidCallback onThresholdReached;

  const ScratchCardWidget({
    super.key,
    required this.child,
    this.title = 'Scratch & Win!',
    this.subtitle = 'Reveal your delivery cash bonus',
    required this.onThresholdReached,
  });

  @override
  State<ScratchCardWidget> createState() => _ScratchCardWidgetState();
}

class _ScratchCardWidgetState extends State<ScratchCardWidget> {
  final List<Offset> _points = [];
  bool _isScratched = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.grey600,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.grey200, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Underlying reward content
                Center(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    child: Center(child: widget.child),
                  ),
                ),
                // Scratchable silver overlay paint
                if (!_isScratched)
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final RenderBox renderBox = context.findRenderObject() as RenderBox;
                        final localOffset = renderBox.globalToLocal(details.globalPosition);
                        
                        // Limit tracking to bounds of box to prevent errors
                        if (localOffset.dx >= 0 &&
                            localOffset.dx <= 250 &&
                            localOffset.dy >= 0 &&
                            localOffset.dy <= 250) {
                          _points.add(localOffset);
                        }

                        // Auto reveal if user scratches a significant amount
                        if (_points.length > 80) {
                          _isScratched = true;
                          widget.onThresholdReached();
                        }
                      });
                    },
                    child: CustomPaint(
                      size: const Size(250, 250),
                      painter: ScratchPainter(points: List.from(_points)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScratchPainter extends CustomPainter {
  final List<Offset> points;

  ScratchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw the beautiful premium silver-gray overlay
    final Paint silverPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [
          Colors.grey[300]!,
          Colors.grey[400]!,
          Colors.grey[500]!,
          Colors.grey[400]!,
          Colors.grey[300]!,
        ],
      );

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(22),
      ),
      silverPaint,
    );

    // 2. Draw subtle greeting patterns on the silver card for premium looks
    final Paint patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double i = -size.width; i < size.width * 2; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), patternPaint);
    }

    // 3. Clear/erase along the scratch paths
    final Paint erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 35.0
      ..style = PaintingStyle.stroke;

    if (points.isNotEmpty) {
      final Path path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, erasePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScratchPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}

