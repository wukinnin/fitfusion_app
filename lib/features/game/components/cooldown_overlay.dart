import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../../../core/enums.dart';
import '../../../services/app_bgm_service.dart';
import '../fitfusion_game.dart';

enum _CooldownPhase { slideIn, countdown, slideOut }

class CooldownOverlay extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double slideInDuration = 1.0;
  static const double slideOutDuration = 1.0;

  final Map<WorkoutType, ui.Image> _exerciseImages = {};

  _CooldownPhase _phase = _CooldownPhase.slideIn;
  double _phaseTimer = 0;
  double _countdownRemaining = kCooldownSeconds.toDouble();
  int? _previousCountdownSecond;
  int _nextRound = 1;
  bool _isActive = false;

  VoidCallback? onCooldownComplete;

  /// Returns the current slide offset (0 = fully visible, negative = sliding in from left,
  /// positive = sliding out to right). Used by the game to move HUD elements in sync.
  double get slideOffsetFraction {
    if (!_isActive) return 0;
    switch (_phase) {
      case _CooldownPhase.slideIn:
        final t = (_phaseTimer / slideInDuration).clamp(0.0, 1.0);
        return -(1 - _easeOutCubic(t));
      case _CooldownPhase.countdown:
        return 0;
      case _CooldownPhase.slideOut:
        final t = (_phaseTimer / slideOutDuration).clamp(0.0, 1.0);
        return _easeInCubic(t);
    }
  }

  void startCooldown(int nextRound) {
    _nextRound = nextRound;
    _phase = _CooldownPhase.slideIn;
    _phaseTimer = 0;
    _countdownRemaining = kCooldownSeconds.toDouble();
    _previousCountdownSecond = kCooldownSeconds;
    _isActive = true;
  }

  void stopCooldown() {
    _isActive = false;
    _previousCountdownSecond = null;
  }

  bool get isActive => _isActive;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _exerciseImages[WorkoutType.squats] = await game.images.load(
      'game/squats.png',
    );
    _exerciseImages[WorkoutType.jumpingJacks] = await game.images.load(
      'game/jumping-jacks.png',
    );
    _exerciseImages[WorkoutType.obliqueCrunches] = await game.images.load(
      'game/side-crunches.png',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isActive) return;

    _phaseTimer += dt;

    switch (_phase) {
      case _CooldownPhase.slideIn:
        if (_phaseTimer >= slideInDuration) {
          _phase = _CooldownPhase.countdown;
          _phaseTimer = 0;
          _previousCountdownSecond = _countdownRemaining.ceil();
        }
        break;

      case _CooldownPhase.countdown:
        final previousSecond =
            _previousCountdownSecond ?? _countdownRemaining.ceil();
        _countdownRemaining -= dt;
        final currentSecond = _countdownRemaining <= 0
            ? 0
            : _countdownRemaining.ceil();

        if (currentSecond < previousSecond) {
          for (
            var crossedSecond = previousSecond - 1;
            crossedSecond >= currentSecond;
            crossedSecond--
          ) {
            if (crossedSecond >= 0 && crossedSecond < kCooldownSeconds) {
              _playTickSafe();
            }
          }
        }

        _previousCountdownSecond = currentSecond;

        if (_countdownRemaining <= 0) {
          _countdownRemaining = 0;
          _phase = _CooldownPhase.slideOut;
          _phaseTimer = 0;
        }
        break;

      case _CooldownPhase.slideOut:
        if (_phaseTimer >= slideOutDuration) {
          _isActive = false;
          onCooldownComplete?.call();
        }
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_isActive) return;

    final screenW = game.size.x;
    final screenH = game.size.y;

    // Calculate slide offset
    double slideOffsetX = 0;
    switch (_phase) {
      case _CooldownPhase.slideIn:
        // Slide from left: starts at -screenW, ends at 0
        final t = (_phaseTimer / slideInDuration).clamp(0.0, 1.0);
        final eased = _easeOutCubic(t);
        slideOffsetX = -screenW * (1 - eased);
        break;
      case _CooldownPhase.countdown:
        slideOffsetX = 0;
        break;
      case _CooldownPhase.slideOut:
        // Slide to right: starts at 0, ends at +screenW
        final t = (_phaseTimer / slideOutDuration).clamp(0.0, 1.0);
        final eased = _easeInCubic(t);
        slideOffsetX = screenW * eased;
        break;
    }

    canvas.save();
    canvas.translate(slideOffsetX, 0);

    // 40% black tint overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, screenW, screenH),
      Paint()..color = const Color(0x66000000),
    );

    // "ROUND X" header — top area
    final roundText = TextSpan(
      text: 'ROUND $_nextRound',
      style: GoogleFonts.cinzel(
        color: const Color(0xFFFFFDE7),
        fontSize: 48,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 8, color: Colors.black),
          Shadow(blurRadius: 4, color: Colors.black),
        ],
      ),
    );
    final roundTp = TextPainter(
      text: roundText,
      textDirection: TextDirection.ltr,
    )..layout();
    roundTp.paint(
      canvas,
      Offset((screenW - roundTp.width) / 2, screenH * 0.12),
    );

    // Countdown circle — center area
    final centerX = screenW / 2;
    final centerY = screenH * 0.35;
    final circleRadius = 52.0;

    // Countdown progress fraction
    final fraction = _countdownRemaining / kCooldownSeconds;

    // Pie-chart countdown
    final arcPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final arcRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: circleRadius,
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      fraction * 2 * math.pi,
      false,
      arcPaint,
    );

    // Circle border
    canvas.drawCircle(
      Offset(centerX, centerY),
      circleRadius,
      Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Countdown number
    final seconds = _countdownRemaining.ceil();
    final countText = TextSpan(
      text: '$seconds',
      style: GoogleFonts.cinzel(
        color: const Color(0xFFFFFDE7),
        fontSize: 80,
        fontWeight: FontWeight.bold,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    );
    final countTp = TextPainter(
      text: countText,
      textDirection: TextDirection.ltr,
    )..layout();
    countTp.paint(
      canvas,
      Offset(centerX - countTp.width / 2, centerY - countTp.height / 2),
    );

    // Exercise illustration — below timer (contain-fit, no stretching)
    final image = _exerciseImages[game.workoutType];
    if (image != null) {
      final imageTop = centerY + circleRadius + 24;
      final maxWidth = math.min(screenW * 0.6, 280.0);
      final maxHeight = math.min(screenH * 0.28, 200.0);

      final imageAspect = image.width / image.height;
      final boxAspect = maxWidth / maxHeight;

      late final double drawWidth;
      late final double drawHeight;
      if (imageAspect > boxAspect) {
        drawWidth = maxWidth;
        drawHeight = maxWidth / imageAspect;
      } else {
        drawHeight = maxHeight;
        drawWidth = maxHeight * imageAspect;
      }

      final dstRect = Rect.fromLTWH(
        centerX - drawWidth / 2,
        imageTop,
        drawWidth,
        drawHeight,
      );
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      canvas.drawImageRect(image, srcRect, dstRect, Paint());
    }

    canvas.restore();
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
  double _easeInCubic(double t) => t * t * t;

  void _playTickSafe() {
    try {
      unawaited(AppBgmService.instance.playSfx('sfx/tick1.mp3'));
    } catch (e) {
      debugPrint('[CooldownOverlay] Audio error: $e');
    }
  }
}
