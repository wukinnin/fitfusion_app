import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fitfusion_game.dart';

class RoundBanner extends PositionComponent
    with HasGameReference<FitFusionGame> {
  int _round = 1;
  String? _customRoundLabel;
  String _workoutLabel = '';
  bool _roundDirty = true;
  bool _workoutDirty = true;

  final TextPainter _roundPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  final TextPainter _workoutPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  final TextStyle _roundStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFD700),
    fontSize: 22,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
  );
  final TextStyle _workoutStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFD700),
    fontSize: 16,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
  );

  void setRound(int round) {
    if (_round == round && _customRoundLabel == null) return;
    _round = round;
    _customRoundLabel = null;
    _roundDirty = true;
  }

  void setCustomRoundLabel(String label) {
    if (_customRoundLabel == label) return;
    _customRoundLabel = label;
    _roundDirty = true;
  }

  void setWorkoutLabel(String label) {
    if (_workoutLabel == label) return;
    _workoutLabel = label;
    _workoutDirty = true;
  }

  @override
  void render(Canvas canvas) {
    final screenW = game.size.x;

    if (_roundDirty) {
      _roundPainter.text = TextSpan(
        text: _customRoundLabel ?? 'ROUND $_round',
        style: _roundStyle,
      );
      _roundPainter.layout();
      _roundDirty = false;
    }

    if (_workoutDirty) {
      _workoutPainter.text = TextSpan(
        text: _workoutLabel,
        style: _workoutStyle,
      );
      _workoutPainter.layout();
      _workoutDirty = false;
    }

    _roundPainter.paint(
      canvas,
      Offset((screenW - _roundPainter.width) / 2 - position.x, 0),
    );
    _workoutPainter.paint(
      canvas,
      Offset(
        (screenW - _workoutPainter.width) / 2 - position.x,
        _roundPainter.height + 4,
      ),
    );
  }
}
