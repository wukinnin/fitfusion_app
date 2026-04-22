import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class FitFusionAnimatedBackground extends StatefulWidget {
  final Widget child;
  final int circleCount;

  const FitFusionAnimatedBackground({
    super.key,
    required this.child,
    this.circleCount = 15,
  });

  @override
  State<FitFusionAnimatedBackground> createState() =>
      _FitFusionAnimatedBackgroundState();
}

class _FitFusionAnimatedBackgroundState
    extends State<FitFusionAnimatedBackground>
    with SingleTickerProviderStateMixin {
  static const double _travelDistance = 1000;
  static const Color _baseColor = Color.fromARGB(130, 255, 255, 255);

  late final AnimationController _controller;
  late final List<_CircleSpec> _circles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _circles = _generateCircles(widget.circleCount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_CircleSpec> _generateCircles(int count) {
    final random = math.Random(428);
    return List.generate(count, (_) {
      return _CircleSpec(
        size: random.nextDouble() * 150 + 300,
        leftFactor: random.nextDouble(),
        topFactor: random.nextDouble(),
        durationSeconds: random.nextDouble() * 20 + 10,
        delaySeconds: random.nextDouble() * 5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(color: AppTheme.bloodRed)),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final elapsedSeconds =
                    _controller.duration!.inMilliseconds *
                    _controller.value /
                    1000.0;
                return CustomPaint(
                  painter: _FloatingCirclesPainter(
                    circles: _circles,
                    elapsedSeconds: elapsedSeconds,
                  ),
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _FloatingCirclesPainter extends CustomPainter {
  final List<_CircleSpec> circles;
  final double elapsedSeconds;

  const _FloatingCirclesPainter({
    required this.circles,
    required this.elapsedSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final circle in circles) {
      final progress = _animationProgress(circle);
      final center = Offset(
        circle.leftFactor * size.width,
        circle.topFactor * size.height -
            _FitFusionAnimatedBackgroundState._travelDistance * progress,
      );

      final gradient = RadialGradient(
        colors: [
          _FitFusionAnimatedBackgroundState._baseColor.withValues(
            alpha: 0.10 * (1 - progress),
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7],
      );

      final rect = Rect.fromCircle(center: center, radius: circle.size / 2);

      final paint = Paint()..shader = gradient.createShader(rect);
      canvas.drawCircle(center, circle.size / 2, paint);
    }
  }

  double _animationProgress(_CircleSpec circle) {
    final startedAt = elapsedSeconds - circle.delaySeconds;
    if (startedAt <= 0) return 0;
    return (startedAt % circle.durationSeconds) / circle.durationSeconds;
  }

  @override
  bool shouldRepaint(covariant _FloatingCirclesPainter oldDelegate) {
    return oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.circles != circles;
  }
}

class _CircleSpec {
  final double size;
  final double leftFactor;
  final double topFactor;
  final double durationSeconds;
  final double delaySeconds;

  const _CircleSpec({
    required this.size,
    required this.leftFactor,
    required this.topFactor,
    required this.durationSeconds,
    required this.delaySeconds,
  });
}
