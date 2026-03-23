import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class DamageNumber extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double _lifetime = 1.0;
  static const double _riseSpeed = 60.0;

  double _elapsed = 0;

  DamageNumber({required Vector2 startPosition}) {
    position = startPosition;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    position.y -= _riseSpeed * dt;

    if (_elapsed >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1.0 - (_elapsed / _lifetime)).clamp(0.0, 1.0);
    final color = Color.fromRGBO(255, 215, 0, alpha);

    final textSpan = TextSpan(
      text: '-1',
      style: TextStyle(
        color: color,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(blurRadius: 4, color: Colors.black.withValues(alpha: alpha)),
        ],
      ),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }
}
