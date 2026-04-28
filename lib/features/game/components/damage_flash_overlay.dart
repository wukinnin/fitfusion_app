import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class DamageFlashOverlay extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double _flashDuration = 2.0;
  static const double _maxOpacity = 0.4;

  double _elapsed = 0;
  bool _isActive = false;
  final Paint _paint = Paint();
  Rect _screenRect = Rect.zero;
  Vector2 _lastSize = Vector2.zero();

  void trigger() {
    _isActive = true;
    _elapsed = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isActive) return;

    _elapsed += dt;
    if (_elapsed >= _flashDuration) {
      _isActive = false;
      _elapsed = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    final progress = (_elapsed / _flashDuration).clamp(0.0, 1.0);
    final alpha = _maxOpacity * (1.0 - progress);
    if (_lastSize != game.size) {
      _lastSize = game.size.clone();
      _screenRect = Rect.fromLTWH(0, 0, game.size.x, game.size.y);
    }
    _paint.color = Color.fromRGBO(183, 28, 28, alpha);

    canvas.drawRect(_screenRect, _paint);
  }
}
