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
  bool _centerOnPosition = false;
  double _fontScale = 1.0;
  late RRect _bgRect;
  Offset _textOffset = Offset.zero;

  static final TextStyle _baseTextStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFFDE7),
    fontSize: 28,
    fontWeight: FontWeight.bold,
    shadows: const [
      Shadow(blurRadius: 6, color: Colors.black),
      Shadow(blurRadius: 2, color: Colors.black),
    ],
  );

  final Paint _bgPaint = Paint()..color = const Color(0xAA1A1A2E);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
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

  void setCenterOnPosition(bool centerOnPosition) {
    if (_centerOnPosition == centerOnPosition) return;
    _centerOnPosition = centerOnPosition;
    _isDirty = true;
  }

  void setFontScale(double fontScale) {
    if (_fontScale == fontScale) return;
    _fontScale = fontScale;
    _isDirty = true;
  }

  @override
  void render(Canvas canvas) {
    if (_isDirty) {
      _textPainter.text = TextSpan(
        text: _customText ?? '$_reps/ $_required REPS',
        style: _baseTextStyle.copyWith(fontSize: 28 * _fontScale),
      );
      _textPainter.layout();
      final textLeft = _centerOnPosition ? -_textPainter.width / 2 : 0.0;
      _textOffset = Offset(textLeft, 0);
      _bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          textLeft - 8,
          -4,
          _textPainter.width + 16,
          _textPainter.height + 8,
        ),
        const Radius.circular(6),
      );
      _isDirty = false;
    }

    canvas.drawRRect(_bgRect, _bgPaint);
    canvas.drawRRect(_bgRect, _borderPaint);
    _textPainter.paint(canvas, _textOffset);
  }
}
