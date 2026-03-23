import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../fitfusion_game.dart';

class PaceTimerIndicator extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double radius = 42;
  static const double dangerThreshold = 2.0;

  double _remainingSeconds = kPaceThresholdSeconds;
  bool _isActive = false;

  void setRemaining(double seconds) {
    _remainingSeconds = seconds.clamp(0.0, kPaceThresholdSeconds);
  }

  void setActive(bool active) {
    _isActive = active;
    if (!active) {
      _remainingSeconds = kPaceThresholdSeconds;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    final center = Offset(radius, radius);
    final fraction = _remainingSeconds / kPaceThresholdSeconds;
    final isDanger = _remainingSeconds <= dangerThreshold;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xCC1A1A2E),
    );

    // Progress arc
    final arcPaint = Paint()
      ..color = isDanger ? const Color(0xFFB71C1C) : const Color(0xFF76FF03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 5),
      -math.pi / 2,
      fraction * 2 * math.pi,
      false,
      arcPaint,
    );

    // Border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = isDanger ? const Color(0xFFB71C1C) : const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Number text
    final seconds = _remainingSeconds.ceil();
    final textSpan = TextSpan(
      text: '$seconds',
      style: GoogleFonts.cinzel(
        color: isDanger ? const Color(0xFFB71C1C) : const Color(0xFFFFFDE7),
        fontSize: 44,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
}
