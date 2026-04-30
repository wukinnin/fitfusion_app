import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fitfusion_game.dart';

class RepProgressBar extends PositionComponent
    with HasGameReference<FitFusionGame> {
  int _reps = 0;
  int _required = 1;
  String? _customText;
  bool _isDirty = true;
  late RRect _bgRect;

  final Paint _bgPaint = Paint()..color = const Color(0xAA1A1A2E);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  final TextStyle _textStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFFDE7),
    fontSize: 28,
    fontWeight: FontWeight.bold,
    shadows: const [
      Shadow(blurRadius: 6, color: Colors.black),
      Shadow(blurRadius: 2, color: Colors.black),
    ],
  );

  void setProgress(int reps, int required) {
    if (_reps == reps && _required == required && _customText == null) return;
    _reps = reps;
    _required = required;
    _customText = null;
    _isDirty = true;
  }

  void setCustomText(String text) {
    if (_customText == text) return;
    _customText = text;
    _isDirty = true;
  }

  @override
  void render(Canvas canvas) {
    if (_isDirty) {
      _textPainter.text = TextSpan(
        text: _customText ?? '$_reps/ $_required REPS',
        style: _textStyle,
      );
      _textPainter.layout();
      _bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(-8, -4, _textPainter.width + 16, _textPainter.height + 8),
        const Radius.circular(6),
      );
      _isDirty = false;
    }

    canvas.drawRRect(_bgRect, _bgPaint);
    canvas.drawRRect(_bgRect, _borderPaint);
    _textPainter.paint(canvas, Offset.zero);
  }
}
