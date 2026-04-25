import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class MonsterHealthBar extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double barHeight = 22;
  static const double borderWidth = 3;

  double _displayedFraction = 1.0;

  final Paint _bgPaint = Paint()..color = const Color(0xFF1A1A2E);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;
  final Paint _fillPaint = Paint()..color = const Color(0xFFB71C1C);
  double _cachedBarWidth = -1;
  late RRect _bgRRect;

  void setHP(int current, int max) {
    _displayedFraction = max > 0 ? current / max : 0.0;
  }

  @override
  void render(Canvas canvas) {
    final barWidth = game.size.x - 24;
    if (_cachedBarWidth != barWidth) {
      _cachedBarWidth = barWidth;
      _bgRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, barWidth, barHeight),
        const Radius.circular(4),
      );
    }
    canvas.drawRRect(_bgRRect, _bgPaint);

    final fillWidth = barWidth * _displayedFraction.clamp(0.0, 1.0);
    if (fillWidth > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillWidth, barHeight);
      final fillRRect = RRect.fromRectAndRadius(fillRect, const Radius.circular(4));
      canvas.drawRRect(fillRRect, _fillPaint);
    }

    canvas.drawRRect(_bgRRect, _borderPaint);
  }
}
