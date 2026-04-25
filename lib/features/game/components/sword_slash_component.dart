import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class SwordSlashComponent extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double _lifetime = 0.35;
  static const double slashWidth = 120;
  static const double slashHeight = 80;

  double _elapsed = 0;
  bool _isActive = false;
  bool get isEffectActive => _isActive;

  final Path _path = Path();
  final Paint _slashPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;

  SwordSlashComponent() {
    size = Vector2(slashWidth, slashHeight);
  }

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
    if (_elapsed >= _lifetime) {
      _isActive = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    _slashPaint.color = Color.fromRGBO(255, 238, 88, alpha);
    _glowPaint.color = Color.fromRGBO(255, 215, 0, alpha * 0.25);

    _path.reset();
    final cx = slashWidth / 2;
    final cy = slashHeight / 2;
    final extent = slashWidth * 0.4 * (0.3 + progress * 0.7);

    // Diagonal slash lines creating an X-like slash effect
    _path.moveTo(cx - extent, cy - extent * 0.6);
    _path.quadraticBezierTo(cx, cy, cx + extent, cy + extent * 0.6);

    _path.moveTo(cx - extent * 0.8, cy + extent * 0.4);
    _path.quadraticBezierTo(cx, cy, cx + extent * 0.8, cy - extent * 0.4);

    canvas.drawPath(_path, _glowPaint);
    canvas.drawPath(_path, _slashPaint);
  }
}
