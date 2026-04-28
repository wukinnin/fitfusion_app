import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

/// A small trophy-icon popup that slides in from the right below the pace timer
/// when an achievement is unlocked during gameplay.
///
/// Animation: slide-in from right (0.5s) → visible (2.0s) → slide-out to right (0.5s) → self-remove.
/// Multiple popups stack downward via [stackIndex].
class AchievementPopup extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double _slideInDuration = 0.5;
  static const double _visibleDuration = 2.0;
  static const double _slideOutDuration = 0.5;
  static const double _totalDuration =
      _slideInDuration + _visibleDuration + _slideOutDuration;

  static const double popupRadius = 30.0;
  static const double popupSpacing = 8.0;

  final int stackIndex;
  double _elapsed = 0;
  final Paint _backgroundPaint = Paint()..color = const Color(0xCC1A1A2E);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final Paint _trophyPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;
  final Paint _handlePaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;
  final Paint _starPaint = Paint()
    ..color = const Color(0xFF1A1A2E)
    ..style = PaintingStyle.fill;
  final Path _cupPath = Path();
  final Path _starPath = Path();

  AchievementPopup({required this.stackIndex});

  /// The Y offset for this popup based on its stack position.
  /// Positioned below the pace timer area (row2Y ≈ 66, pace timer height ≈ 84).
  double get _baseY =>
      66.0 + 84.0 + 12.0 + stackIndex * (popupRadius * 2 + popupSpacing);

  /// The resting X position (fully visible) — right-aligned like the pace timer.
  double get _restX => game.size.x - popupRadius * 2 - 12;

  /// Off-screen X position (hidden to the right).
  double get _offScreenX => game.size.x + popupRadius;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= _totalDuration) {
      removeFromParent();
      return;
    }

    // Calculate current X based on animation phase
    double x;
    if (_elapsed < _slideInDuration) {
      // Slide in from right
      final t = (_elapsed / _slideInDuration).clamp(0.0, 1.0);
      final eased = _easeOutCubic(t);
      x = _offScreenX + (_restX - _offScreenX) * eased;
    } else if (_elapsed < _slideInDuration + _visibleDuration) {
      // Stationary
      x = _restX;
    } else {
      // Slide out to right
      final t =
          ((_elapsed - _slideInDuration - _visibleDuration) / _slideOutDuration)
              .clamp(0.0, 1.0);
      final eased = _easeInCubic(t);
      x = _restX + (_offScreenX - _restX) * eased;
    }

    position.x = x;
    position.y = _baseY;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(popupRadius, popupRadius);

    // Background circle — dark with slight transparency
    canvas.drawCircle(center, popupRadius, _backgroundPaint);

    // Gold border
    canvas.drawCircle(center, popupRadius, _borderPaint);

    // Trophy icon — drawn as a simple geometric shape
    _drawTrophy(canvas, center, popupRadius * 0.45);
  }

  void _drawTrophy(Canvas canvas, Offset center, double size) {
    final cx = center.dx;
    final cy = center.dy;

    // Cup body (trapezoid shape)
    _cupPath.reset();
    _cupPath.moveTo(cx - size * 0.6, cy - size * 0.5);
    _cupPath.lineTo(cx + size * 0.6, cy - size * 0.5);
    _cupPath.lineTo(cx + size * 0.35, cy + size * 0.15);
    _cupPath.lineTo(cx - size * 0.35, cy + size * 0.15);
    _cupPath.close();
    canvas.drawPath(_cupPath, _trophyPaint);

    // Left handle
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - size * 0.65, cy - size * 0.15),
        width: size * 0.35,
        height: size * 0.5,
      ),
      -math.pi * 0.3,
      math.pi * 0.8,
      false,
      _handlePaint,
    );

    // Right handle
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx + size * 0.65, cy - size * 0.15),
        width: size * 0.35,
        height: size * 0.5,
      ),
      math.pi * 0.5,
      math.pi * 0.8,
      false,
      _handlePaint,
    );

    // Stem
    canvas.drawLine(
      Offset(cx, cy + size * 0.15),
      Offset(cx, cy + size * 0.5),
      _strokePaint,
    );

    // Base
    canvas.drawLine(
      Offset(cx - size * 0.35, cy + size * 0.5),
      Offset(cx + size * 0.35, cy + size * 0.5),
      _strokePaint,
    );

    // Star in center of cup
    _drawStar(canvas, Offset(cx, cy - size * 0.18), size * 0.18);
  }

  void _drawStar(Canvas canvas, Offset center, double radius) {
    _starPath.reset();
    const int points = 5;
    final innerRadius = radius * 0.4;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : innerRadius;
      final angle = -math.pi / 2 + (i * math.pi / points);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        _starPath.moveTo(x, y);
      } else {
        _starPath.lineTo(x, y);
      }
    }
    _starPath.close();
    canvas.drawPath(_starPath, _starPaint);
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
  double _easeInCubic(double t) => t * t * t;
}
