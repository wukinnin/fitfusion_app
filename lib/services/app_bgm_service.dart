import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool shouldPlayMenuForRoute(String? routeName) {
  if (routeName == null) return false;

  // Menu BGM plays everywhere the player spends time in menus — including
  // the "deeper" auth screens (verify / forgot / reset password). The only
  // screens that should stay silent are the cold-start entry points and
  // the game proper itself.
  const silentRoutes = <String>{
    '/', // Splash
    '/auth', // Welcome / auth landing
    '/auth/login',
    '/auth/signup',
    '/game', // Game proper is BGM-silent; gameplay SFX still play.
    '/results', // Results is fully silent.
  };

  return !silentRoutes.contains(routeName);
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
  static const List<String> _menuAudio = [_menuTrack];
  static const List<String> _gameplayAudio = [
    'sfx/achievement.mp3',
    'sfx/slash.mp3',
    'sfx/thud.mp3',
    'sfx/damage.mp3',
    'sfx/ping.mp3',
    'sfx/poison.mp3',
    'sfx/win_violin.mp3',
    'sfx/victory_orchestra.mp3',
    'sfx/lose_violin.mp3',
  ];
  static const String _volumePreferenceKey = 'global_audio_volume';

  bool _initialized = false;
  bool _isMenuPlaying = false;
  int _syncToken = 0;
  int _gameplayCacheToken = 0;
  String? _currentRouteName;
  double _globalVolume = 1.0;
  bool _gameplayAudioLoaded = false;
  Future<void>? _gameplayAudioLoadFuture;

  double get globalVolume => _globalVolume;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _globalVolume = prefs.getDouble(_volumePreferenceKey) ?? 1.0;
    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll(_menuAudio);
    _queueMenuSync();
  }

  Future<void> setGlobalVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    _globalVolume = clamped;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumePreferenceKey, clamped);

    if (_isMenuPlaying) {
      await FlameAudio.bgm.audioPlayer.setVolume(_globalVolume);
    }
  }

  Future<void> playSfx(String file, {double volume = 1.0}) async {
    final effectiveVolume = (volume * _globalVolume).clamp(0.0, 1.0).toDouble();
    await FlameAudio.play(file, volume: effectiveVolume);
  }

  Future<void> loadGameplayAudio() {
    if (_gameplayAudioLoaded) return Future.value();
    _gameplayAudioLoadFuture ??= _loadGameplayAudioInternal();
    return _gameplayAudioLoadFuture!;
  }

  Future<void> _loadGameplayAudioInternal() async {
    try {
      await FlameAudio.audioCache.loadAll(_gameplayAudio);
      _gameplayAudioLoaded = true;
      if (!_isGameplayAudioRoute(_currentRouteName)) {
        _queueGameplayAudioUnload();
      }
    } catch (e) {
      assert(() {
        debugPrint('[AppBgmService] Failed to load gameplay audio: $e');
        return true;
      }());
    } finally {
      _gameplayAudioLoadFuture = null;
    }
  }

  void _queueGameplayAudioUnload() {
    if (!_gameplayAudioLoaded) return;
    final token = ++_gameplayCacheToken;
    unawaited(_unloadGameplayAudioAfterSettling(token));
  }

  Future<void> _unloadGameplayAudioAfterSettling(int token) async {
    // Let one-shot result sounds finish and avoid fighting quick retry taps.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (token != _gameplayCacheToken) return;
    if (_isGameplayAudioRoute(_currentRouteName)) return;

    try {
      await Future.wait(_gameplayAudio.map(FlameAudio.audioCache.clear));
      _gameplayAudioLoaded = false;
    } catch (e) {
      assert(() {
        debugPrint('[AppBgmService] Failed to unload gameplay audio: $e');
        return true;
      }());
    }
  }

  void syncForRoute(String? routeName) {
    if (!_initialized) return;

    _currentRouteName = routeName;
    if (_isGameplayAudioRoute(routeName)) {
      _gameplayCacheToken++;
      unawaited(loadGameplayAudio());
    } else {
      _queueGameplayAudioUnload();
    }
    _queueMenuSync();
  }

  void _queueMenuSync() {
    final token = ++_syncToken;
    unawaited(_syncMenuMusic(token));
  }

  Future<void> _syncMenuMusic(int token) async {
    try {
      final shouldPlay = shouldPlayMenuForRoute(_currentRouteName);

      if (shouldPlay) {
        if (_isMenuPlaying) {
          await FlameAudio.bgm.audioPlayer.setVolume(_globalVolume);
          return;
        }

        await FlameAudio.bgm.play(_menuTrack, volume: _globalVolume);
        _isMenuPlaying = true;
        if (!_isCurrentSync(token)) {
          _queueMenuSync();
          return;
        }
        return;
      }

      if (_isMenuPlaying) {
        await FlameAudio.bgm.stop();
        _isMenuPlaying = false;
        if (!_isCurrentSync(token)) {
          _queueMenuSync();
          return;
        }
      }
    } catch (e) {
      _isMenuPlaying = false;
      assert(() {
        debugPrint('[AppBgmService] Failed to sync menu music: $e');
        return true;
      }());
    }
  }

  bool _isCurrentSync(int token) => token == _syncToken;

  bool _isGameplayAudioRoute(String? routeName) {
    return routeName == '/game' || routeName == '/results';
  }
}
