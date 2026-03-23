import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fitfusion_game.dart';

class RoundBanner extends PositionComponent with HasGameReference<FitFusionGame> {
  int _round = 1;
  String _workoutLabel = '';

  void setRound(int round) {
    _round = round;
  }

  void setWorkoutLabel(String label) {
    _workoutLabel = label;
  }

  @override
  void render(Canvas canvas) {
    final screenW = game.size.x;

    // Round number — centered
    final roundSpan = TextSpan(
      text: 'ROUND $_round',
      style: GoogleFonts.cinzel(
        color: const Color(0xFFFFD700),
        fontSize: 22,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    final roundTp = TextPainter(
      text: roundSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    roundTp.paint(canvas, Offset((screenW - roundTp.width) / 2 - position.x, 0));

    // Workout label — centered below round
    final workoutSpan = TextSpan(
      text: _workoutLabel,
      style: GoogleFonts.cinzel(
        color: const Color(0xFFFFD700),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
      ),
    );
    final workoutTp = TextPainter(
      text: workoutSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    workoutTp.paint(canvas, Offset((screenW - workoutTp.width) / 2 - position.x, roundTp.height + 4));
  }
}
