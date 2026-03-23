import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fitfusion_game.dart';

class RepProgressBar extends PositionComponent with HasGameReference<FitFusionGame> {
  int _reps = 0;
  int _required = 1;

  void setProgress(int reps, int required) {
    _reps = reps;
    _required = required;
  }

  @override
  void render(Canvas canvas) {
    final textSpan = TextSpan(
      text: '$_reps/ $_required REPS',
      style: GoogleFonts.cinzel(
        color: const Color(0xFFFFFDE7),
        fontSize: 28,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 6, color: Colors.black),
          Shadow(blurRadius: 2, color: Colors.black),
        ],
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-8, -4, tp.width + 16, tp.height + 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = const Color(0xAA1A1A2E),
    );
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    tp.paint(canvas, Offset.zero);
  }
}
