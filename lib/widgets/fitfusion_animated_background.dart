import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

class FitFusionAnimatedBackground extends StatefulWidget {
  final Widget child;
  final int circleCount;

  const FitFusionAnimatedBackground({
    super.key,
    required this.child,
    this.circleCount = 8,
  });

  @override
  State<FitFusionAnimatedBackground> createState() =>
      _FitFusionAnimatedBackgroundState();
}

class _FitFusionAnimatedBackgroundState
    extends State<FitFusionAnimatedBackground> {
  static const double _travelDistance = 1000;
  static const Color _baseColor = Color.fromARGB(130, 255, 255, 255);
  static const Duration _frameInterval = Duration(milliseconds: 83);

  final Stopwatch _stopwatch = Stopwatch();
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier<double>(0);
  Timer? _timer;
  late final List<_CircleSpec> _circles;

  @override
  void initState() {
    super.initState();
    _circles = _generateCircles(widget.circleCount);
    _stopwatch.start();
    _timer = Timer.periodic(_frameInterval, (_) {
      _elapsedSeconds.value =
          _stopwatch.elapsedMicroseconds / Duration.microsecondsPerSecond;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _elapsedSeconds.dispose();
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
          child: RepaintBoundary(
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _elapsedSeconds,
                builder: (context, elapsedSeconds, _) {
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
        ),
        RepaintBoundary(child: widget.child),
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
    final paint = Paint();
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

      paint.shader = gradient.createShader(rect);
      canvas.drawCircle(center, circle.size / 2, paint);
    }
    paint.shader = null;
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
