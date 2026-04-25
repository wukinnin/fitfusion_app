import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../core/events.dart';
import '../../core/enums.dart';

class PaceMonitor {
  Timer? _paceTimer;
  DateTime? _lastRepTime;
  bool _isActive = false;
  bool _isDisposed = false;
  Future<void>? _disposeFuture;

  final StreamController<PaceEvent> _paceController =
      StreamController<PaceEvent>.broadcast();

  Stream<PaceEvent> get paceStream => _paceController.stream;
  bool get isActive => _isActive;

  /// Call this when the FIRST REP of a round is detected.
  /// This starts the pace timer. Do not call this before the first rep
  /// of a round — the player needs time to get into position.
  void startMonitoring() {
    if (_isDisposed) return;
    if (_isActive) return; // already monitoring
    _isActive = true;
    _lastRepTime = DateTime.now();
    _resetTimer();
    assert(() {
      debugPrint('[PaceMonitor] Started monitoring');
      return true;
    }());
  }

  /// Call this when a round ends (won or lost), during cooldown,
  /// or when the game ends. Stops the timer cleanly without emitting.
  void stopMonitoring() {
    _isActive = false;
    _paceTimer?.cancel();
    _paceTimer = null;
    assert(() {
      debugPrint('[PaceMonitor] Stopped monitoring');
      return true;
    }());
  }

  /// Call this each time a rep is detected (after startMonitoring has been called).
  /// Resets the 3-second window and emits a repOnTime event.
  void onRepReceived() {
    if (_isDisposed) return;
    if (!_isActive) return;

    final now = DateTime.now();
    final intervalSeconds = _lastRepTime != null
        ? now.difference(_lastRepTime!).inMilliseconds / 1000.0
        : 0.0;

    _lastRepTime = now;
    _resetTimer();

    if (!_paceController.isClosed) {
      _paceController.add(
        PaceEvent(
          type: PaceEventType.repOnTime,
          intervalSeconds: intervalSeconds,
          timestamp: now,
        ),
      );
    }
  }

  void _resetTimer() {
    _paceTimer?.cancel();
    _paceTimer = Timer(
      Duration(milliseconds: (kPaceThresholdSeconds * 1000).round()),
      _onPaceViolation,
    );
  }

  void _onPaceViolation() {
    if (_isDisposed) return;
    if (!_isActive) return;

    assert(() {
      debugPrint(
        '[PaceMonitor] PACE VIOLATION — no rep in ${kPaceThresholdSeconds}s',
      );
      return true;
    }());

    if (!_paceController.isClosed) {
      _paceController.add(
        PaceEvent(
          type: PaceEventType.paceFailed,
          intervalSeconds: kPaceThresholdSeconds,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Restart the timer — the player must keep moving.
    // The pace monitor keeps firing until they do a rep
    // or until stopMonitoring() is called.
    _resetTimer();
  }

  Future<void> dispose() async {
    _disposeFuture ??= _disposeInternal();
    await _disposeFuture;
  }

  Future<void> _disposeInternal() async {
    _isDisposed = true;
    stopMonitoring();
    if (!_paceController.isClosed) {
      await _paceController.close();
    }
  }
}
