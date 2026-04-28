import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class DamageNumber extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double _lifetime = 1.0;
  static const double _riseSpeed = 60.0;

  double _elapsed = 0;
  bool _isActive = false;
  bool get isEffectActive => _isActive;

  final TextPainter _textPainter = TextPainter(
    text: const TextSpan(
      text: '-1',
      style: TextStyle(
        color: Color(0xFFFFD700),
        fontSize: 32,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void activateAt(double x, double y) {
    position.x = x;
    position.y = y;
    _elapsed = 0;
    _isActive = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isActive) return;

    _elapsed += dt;
    position.y -= _riseSpeed * dt;

    if (_elapsed >= _lifetime) {
      _isActive = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    _textPainter.paint(
      canvas,
      Offset(-_textPainter.width / 2, -_textPainter.height / 2),
    );
  }
}
