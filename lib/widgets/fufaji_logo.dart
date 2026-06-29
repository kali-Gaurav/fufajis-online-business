// ============================================================
//  FufajiLogo — Custom brand logo widget
//
//  Replaces the shopping-bag icon with a beautiful custom-painted
//  traditional Indian kirana shop facade that suits Fufaji's Store.
//
//  Variants:
//    FufajiLogo()              — full colour (for light backgrounds)
//    FufajiLogo.onDark()       — white outline (for dark/orange backgrounds)
//    FufajiLogoBadge()         — small circular badge for app bars / tiles
// ============================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;

// ── Primary logo widget ────────────────────────────────────

class FufajiLogo extends StatelessWidget {
  final double size;
  final bool onDark;

  const FufajiLogo({
    super.key,
    this.size = 120,
    this.onDark = false,
  });

  const FufajiLogo.onDark({
    super.key,
    this.size = 120,
  }) : onDark = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? Colors.white : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: onDark ? 0.20 : 0.12),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          painter: _ShopPainter(),
          size: Size(size, size),
        ),
      ),
    );
  }
}

// ── Small badge variant ────────────────────────────────────

class FufajiLogoBadge extends StatelessWidget {
  final double size;
  const FufajiLogoBadge({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8F00), Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5722).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'फ',
          style: TextStyle(
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Custom painter — kirana shop facade ───────────────────

class _ShopPainter extends CustomPainter {
  static const _primary      = Color(0xFFFF5722);
  static const _primaryDark  = Color(0xFFE64A19);
  static const _primaryLight = Color(0xFFFF8A65);
  static const _accent       = Color(0xFFFFB300);
  static const _sky          = Color(0xFFE3F2FD);
  static const _wall         = Color(0xFFFFF8F2);
  static const _wallEdge     = Color(0xFFFFE0CC);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..isAntiAlias = true;
    final w = s.width;
    final h = s.height;

    // ── Background sky ─────────────────────────────────────
    p.color = _sky;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);

    // ── Ground strip ───────────────────────────────────────
    const groundGrad = LinearGradient(
      colors: [Color(0xFFBCAAA4), Color(0xFF8D6E63)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    p.shader = groundGrad.createShader(Rect.fromLTWH(0, h * 0.87, w, h * 0.13));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.87, w, h * 0.13), p);
    p.shader = null;

    // ── Shop body (wall) ───────────────────────────────────
    p.color = _wall;
    _drawRounded(canvas, Rect.fromLTWH(w * 0.07, h * 0.36, w * 0.86, h * 0.52), 6, p);
    p.color = _wallEdge;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.2;
    _drawRounded(canvas, Rect.fromLTWH(w * 0.07, h * 0.36, w * 0.86, h * 0.52), 6, p);
    p.style = PaintingStyle.fill;

    // ── Awning / canopy ────────────────────────────────────
    const awningGrad = LinearGradient(
      colors: [Color(0xFFFF8F00), _primary, _primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    p.shader = awningGrad.createShader(Rect.fromLTWH(0, h * 0.10, w, h * 0.32));

    final awning = Path()
      ..moveTo(w * 0.03, h * 0.41)
      ..lineTo(w * 0.5, h * 0.10)
      ..lineTo(w * 0.97, h * 0.41)
      ..close();
    canvas.drawPath(awning, p);
    p.shader = null;

    // Awning stripes (darker diagonal bands)
    p.color = _primaryDark.withValues(alpha: 0.30);
    for (int i = 0; i < 5; i++) {
      final x0 = w * (0.10 + i * 0.19);
      final x1 = w * (0.5 + (i - 2) * 0.12);
      final stripe = Path()
        ..moveTo(x0, h * 0.41)
        ..lineTo(x1, h * 0.10)
        ..lineTo(x1 + w * 0.06, h * 0.10)
        ..lineTo(x0 + w * 0.06, h * 0.41)
        ..close();
      canvas.drawPath(stripe, p);
    }

    // Awning bottom fringe
    p.color = _primaryDark;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.5;
    canvas.drawLine(Offset(w * 0.03, h * 0.41), Offset(w * 0.97, h * 0.41), p);
    p.style = PaintingStyle.fill;

    // Fringe drops
    p.color = _primaryDark;
    const drops = 9;
    for (int i = 0; i < drops; i++) {
      final x = w * (0.09 + i * (0.82 / (drops - 1)));
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2.5, h * 0.41, 5, h * 0.04),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, p);
      canvas.drawCircle(Offset(x, h * 0.452), 3.5, p);
    }

    // ── Sign board ─────────────────────────────────────────
    const signGrad = LinearGradient(
      colors: [Color(0xFFFF8F00), _primary],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    p.shader = signGrad.createShader(Rect.fromLTWH(w * 0.15, h * 0.355, w * 0.70, h * 0.115));
    _drawRounded(
      canvas,
      Rect.fromLTWH(w * 0.15, h * 0.355, w * 0.70, h * 0.115),
      5,
      p,
    );
    p.shader = null;

    // Sign border
    p.color = _accent;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.5;
    _drawRounded(canvas, Rect.fromLTWH(w * 0.15, h * 0.355, w * 0.70, h * 0.115), 5, p);
    p.style = PaintingStyle.fill;

    // "फुफाजी" text on sign
    _drawText(canvas, 'फुफाजी', Offset(w * 0.5, h * 0.397),
        fontSize: w * 0.145, color: Colors.white, bold: true, centerX: true);

    // ── Left window ────────────────────────────────────────
    _drawWindow(canvas, Rect.fromLTWH(w * 0.11, h * 0.49, w * 0.23, h * 0.20), w);

    // ── Right window ───────────────────────────────────────
    _drawWindow(canvas, Rect.fromLTWH(w * 0.66, h * 0.49, w * 0.23, h * 0.20), w);

    // ── Door ───────────────────────────────────────────────
    p.color = _primaryLight.withValues(alpha: 0.25);
    final doorRect = Rect.fromLTWH(w * 0.36, h * 0.50, w * 0.28, h * 0.37);
    final doorRRect = RRect.fromRectAndCorners(
      doorRect,
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
    );
    canvas.drawRRect(doorRRect, p);

    p.color = _primary.withValues(alpha: 0.60);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.8;
    canvas.drawRRect(doorRRect, p);
    p.style = PaintingStyle.fill;

    // Door arch
    p.color = _primaryLight.withValues(alpha: 0.45);
    final archRect = Rect.fromLTWH(w * 0.36, h * 0.50, w * 0.28, w * 0.28);
    canvas.drawArc(archRect, math.pi, math.pi, false, p);

    // Door panel line
    p.color = _primaryDark.withValues(alpha: 0.35);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.0;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.50),
      Offset(w * 0.5, h * 0.87),
      p,
    );
    p.style = PaintingStyle.fill;

    // Door handle
    p.color = _accent;
    canvas.drawCircle(Offset(w * 0.565, h * 0.69), w * 0.030, p);
    p.color = _primaryDark;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.2;
    canvas.drawCircle(Offset(w * 0.565, h * 0.69), w * 0.030, p);
    p.style = PaintingStyle.fill;

    // ── Steps ─────────────────────────────────────────────
    p.color = const Color(0xFFBCAAA4);
    canvas.drawRect(Rect.fromLTWH(w * 0.32, h * 0.87, w * 0.36, h * 0.025), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.28, h * 0.893, w * 0.44, h * 0.025), p);

    // ── Hanging string lights ──────────────────────────────
    _drawStringLights(canvas, w, h);

    // ── Stars / sparkles ───────────────────────────────────
    _drawSparkle(canvas, Offset(w * 0.14, h * 0.22), w * 0.026);
    _drawSparkle(canvas, Offset(w * 0.84, h * 0.18), w * 0.020);
    _drawSparkle(canvas, Offset(w * 0.5,  h * 0.045), w * 0.016);
  }

  void _drawRounded(Canvas c, Rect r, double radius, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
  }

  void _drawWindow(Canvas canvas, Rect rect, double w) {
    final p = Paint()..isAntiAlias = true;

    // Frame
    p.color = _primaryLight.withValues(alpha: 0.30);
    _drawRounded(canvas, rect, 5, p);
    p.color = _primary.withValues(alpha: 0.55);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.8;
    _drawRounded(canvas, rect, 5, p);
    p.style = PaintingStyle.fill;

    // Pane (glass tint)
    p.color = const Color(0xFFB3E5FC).withValues(alpha: 0.55);
    _drawRounded(
      canvas,
      rect.deflate(3),
      3,
      p,
    );

    // Cross divider
    p.color = _primary.withValues(alpha: 0.40);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.2;
    canvas.drawLine(
      Offset(rect.center.dx, rect.top + 2),
      Offset(rect.center.dx, rect.bottom - 2),
      p,
    );
    canvas.drawLine(
      Offset(rect.left + 2, rect.center.dy),
      Offset(rect.right - 2, rect.center.dy),
      p,
    );

    // Small shelf silhouette inside window
    p.color = _primaryDark.withValues(alpha: 0.20);
    canvas.drawLine(
      Offset(rect.left + 5, rect.center.dy + rect.height * 0.18),
      Offset(rect.right - 5, rect.center.dy + rect.height * 0.18),
      p,
    );
    p.style = PaintingStyle.fill;

    // Tiny product dots on shelf
    p.color = const Color(0xFFFFB300).withValues(alpha: 0.70);
    canvas.drawCircle(
        Offset(rect.center.dx - rect.width * 0.2, rect.center.dy + rect.height * 0.10),
        rect.width * 0.09, p);
    p.color = const Color(0xFF4CAF50).withValues(alpha: 0.70);
    canvas.drawCircle(
        Offset(rect.center.dx + rect.width * 0.05, rect.center.dy + rect.height * 0.10),
        rect.width * 0.09, p);
    p.color = const Color(0xFFE53935).withValues(alpha: 0.70);
    canvas.drawCircle(
        Offset(rect.center.dx + rect.width * 0.28, rect.center.dy + rect.height * 0.10),
        rect.width * 0.08, p);
  }

  void _drawStringLights(Canvas canvas, double w, double h) {
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.60);

    // Sagging string
    final path = Path();
    path.moveTo(w * 0.07, h * 0.42);
    path.quadraticBezierTo(w * 0.5, h * 0.35, w * 0.93, h * 0.42);
    canvas.drawPath(path, p);

    p.style = PaintingStyle.fill;
    final bulbColors = [
      const Color(0xFFFF5252),
      const Color(0xFFFFD740),
      const Color(0xFF69F0AE),
      const Color(0xFF40C4FF),
      const Color(0xFFFF5252),
      const Color(0xFFFFD740),
      const Color(0xFF69F0AE),
    ];
    for (int i = 0; i < 7; i++) {
      final t = i / 6.0;
      final bx = w * 0.07 + (w * 0.86) * t;
      final sag = 0.0 - 0.07 * 4 * (t - 0.5) * (t - 0.5); // parabola dip
      final by = h * 0.42 + h * sag;

      p.color = bulbColors[i].withValues(alpha: 0.85);
      canvas.drawOval(Rect.fromCenter(center: Offset(bx, by + h * 0.018), width: w * 0.035, height: h * 0.028), p);
      p.color = Colors.white.withValues(alpha: 0.55);
      canvas.drawOval(Rect.fromCenter(center: Offset(bx - w * 0.005, by + h * 0.014), width: w * 0.010, height: h * 0.008), p);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius) {
    final p = Paint()
      ..color = _accent
      ..isAntiAlias = true;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        p..strokeWidth = 1.5..style = PaintingStyle.stroke,
      );
    }
    canvas.drawCircle(center, radius * 0.35, p..style = PaintingStyle.fill);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    required double fontSize,
    Color color = Colors.white,
    bool bold = false,
    bool centerX = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = centerX
        ? Offset(position.dx - tp.width / 2, position.dy - tp.height / 2)
        : position;
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
