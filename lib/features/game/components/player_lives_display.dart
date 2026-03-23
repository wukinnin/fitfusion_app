import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../fitfusion_game.dart';

class PlayerLivesDisplay extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double heartSize = 66;
  static const double heartSpacing = 14;

  int _lives = kStartingLives;

  final Paint _activePaint = Paint()..color = const Color(0xFF1A3A8A);
  final Paint _lostPaint = Paint()..color = const Color(0xFF1A1A2E);

  void setLives(int lives) {
    _lives = lives;
  }

  static double get totalWidth =>
      kStartingLives * heartSize + (kStartingLives - 1) * heartSpacing;

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < kStartingLives; i++) {
      final isActive = i < _lives;
      final paint = isActive ? _activePaint : _lostPaint;
      final cx = i * (heartSize + heartSpacing) + heartSize / 2;
      final cy = heartSize / 2;

      _drawHeart(canvas, cx, cy, heartSize * 0.45, paint);
    }
  }

  void _drawHeart(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final path = Path();
    final r = radius;
    path.moveTo(cx, cy + r * 0.5);
    path.cubicTo(cx - r * 1.2, cy - r * 0.3, cx - r * 0.6, cy - r * 1.2, cx, cy - r * 0.5);
    path.cubicTo(cx + r * 0.6, cy - r * 1.2, cx + r * 1.2, cy - r * 0.3, cx, cy + r * 0.5);
    path.close();
    canvas.drawPath(path, paint);

    final outlinePaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, outlinePaint);
  }
}
