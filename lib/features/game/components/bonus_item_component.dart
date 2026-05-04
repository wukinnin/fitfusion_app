import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum BonusItemKind { gem, poison }

class BonusItemComponent extends SpriteComponent {
  static const double itemSize = 92;

  final BonusItemKind kind;
  bool _active = false;

  BonusItemComponent({required this.kind});

  bool get isActive => _active;
  Offset get centerOffset =>
      Offset(position.x + size.x / 2, position.y + size.y / 2);

  Rect get itemRect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  void activateAt(Vector2 nextPosition) {
    final sourceSize = sprite?.srcSize;
    if (sourceSize != null && sourceSize.y > 0) {
      final aspect = sourceSize.x / sourceSize.y;
      size = aspect >= 1
          ? Vector2(itemSize, itemSize / aspect)
          : Vector2(itemSize * aspect, itemSize);
    } else {
      size = Vector2.all(itemSize);
    }
    position = nextPosition;
    _active = true;
  }

  void deactivate() {
    _active = false;
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    super.render(canvas);
  }
}
