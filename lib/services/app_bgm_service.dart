import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

bool shouldPlayMenuForRoute(String? routeName) {
  if (routeName == null) return false;

  const allowedRoutes = <String>{
    '/home',
    '/select',
    '/leaderboard',
    '/stats',
    '/achievements',
    '/settings',
  };

  return allowedRoutes.contains(routeName) ||
      routeName.startsWith('/settings/');
}

class AppBgmRouteObserver extends NavigatorObserver {
  void _syncRoute(Route<dynamic>? route) {
    final routeName = _pageRouteName(route);
    if (routeName == null) return;
    AppBgmService.instance.syncForRoute(routeName);
  }

  String? _pageRouteName(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return null;
    return route.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _syncRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _syncRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _syncRoute(newRoute);
  }
}

class AppBgmService {
  AppBgmService._();

  static final AppBgmService instance = AppBgmService._();

  static const String _menuTrack = 'music/menu.mp3';
  static const double _menuVolume = 0.25;
  static const int _fadeSteps = 10;
  static const Duration _fadeStepDuration = Duration(milliseconds: 50);

  bool _initialized = false;
  bool _isProcessing = false;
  bool _shouldPlayMenu = false;
  bool _menuTrackRunning = false;
  double _currentVolume = 0.0;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await FlameAudio.bgm.initialize();
  }

  void syncForRoute(String? routeName) {
    if (!_initialized) return;

    _shouldPlayMenu = shouldPlayMenuForRoute(routeName);
    _pumpTransitionLoop();
  }

  void _pumpTransitionLoop() {
    if (_isProcessing) return;

    _isProcessing = true;
    unawaited(_processDesiredState());
  }

  Future<void> _processDesiredState() async {
    try {
      while (true) {
        if (_shouldPlayMenu) {
          await _playMenuFromStart();
          await _fadeTo(_menuVolume, shouldContinue: () => _shouldPlayMenu);
        } else if (_menuTrackRunning) {
          await _fadeOutAndStop();
        }

        if (_isStableForDesiredState()) {
          break;
        }
      }
    } catch (e) {
      _menuTrackRunning = false;
      _currentVolume = 0.0;
      assert(() {
        debugPrint('[AppBgmService] Failed to update BGM state: $e');
        return true;
      }());
    } finally {
      _isProcessing = false;
      if (!_isStableForDesiredState()) {
        _pumpTransitionLoop();
      }
    }
  }

  bool _isStableForDesiredState() {
    if (_shouldPlayMenu) {
      return _menuTrackRunning && (_currentVolume - _menuVolume).abs() < 0.001;
    }

    return !_menuTrackRunning;
  }

  Future<void> _playMenuFromStart() async {
    if (_menuTrackRunning) return;

    await FlameAudio.bgm.play(_menuTrack, volume: 0.0);
    _menuTrackRunning = true;
    _currentVolume = 0.0;
  }

  Future<void> _fadeOutAndStop() async {
    await _fadeTo(0.0, shouldContinue: () => !_shouldPlayMenu);

    if (_shouldPlayMenu || !_menuTrackRunning) return;

    await FlameAudio.bgm.stop();
    _menuTrackRunning = false;
    _currentVolume = 0.0;
  }

  Future<void> _fadeTo(
    double targetVolume, {
    required bool Function() shouldContinue,
  }) async {
    if (!_menuTrackRunning) return;

    if ((_currentVolume - targetVolume).abs() < 0.001) {
      _currentVolume = targetVolume;
      await FlameAudio.bgm.audioPlayer.setVolume(targetVolume);
      return;
    }

    final stepDelta = (targetVolume - _currentVolume) / _fadeSteps;

    for (var step = 0; step < _fadeSteps; step++) {
      if (!shouldContinue()) return;

      final nextVolume = (_currentVolume + stepDelta)
          .clamp(0.0, _menuVolume)
          .toDouble();
      _currentVolume = step == _fadeSteps - 1 ? targetVolume : nextVolume;
      await FlameAudio.bgm.audioPlayer.setVolume(_currentVolume);

      if (step < _fadeSteps - 1) {
        await Future.delayed(_fadeStepDuration);
      }
    }
  }
}
