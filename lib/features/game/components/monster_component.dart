import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fitfusion_game.dart';

class MonsterComponent extends PositionComponent with HasGameReference<FitFusionGame> {
  static const double displayWidth = 96;
  static const double displayHeight = 144;
  static const List<String> _monsterFiles = [
    'monsters/monster_01.png',
    'monsters/monster_02.png',
    'monsters/monster_03.png',
    'monsters/monster_04.png',
    'monsters/monster_05.png',
    'monsters/monster_06.png',
    'monsters/monster_07.png',
    'monsters/monster_08.png',
    'monsters/monster_09.png',
    'monsters/monster_10.png',
  ];

  late final List<int> _shuffledOrder;
  int _monsterIndex = 0;
  SpriteComponent? _spriteComp;

  // White flash overlay for hit animation
  final _flashPaint = Paint()
    ..color = Colors.white
    ..blendMode = BlendMode.srcATop;
  bool _isFlashing = false;
  double _flashTimer = 0;
  static const double _flashDuration = 0.12;

  @override
  Future<void> onLoad() async {
    size = Vector2(displayWidth, displayHeight);

    // Shuffle monster order — no repetition linearly
    _shuffledOrder = List.generate(_monsterFiles.length, (i) => i);
    _shuffledOrder.shuffle(Random());
    _monsterIndex = 0;

    await _loadCurrentMonster();
  }

  Future<void> _loadCurrentMonster() async {
    _spriteComp?.removeFromParent();

    final fileName = _monsterFiles[_shuffledOrder[_monsterIndex % _monsterFiles.length]];
    final sprite = await game.loadSprite(fileName);

    _spriteComp = SpriteComponent(
      sprite: sprite,
      size: Vector2(displayWidth, displayHeight),
    );
    add(_spriteComp!);
  }

  void nextMonster() {
    _monsterIndex++;
    _loadCurrentMonster();
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
