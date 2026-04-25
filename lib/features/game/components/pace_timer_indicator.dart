import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../fitfusion_game.dart';

class PaceTimerIndicator extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double radius = 42;
  static const double dangerThreshold = 2.0;
  static const Offset _center = Offset(radius, radius);
  static final Rect _arcRect = Rect.fromCircle(
    center: _center,
    radius: radius - 5,
  );

  double _remainingSeconds = kPaceThresholdSeconds;
  bool _isActive = false;

  final Paint _backgroundPaint = Paint()..color = const Color(0xCC1A1A2E);
  final Paint _arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final List<TextPainter> _normalDigitPainters;
  late final List<TextPainter> _dangerDigitPainters;

  PaceTimerIndicator() {
    size = Vector2.all(radius * 2);
    _normalDigitPainters = _buildDigitPainters(const Color(0xFFFFFDE7));
    _dangerDigitPainters = _buildDigitPainters(const Color(0xFFB71C1C));
  }

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

    final fraction = _remainingSeconds / kPaceThresholdSeconds;
    final isDanger = _remainingSeconds <= dangerThreshold;
    _arcPaint.color = isDanger
        ? const Color(0xFFB71C1C)
        : const Color(0xFF76FF03);
    _borderPaint.color = isDanger
        ? const Color(0xFFB71C1C)
        : const Color(0xFFFFD700);

    // Background circle
    canvas.drawCircle(_center, radius, _backgroundPaint);

    canvas.drawArc(
      _arcRect,
      -math.pi / 2,
      fraction * 2 * math.pi,
      false,
      _arcPaint,
    );

    // Border
    canvas.drawCircle(_center, radius, _borderPaint);

    // Number text
    final seconds = _remainingSeconds.ceil();
    final tp = isDanger
        ? _dangerDigitPainters[seconds]
        : _normalDigitPainters[seconds];
    tp.paint(
      canvas,
      Offset(_center.dx - tp.width / 2, _center.dy - tp.height / 2),
    );
  }

  List<TextPainter> _buildDigitPainters(Color color) {
    return List.generate(kPaceThresholdSeconds.ceil() + 1, (seconds) {
      return TextPainter(
        text: TextSpan(
          text: '$seconds',
          style: GoogleFonts.cinzel(
            color: color,
            fontSize: 44,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}
