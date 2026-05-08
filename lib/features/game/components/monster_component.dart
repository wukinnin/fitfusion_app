import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class MonsterComponent extends PositionComponent
    with HasGameReference<FitFusionGame> {
  static const double layoutWidth = 96;
  static const double displayWidth = 231.84;
  static const double displayHeight = 206.08;
  static const double frameWidth = 144;
  static const double frameHeight = 128;
  static const String dragonFile =
      'game/flying_twin_headed_dragon-red-spritesheet-144x128.png';
  static const List<String> monsterFiles = [dragonFile];

  late final SpriteAnimationComponent _dragon;

  // White flash overlay for hit animation
  final _flashPaint = Paint()
    ..color = Colors.white
    ..blendMode = BlendMode.srcATop;
  bool _isFlashing = false;
  double _flashTimer = 0;
  double _baseScale = 1.0;
  double _lifeStealScale = 1.0;
  static const double _flashDuration = 0.12;

  double get visualWidth => displayWidth * scale.x;
  double get visualHeight => displayHeight * scale.y;

  @override
  Future<void> onLoad() async {
    size = Vector2(displayWidth, displayHeight);

    final image = await game.images.load(dragonFile);
    _dragon = SpriteAnimationComponent(
      animation: SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.12,
          textureSize: Vector2(frameWidth, frameHeight),
        ),
      ),
      size: size,
    );
    add(_dragon);
  }

  void nextMonster() {}

  void setBaseScale(double multiplier) {
    if (_baseScale == multiplier) return;
    _baseScale = multiplier;
    _applyScale();
  }

  void setLifeStealScale(double multiplier) {
    if (_lifeStealScale == multiplier) return;
    _lifeStealScale = multiplier;
    _applyScale();
  }

  void _applyScale() {
    scale = Vector2.all(_baseScale * _lifeStealScale);
  }

  void flashHit() {
    _isFlashing = true;
    _flashTimer = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isFlashing) {
      _flashTimer += dt;
      if (_flashTimer >= _flashDuration) {
        _isFlashing = false;
        _flashTimer = 0;
      }
    }
  }

  @override
  void renderTree(Canvas canvas) {
    if (game.isBonusMode) return;
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // White silhouette flash overlay (Zelda II style)
    if (_isFlashing) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, displayWidth, displayHeight),
        _flashPaint,
      );
    }
  }
}
