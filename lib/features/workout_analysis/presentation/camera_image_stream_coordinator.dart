import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Processes one camera image without retaining a queue of native buffers.
typedef CameraImageStreamFrameHandler =
    FutureOr<void> Function(CameraImage image, CameraController controller);

typedef CameraImageStreamIntervalReader = Duration Function();

Duration _noMinimumFrameInterval() => Duration.zero;

/// Owns the single image-stream callback of a [CameraController].
///
/// Camera controllers expose only one image-stream callback. Route transitions,
/// retries, and lifecycle recovery can otherwise leave a controller streaming
/// frames to a screen that is no longer active. This coordinator serializes
/// ownership changes so stale start/stop operations cannot orphan a stream.
///
/// The coordinator also applies backpressure at the earliest Dart boundary:
/// only one frame handler can run at a time and frames are never queued while
/// analysis is busy. Holding a "latest" camera image would retain its native
/// buffer and increase the allocation pressure this class is meant to reduce.
class CameraImageStreamCoordinator {
  CameraImageStreamCoordinator({
    this.frameDrainTimeout = const Duration(seconds: 2),
    this.performanceLogInterval = const Duration(seconds: 5),
  }) : assert(frameDrainTimeout > Duration.zero),
       assert(performanceLogInterval > Duration.zero);

  final Duration frameDrainTimeout;
  final Duration performanceLogInterval;

  Future<void> _operation = Future<void>.value();
  Future<void>? _inFlightFrame;
  CameraController? _claimingController;
  CameraController? _ownedController;
  Stopwatch? _streamClock;
  int? _lastForwardedFrameAtMicros;
  _CameraFrameWindow? _frameWindow;
  var _generation = 0;
  var _isAcceptingFrames = false;
  var _isDisposed = false;

  bool get ownsImageStream {
    final controller = _ownedController;
    return controller != null &&
        _safeControllerValue(controller)?.isStreamingImages == true;
  }

  bool get hasInFlightFrame => _inFlightFrame != null;

  CameraController? get ownedController => _ownedController;

  /// Completes when ownership operations and the current frame handler finish.
  Future<void> waitForIdle() async {
    await _operation;
    await _drainInFlightFrame();
  }

  /// Ensures that [controller] streams frames to [onFrame].
  ///
  /// Repeated calls for the same controller are coalesced. If the controller is
  /// already streaming, its previous callback is stopped before this owner is
  /// attached because the camera plugin supports only one callback.
  ///
  /// [minimumFrameInterval] rejects callbacks before invoking [onFrame]. Use a
  /// value no larger than the fastest supported analysis interval so exercise
  /// engines retain their existing cadence. Busy frames are always discarded;
  /// this coordinator intentionally does not retain a pending camera image.
  void ensureStarted({
    required CameraController controller,
    required bool Function() shouldStart,
    required CameraImageStreamFrameHandler onFrame,
    CameraImageStreamIntervalReader minimumFrameInterval =
        _noMinimumFrameInterval,
    String debugLabel = 'camera',
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (_isDisposed || !shouldStart()) {
      return;
    }
    final value = _safeControllerValue(controller);
    if (value == null || !value.isInitialized) {
      return;
    }

    if (identical(_claimingController, controller)) {
      return;
    }

    if (identical(_ownedController, controller) &&
        value.isStreamingImages &&
        _claimingController == null) {
      return;
    }

    final generation = ++_generation;
    _claimingController = controller;
    _operation = _operation.then(
      (_) => _claim(
        generation: generation,
        controller: controller,
        shouldStart: shouldStart,
        onFrame: onFrame,
        minimumFrameInterval: minimumFrameInterval,
        debugLabel: debugLabel,
        onError: onError,
      ),
    );
  }

  /// Stops only the stream owned by this coordinator.
  Future<void> stop() {
    _stopAcceptingFrames();
    if (_isDisposed) {
      return _operation;
    }
    return _scheduleStop();
  }

  /// Cancels pending claims and releases the owned image stream.
  Future<void> dispose() {
    _stopAcceptingFrames();
    if (_isDisposed) {
      return _operation;
    }
    _isDisposed = true;
    return _scheduleStop();
  }

  Future<void> _scheduleStop() {
    _generation += 1;
    _claimingController = null;
    final next = _operation.then((_) => _stopOwnedStream());
    _operation = next;
    return next;
  }

  Future<void> _claim({
    required int generation,
    required CameraController controller,
    required bool Function() shouldStart,
    required CameraImageStreamFrameHandler onFrame,
    required CameraImageStreamIntervalReader minimumFrameInterval,
    required String debugLabel,
    required void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      if (!_isCurrentClaim(generation, controller, shouldStart)) {
        return;
      }

      if (identical(_ownedController, controller) &&
          _safeControllerValue(controller)?.isStreamingImages == true) {
        return;
      }

      await _stopOwnedStream();

      if (!_isCurrentClaim(generation, controller, shouldStart)) {
        return;
      }

      final value = _safeControllerValue(controller);
      if (value == null || !value.isInitialized) {
        return;
      }

      // A controller can survive a route transition while still streaming to
      // the previous screen. Stop that foreign callback before claiming it.
      if (value.isStreamingImages) {
        await controller.stopImageStream();
      }

      if (!_isCurrentClaim(generation, controller, shouldStart)) {
        return;
      }

      _beginAcceptingFrames(debugLabel);
      await controller.startImageStream((image) {
        _dispatchFrame(
          generation: generation,
          image: image,
          controller: controller,
          shouldStart: shouldStart,
          onFrame: onFrame,
          minimumFrameInterval: minimumFrameInterval,
          onError: onError,
        );
      });

      if (!_isCurrentClaim(generation, controller, shouldStart)) {
        _stopAcceptingFrames();
        await _stopControllerStream(controller);
        await _drainInFlightFrame();
        _flushFrameWindow();
        return;
      }

      _ownedController = controller;
    } catch (error, stackTrace) {
      _stopAcceptingFrames();
      await _stopControllerStream(controller);
      await _drainInFlightFrame();
      _flushFrameWindow();
      if (identical(_ownedController, controller)) {
        _ownedController = null;
      }
      _notifyError(onError, error, stackTrace);
    } finally {
      if (identical(_claimingController, controller)) {
        _claimingController = null;
      }
    }
  }

  void _dispatchFrame({
    required int generation,
    required CameraImage image,
    required CameraController controller,
    required bool Function() shouldStart,
    required CameraImageStreamFrameHandler onFrame,
    required CameraImageStreamIntervalReader minimumFrameInterval,
    required void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final window = _frameWindow;
    window?.recordCallback();

    if (!_isAcceptingFrames ||
        generation != _generation ||
        _isDisposed ||
        !shouldStart()) {
      window?.recordInactiveDrop();
      _maybeLogFrameWindow();
      return;
    }

    if (_inFlightFrame != null) {
      window?.recordBusyDrop();
      _maybeLogFrameWindow();
      return;
    }

    final nowMicros = _streamClock?.elapsedMicroseconds ?? 0;
    final lastForwardedAtMicros = _lastForwardedFrameAtMicros;
    final interval = minimumFrameInterval();
    assert(!interval.isNegative, 'minimumFrameInterval must not be negative.');
    if (lastForwardedAtMicros != null &&
        nowMicros - lastForwardedAtMicros < interval.inMicroseconds) {
      window?.recordIntervalDrop();
      _maybeLogFrameWindow();
      return;
    }

    _lastForwardedFrameAtMicros = nowMicros;
    window?.recordForwarded();

    late final Future<void> guardedFrame;
    guardedFrame = Future<void>.sync(() => onFrame(image, controller))
        .catchError((Object error, StackTrace stackTrace) {
          window?.recordHandlerError();
          if (generation == _generation && _isAcceptingFrames && !_isDisposed) {
            _notifyError(onError, error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_inFlightFrame, guardedFrame)) {
            _inFlightFrame = null;
          }
          _maybeLogFrameWindow();
        });
    _inFlightFrame = guardedFrame;
    unawaited(guardedFrame);
    _maybeLogFrameWindow();
  }

  bool _isCurrentClaim(
    int generation,
    CameraController controller,
    bool Function() shouldStart,
  ) {
    return !_isDisposed &&
        generation == _generation &&
        identical(_claimingController, controller) &&
        shouldStart();
  }

  Future<void> _stopOwnedStream() async {
    _stopAcceptingFrames();
    final controller = _ownedController;
    _ownedController = null;
    if (controller != null) {
      await _stopControllerStream(controller);
    }
    await _drainInFlightFrame();
    _flushFrameWindow();
  }

  Future<void> _stopControllerStream(CameraController controller) async {
    try {
      if (_safeControllerValue(controller)?.isStreamingImages == true) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Camera teardown can race with provider disposal or app lifecycle loss.
    }
  }

  Future<void> _drainInFlightFrame() async {
    final frame = _inFlightFrame;
    if (frame == null) {
      return;
    }

    try {
      await frame.timeout(frameDrainTimeout);
    } on TimeoutException {
      if (!kReleaseMode) {
        debugPrint(
          'CameraFrameBackpressure: frame drain exceeded '
          '${frameDrainTimeout.inMilliseconds}ms; teardown will continue.',
        );
      }
    }
  }

  void _beginAcceptingFrames(String debugLabel) {
    _isAcceptingFrames = true;
    _lastForwardedFrameAtMicros = null;
    _streamClock = Stopwatch()..start();
    _frameWindow = _CameraFrameWindow(debugLabel: debugLabel);
  }

  void _stopAcceptingFrames() {
    _isAcceptingFrames = false;
    _lastForwardedFrameAtMicros = null;
  }

  void _maybeLogFrameWindow() {
    if (kReleaseMode) {
      return;
    }
    final window = _frameWindow;
    if (window == null || window.elapsed < performanceLogInterval) {
      return;
    }
    debugPrint(window.summary());
    _frameWindow = window.nextWindow();
  }

  void _flushFrameWindow() {
    if (!kReleaseMode) {
      final window = _frameWindow;
      if (window != null && window.callbackCount > 0) {
        debugPrint(window.summary());
      }
    }
    _frameWindow = null;
    _streamClock?.stop();
    _streamClock = null;
  }

  CameraValue? _safeControllerValue(CameraController controller) {
    try {
      return controller.value;
    } catch (_) {
      return null;
    }
  }

  void _notifyError(
    void Function(Object error, StackTrace stackTrace)? onError,
    Object error,
    StackTrace stackTrace,
  ) {
    if (onError == null) {
      return;
    }
    try {
      onError(error, stackTrace);
    } catch (_) {
      // Error reporting must not break the serialized stream lifecycle.
    }
  }
}

class _CameraFrameWindow {
  _CameraFrameWindow({required this.debugLabel});

  final String debugLabel;
  final Stopwatch _stopwatch = Stopwatch()..start();

  int callbackCount = 0;
  int forwardedCount = 0;
  int busyDropCount = 0;
  int intervalDropCount = 0;
  int inactiveDropCount = 0;
  int handlerErrorCount = 0;

  Duration get elapsed => _stopwatch.elapsed;

  void recordCallback() => callbackCount += 1;
  void recordForwarded() => forwardedCount += 1;
  void recordBusyDrop() => busyDropCount += 1;
  void recordIntervalDrop() => intervalDropCount += 1;
  void recordInactiveDrop() => inactiveDropCount += 1;
  void recordHandlerError() => handlerErrorCount += 1;

  String summary() {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final cameraFps = seconds <= 0 ? 0 : callbackCount / seconds;
    final forwardedFps = seconds <= 0 ? 0 : forwardedCount / seconds;
    return 'CameraFrameBackpressure[$debugLabel]: '
        'callback=$callbackCount '
        'forwarded=$forwardedCount '
        'busyDrop=$busyDropCount '
        'intervalDrop=$intervalDropCount '
        'inactiveDrop=$inactiveDropCount '
        'handlerError=$handlerErrorCount '
        'cameraFps=${cameraFps.toStringAsFixed(1)} '
        'forwardedFps=${forwardedFps.toStringAsFixed(1)}';
  }

  _CameraFrameWindow nextWindow() {
    _stopwatch.stop();
    return _CameraFrameWindow(debugLabel: debugLabel);
  }
}
