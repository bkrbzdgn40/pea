import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

typedef CameraFocusTimerFactory =
    Timer Function(Duration duration, void Function() callback);

Timer _defaultCameraFocusTimerFactory(
  Duration duration,
  void Function() callback,
) {
  return Timer(duration, callback);
}

/// Keeps workout-camera focus predictable across preparation, analysis, and
/// lifecycle recovery without making focus support a hard camera requirement.
///
/// Preparation leaves autofocus enabled while the athlete moves into place.
/// Once the athlete is stable, analysis can lock the current lens position so
/// passive continuous autofocus does not hunt during movement. Unsupported
/// focus controls degrade silently to the camera plugin's default behavior.
class CameraFocusStabilizer {
  CameraFocusStabilizer({
    this.debugLabel = 'camera',
    CameraFocusTimerFactory timerFactory = _defaultCameraFocusTimerFactory,
  }) : _timerFactory = timerFactory;

  final String debugLabel;
  final CameraFocusTimerFactory _timerFactory;

  CameraController? _requestedController;
  FocusMode? _requestedMode;
  Duration? _requestedSettleDuration;
  Future<bool>? _requestedOperation;
  Future<void> _operation = Future<void>.value();
  Timer? _settleTimer;
  Completer<void>? _settleCompleter;
  int _generation = 0;
  bool _isDisposed = false;

  Future<bool> useAuto(CameraController controller) {
    return _request(
      controller: controller,
      mode: FocusMode.auto,
      settleDuration: Duration.zero,
    );
  }

  Future<bool> lockForAnalysis(
    CameraController controller, {
    Duration settleDuration = Duration.zero,
  }) {
    assert(!settleDuration.isNegative);
    return _request(
      controller: controller,
      mode: FocusMode.locked,
      settleDuration: settleDuration,
    );
  }

  void cancelPending() {
    _generation += 1;
    _cancelSettleDelay();
    _requestedController = null;
    _requestedMode = null;
    _requestedSettleDuration = null;
    _requestedOperation = null;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    cancelPending();
  }

  Future<bool> _request({
    required CameraController controller,
    required FocusMode mode,
    required Duration settleDuration,
  }) {
    if (_isDisposed) {
      return Future<bool>.value(false);
    }

    final existing = _requestedOperation;
    if (identical(_requestedController, controller) &&
        _requestedMode == mode &&
        _requestedSettleDuration == settleDuration &&
        existing != null) {
      return existing;
    }

    _cancelSettleDelay();
    final generation = ++_generation;
    _requestedController = controller;
    _requestedMode = mode;
    _requestedSettleDuration = settleDuration;

    late final Future<bool> next;
    next = _operation.then(
      (_) => _apply(
        generation: generation,
        controller: controller,
        mode: mode,
        settleDuration: settleDuration,
      ),
    );
    _requestedOperation = next;
    _operation = next.then<void>((_) {});
    return next;
  }

  Future<bool> _apply({
    required int generation,
    required CameraController controller,
    required FocusMode mode,
    required Duration settleDuration,
  }) async {
    if (!_isCurrent(generation, controller)) {
      return false;
    }

    if (settleDuration > Duration.zero) {
      await _waitForSettle(settleDuration);
      if (!_isCurrent(generation, controller)) {
        return false;
      }
    }

    final value = _safeControllerValue(controller);
    if (value == null || !value.isInitialized) {
      return false;
    }
    if (value.focusMode == mode) {
      return true;
    }

    try {
      await controller.setFocusMode(mode);
      if (!_isCurrent(generation, controller)) {
        return false;
      }
      if (!kReleaseMode) {
        debugPrint('CameraFocus[$debugLabel]: mode=${mode.name}');
      }
      return true;
    } on CameraException catch (error) {
      _logFailure(mode, error);
      return false;
    } catch (error) {
      _logFailure(mode, error);
      return false;
    }
  }

  Future<void> _waitForSettle(Duration duration) {
    final completer = Completer<void>();
    _settleCompleter = completer;
    _settleTimer = _timerFactory(duration, () {
      if (identical(_settleCompleter, completer)) {
        _settleTimer = null;
        _settleCompleter = null;
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  void _cancelSettleDelay() {
    _settleTimer?.cancel();
    _settleTimer = null;

    final completer = _settleCompleter;
    _settleCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  bool _isCurrent(int generation, CameraController controller) {
    return !_isDisposed &&
        generation == _generation &&
        identical(_requestedController, controller);
  }

  CameraValue? _safeControllerValue(CameraController controller) {
    try {
      return controller.value;
    } catch (_) {
      return null;
    }
  }

  void _logFailure(FocusMode mode, Object error) {
    if (!kReleaseMode) {
      debugPrint(
        'CameraFocus[$debugLabel]: mode=${mode.name} unsupported or failed: '
        '$error',
      );
    }
  }
}
