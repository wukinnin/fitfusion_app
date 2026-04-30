import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/enums.dart';
import '../fitfusion_game.dart';

enum _CooldownPhase { slideIn, countdown, slideOut }

class CooldownOverlay extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double slideInDuration = 1.0;
  static const double slideOutDuration = 1.0;
  static const double _circleRadius = 52.0;

  final Map<WorkoutType, ui.Image> _exerciseImages = {};
  final Paint _tintPaint = Paint()..color = const Color(0x66000000);
  final Paint _arcPaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;
  final Paint _circlePaint = Paint()
    ..color = const Color(0xFFFFD700)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _imagePaint = Paint();
  final TextPainter _roundPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );
  final TextPainter _captionPainter = TextPainter(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  final TextStyle _roundStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFFDE7),
    fontSize: 48,
    fontWeight: FontWeight.bold,
    shadows: const [
      Shadow(blurRadius: 8, color: Colors.black),
      Shadow(blurRadius: 4, color: Colors.black),
    ],
  );
  final TextStyle _countStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFFDE7),
    fontSize: 80,
    fontWeight: FontWeight.bold,
    shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
  );
  final TextStyle _captionStyle = GoogleFonts.cinzel(
    color: const Color(0xFFFFD700),
    fontSize: 20,
    fontWeight: FontWeight.bold,
    shadows: const [
      Shadow(blurRadius: 8, color: Colors.black),
      Shadow(blurRadius: 4, color: Colors.black),
    ],
  );
  List<TextPainter> _countdownPainters = [];

  _CooldownPhase _phase = _CooldownPhase.slideIn;
  double _phaseTimer = 0;
  int _cooldownSeconds = 15;
  double _countdownRemaining = 15;
  int _nextRound = 1;
  String? _titleOverride;
  String? _caption;
  bool _hideWorkoutImage = false;
  bool _captionAtBottom = false;
  bool _isActive = false;
  bool _roundTextDirty = true;
  double _cachedScreenW = -1;
  double _cachedScreenH = -1;
  Rect _screenRect = Rect.zero;
  Offset _timerCenter = Offset.zero;
  Rect _arcRect = Rect.zero;
  bool _imageLayoutDirty = true;
  ui.Image? _cachedImage;
  Rect _imageSrcRect = Rect.zero;
  Rect _imageDstRect = Rect.zero;

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

  void startCooldown(
    int nextRound, {
    String? title,
    String? caption,
    bool hideWorkoutImage = false,
    bool captionAtBottom = false,
  }) {
    _nextRound = nextRound;
    _titleOverride = title;
    _caption = caption;
    _hideWorkoutImage = hideWorkoutImage;
    _captionAtBottom = captionAtBottom;
    _roundTextDirty = true;
    _imageLayoutDirty = true;
    _phase = _CooldownPhase.slideIn;
    _phaseTimer = 0;
    _cooldownSeconds = game.cooldownSeconds.clamp(2, 30).toInt();
    _ensureCountdownPainters();
    _countdownRemaining = _cooldownSeconds.toDouble();
    _isActive = true;
  }

  void stopCooldown() {
    _isActive = false;
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

    _cooldownSeconds = game.cooldownSeconds.clamp(2, 30).toInt();
    _ensureCountdownPainters();
  }

  void _ensureCountdownPainters() {
    if (_countdownPainters.length == _cooldownSeconds + 1) return;
    _countdownPainters = List.generate(_cooldownSeconds + 1, (seconds) {
      return TextPainter(
        text: TextSpan(text: '$seconds', style: _countStyle),
        textDirection: TextDirection.ltr,
      )..layout();
    });
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
        }
        break;

      case _CooldownPhase.countdown:
        _countdownRemaining -= dt;

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
    _updateLayout(screenW, screenH);

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
    canvas.drawRect(_screenRect, _tintPaint);

    // "ROUND X" header — top area
    if (_roundTextDirty) {
      _roundPainter.text = TextSpan(
        text: _titleOverride ?? 'ROUND $_nextRound',
        style: _roundStyle,
      );
      _roundPainter.layout();
      if (_caption != null && _caption!.isNotEmpty) {
        _captionPainter.text = TextSpan(text: _caption, style: _captionStyle);
        _captionPainter.layout(maxWidth: screenW * 0.82);
      } else {
        _captionPainter.text = const TextSpan(text: '');
        _captionPainter.layout();
      }
      _roundTextDirty = false;
    }
    if (_captionAtBottom) {
      final titleY = screenH * 0.76;
      if (_caption != null && _caption!.isNotEmpty) {
        _captionPainter.paint(
          canvas,
          Offset((screenW - _captionPainter.width) / 2, titleY - 58),
        );
      }
      _roundPainter.paint(
        canvas,
        Offset((screenW - _roundPainter.width) / 2, titleY),
      );
    } else {
      _roundPainter.paint(
        canvas,
        Offset((screenW - _roundPainter.width) / 2, screenH * 0.12),
      );
      if (_caption != null && _caption!.isNotEmpty) {
        _captionPainter.paint(
          canvas,
          Offset((screenW - _captionPainter.width) / 2, screenH * 0.20),
        );
      }
    }

    // Countdown circle — center area
    final centerX = _timerCenter.dx;
    final centerY = _timerCenter.dy;

    // Countdown progress fraction
    final fraction = _countdownRemaining / _cooldownSeconds;

    // Pie-chart countdown
    canvas.drawArc(
      _arcRect,
      -math.pi / 2,
      fraction * 2 * math.pi,
      false,
      _arcPaint,
    );

    // Circle border
    canvas.drawCircle(_timerCenter, _circleRadius, _circlePaint);

    // Countdown number
    final seconds = _countdownRemaining.ceil();
    final countTp =
        _countdownPainters[seconds.clamp(0, _cooldownSeconds).toInt()];
    countTp.paint(
      canvas,
      Offset(centerX - countTp.width / 2, centerY - countTp.height / 2),
    );

    // Exercise illustration — below timer (contain-fit, no stretching)
    final image = _hideWorkoutImage ? null : _exerciseImages[game.workoutType];
    if (image != null) {
      _updateImageLayout(image, screenW, screenH);
      canvas.drawImageRect(image, _imageSrcRect, _imageDstRect, _imagePaint);
    }

    canvas.restore();
  }

  void _updateLayout(double screenW, double screenH) {
    if (_cachedScreenW == screenW && _cachedScreenH == screenH) return;

    _cachedScreenW = screenW;
    _cachedScreenH = screenH;
    _screenRect = Rect.fromLTWH(0, 0, screenW, screenH);
    _timerCenter = Offset(screenW / 2, screenH * 0.35);
    _arcRect = Rect.fromCircle(center: _timerCenter, radius: _circleRadius);
    _imageLayoutDirty = true;
    _roundTextDirty = true;
  }

  void _updateImageLayout(ui.Image image, double screenW, double screenH) {
    if (!_imageLayoutDirty && identical(_cachedImage, image)) return;

    final imageTop = _timerCenter.dy + _circleRadius + 24;
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

    _cachedImage = image;
    _imageSrcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    _imageDstRect = Rect.fromLTWH(
      _timerCenter.dx - drawWidth / 2,
      imageTop,
      drawWidth,
      drawHeight,
    );
    _imageLayoutDirty = false;
  }

  double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
  double _easeInCubic(double t) => t * t * t;
}
