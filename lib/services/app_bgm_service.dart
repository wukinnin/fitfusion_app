import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _BgmTrack { none, menu, game }

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
  static const String _gameTrack = 'music/game.mp3';
  static const double _bgmVolume = 0.40;
  static const String _volumePreferenceKey = 'global_audio_volume';
  static const int _fadeSteps = 10;
  static const Duration _fadeStepDuration = Duration(milliseconds: 50);

  bool _initialized = false;
  bool _isProcessing = false;
  int _transitionToken = 0;
  String? _currentRouteName;
  bool _gameplayRequested = false;
  _BgmTrack _activeTrack = _BgmTrack.none;
  double _currentVolume = 0.0;
  double _globalVolume = 1.0;

  double get globalVolume => _globalVolume;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _globalVolume = prefs.getDouble(_volumePreferenceKey) ?? 1.0;
    await FlameAudio.bgm.initialize();
  }

  Future<void> setGlobalVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    _globalVolume = clamped;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumePreferenceKey, clamped);

    if (_activeTrack != _BgmTrack.none) {
      _transitionToken++;
      _pumpTransitionLoop();
    }
  }

  Future<void> playSfx(String file, {double volume = 1.0}) async {
    final effectiveVolume = (volume * _globalVolume).clamp(0.0, 1.0).toDouble();
    await FlameAudio.play(file, volume: effectiveVolume);
  }

  void syncForRoute(String? routeName) {
    if (!_initialized) return;

    _currentRouteName = routeName;

    if (routeName != '/game') {
      _gameplayRequested = false;
    }

    _transitionToken++;
    _pumpTransitionLoop();
  }

  void startGameplayBgm() {
    if (!_initialized) return;

    _gameplayRequested = true;
    _transitionToken++;
    _pumpTransitionLoop();
  }

  void stopGameplayBgm() {
    if (!_initialized) return;

    _gameplayRequested = false;
    _transitionToken++;
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
        final token = _transitionToken;
        final desiredTrack = _desiredTrack();

        if (desiredTrack == _BgmTrack.none) {
          if (_activeTrack == _BgmTrack.none) break;
          await _fadeOutAndStop(token);
        } else if (_activeTrack != desiredTrack) {
          if (_activeTrack != _BgmTrack.none) {
            await _fadeOutAndStop(token);
            if (!_isCurrentToken(token)) {
              continue;
            }
          }

          await _playTrackFromStart(desiredTrack);
          if (!_isCurrentToken(token)) {
            continue;
          }

          await _fadeTo(
            _targetVolumeForTrack(desiredTrack),
            maxVolume: _targetVolumeForTrack(desiredTrack),
            token: token,
          );
        } else {
          await _fadeTo(
            _targetVolumeForTrack(desiredTrack),
            maxVolume: _targetVolumeForTrack(desiredTrack),
            token: token,
          );
        }

        if (token == _transitionToken && _isStableForDesiredState()) {
          break;
        }
      }
    } catch (e) {
      _activeTrack = _BgmTrack.none;
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
    final desiredTrack = _desiredTrack();

    if (desiredTrack == _BgmTrack.none) {
      return _activeTrack == _BgmTrack.none;
    }

    return _activeTrack == desiredTrack &&
        (_currentVolume - _targetVolumeForTrack(desiredTrack)).abs() < 0.001;
  }

  _BgmTrack _desiredTrack() {
    if (_gameplayRequested && _currentRouteName == '/game') {
      return _BgmTrack.game;
    }

    if (shouldPlayMenuForRoute(_currentRouteName)) {
      return _BgmTrack.menu;
    }

    return _BgmTrack.none;
  }

  double _targetVolumeForTrack(_BgmTrack track) {
    if (track == _BgmTrack.none) return 0.0;
    return _bgmVolume * _globalVolume;
  }

  String _fileForTrack(_BgmTrack track) {
    switch (track) {
      case _BgmTrack.none:
        throw StateError('No audio file exists for the none track.');
      case _BgmTrack.menu:
        return _menuTrack;
      case _BgmTrack.game:
        return _gameTrack;
    }
  }

  bool _isCurrentToken(int token) => token == _transitionToken;

  Future<void> _playTrackFromStart(_BgmTrack track) async {
    if (track == _BgmTrack.none) return;

    await FlameAudio.bgm.play(_fileForTrack(track), volume: 0.0);
    _activeTrack = track;
    _currentVolume = 0.0;
  }

  Future<void> _fadeOutAndStop(int token) async {
    await _fadeTo(
      0.0,
      maxVolume: _targetVolumeForTrack(_activeTrack),
      token: token,
    );

    if (!_isCurrentToken(token) || _currentVolume > 0.001) return;

    await FlameAudio.bgm.stop();
    _activeTrack = _BgmTrack.none;
    _currentVolume = 0.0;
  }

  Future<void> _fadeTo(
    double targetVolume, {
    required double maxVolume,
    required int token,
  }) async {
    if (_activeTrack == _BgmTrack.none) return;

    if ((_currentVolume - targetVolume).abs() < 0.001) {
      _currentVolume = targetVolume;
      await FlameAudio.bgm.audioPlayer.setVolume(targetVolume);
      return;
    }

    final stepDelta = (targetVolume - _currentVolume) / _fadeSteps;

    for (var step = 0; step < _fadeSteps; step++) {
      if (!_isCurrentToken(token)) return;

      final nextVolume = (_currentVolume + stepDelta)
          .clamp(0.0, maxVolume)
          .toDouble();
      _currentVolume = step == _fadeSteps - 1 ? targetVolume : nextVolume;
      await FlameAudio.bgm.audioPlayer.setVolume(_currentVolume);

      if (step < _fadeSteps - 1) {
        await Future.delayed(_fadeStepDuration);
      }
    }
  }
}
