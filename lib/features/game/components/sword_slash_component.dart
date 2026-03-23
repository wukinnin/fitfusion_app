import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class SwordSlashComponent extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double _lifetime = 0.35;
  static const double slashWidth = 120;
  static const double slashHeight = 80;

  double _elapsed = 0;

  SwordSlashComponent({required Vector2 startPosition}) {
    position = startPosition;
    size = Vector2(slashWidth, slashHeight);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = Color.fromRGBO(255, 238, 88, alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final cx = slashWidth / 2;
    final cy = slashHeight / 2;
    final extent = slashWidth * 0.4 * (0.3 + progress * 0.7);

    // Diagonal slash lines creating an X-like slash effect
    path.moveTo(cx - extent, cy - extent * 0.6);
    path.quadraticBezierTo(cx, cy, cx + extent, cy + extent * 0.6);

    path.moveTo(cx - extent * 0.8, cy + extent * 0.4);
    path.quadraticBezierTo(cx, cy, cx + extent * 0.8, cy - extent * 0.4);

    canvas.drawPath(path, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = Color.fromRGBO(255, 215, 0, alpha * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
  }
}
