import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The SecureCampus mark - a proper shield badge (outline + inner
/// circular emblem, like a security seal) with real depth (gradient
/// fill + layered shadow, not a flat stock icon) and two deliberately
/// restrained animations: a gentle settle-in on first appearance, and
/// a slow, continuous light sheen sweeping across it. Both read as
/// premium/professional rather than playful - no bounce, no spin, no
/// color cycling. Shared across screens (login, library scan, etc.)
/// rather than duplicated per-screen.
class AnimatedShieldLogo extends StatefulWidget {
  final double size;
  const AnimatedShieldLogo({super.key, this.size = 76});

  @override
  State<AnimatedShieldLogo> createState() => _AnimatedShieldLogoState();
}

class _AnimatedShieldLogoState extends State<AnimatedShieldLogo> with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _sheen;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
    _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final eased = Curves.easeOutBack.transform(_entrance.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: _entrance.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.85 + 0.15 * eased, child: child),
        );
      },
      child: SizedBox(
        width: size,
        height: size * 1.12,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft drop shadow, shaped to match the shield silhouette
            // rather than a generic rectangle shadow.
            CustomPaint(size: Size(size, size * 1.12), painter: _ShieldShadowPainter()),
            CustomPaint(size: Size(size, size * 1.12), painter: _ShieldPainter()),
            AnimatedBuilder(
              animation: _sheen,
              builder: (context, _) {
                final progress = Curves.easeInOutSine.transform(_sheen.value);
                return ClipPath(
                  clipper: _ShieldClipper(),
                  child: SizedBox(
                    width: size,
                    height: size * 1.12,
                    child: Transform.translate(
                      offset: Offset((progress * 2 - 1) * size * 1.3, 0),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Container(
                          width: size * 0.26,
                          height: size * 1.6,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The shield silhouette - flat-ish top, sides tapering to a point at
/// the bottom, in a coordinate space scaled to fit whatever size is
/// requested.
Path _shieldPath(Size size) {
  final w = size.width;
  final h = size.height;
  final path = Path();
  path.moveTo(w * 0.5, h * 0.02);
  path.cubicTo(w * 0.5, h * 0.02, w * 0.94, h * 0.10, w * 0.94, h * 0.10);
  path.cubicTo(w * 0.97, h * 0.46, w * 0.90, h * 0.76, w * 0.5, h * 0.99);
  path.cubicTo(w * 0.10, h * 0.76, w * 0.03, h * 0.46, w * 0.06, h * 0.10);
  path.cubicTo(w * 0.06, h * 0.10, w * 0.5, h * 0.02, w * 0.5, h * 0.02);
  path.close();
  return path;
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _shieldPath(size);
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ShieldShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _shieldPath(size);
    canvas.save();
    canvas.translate(0, size.height * 0.06);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryBlue.withValues(alpha: 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shield fill (blue gradient) + a white circular emblem inside, with
/// a ring of small satellite dots, connecting spokes, and a top
/// "visor" arc - a proper seal/badge composition rather than a stock
/// outline icon.
class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = _shieldPath(size);

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fillPaint);

    // Thin lighter inset border for a "badge edge" look.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.018
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    final center = Offset(size.width * 0.5, size.height * 0.44);
    final ringRadius = size.width * 0.24;
    final coreRadius = size.width * 0.11;

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    for (var i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2 - math.pi / 2;
      final dot = Offset(
        center.dx + ringRadius * 1.28 * math.cos(angle),
        center.dy + ringRadius * 1.28 * math.sin(angle),
      );
      canvas.drawCircle(dot, size.width * 0.022, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }

    canvas.drawCircle(center, coreRadius, Paint()..color = Colors.white);

    for (var i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2 - math.pi / 2;
      final inner = Offset(center.dx + coreRadius * math.cos(angle), center.dy + coreRadius * math.sin(angle));
      final outer = Offset(center.dx + ringRadius * math.cos(angle), center.dy + ringRadius * math.sin(angle));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = size.width * 0.012
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    final visorRect = Rect.fromCircle(center: center, radius: ringRadius * 1.55);
    canvas.drawArc(
      visorRect,
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}