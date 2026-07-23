import 'package:camera/camera.dart';

/// Owns the single image-stream callback of a [CameraController].
///
/// Camera controllers expose only one image-stream callback. Route transitions,
/// retries, and lifecycle recovery can otherwise leave a controller streaming
/// frames to a screen that is no longer active. This coordinator serializes
/// ownership changes so stale start/stop operations cannot orphan a stream.
class CameraImageStreamCoordinator {
  Future<void> _operation = Future<void>.value();
  CameraController? _claimingController;
  CameraController? _ownedController;
  var _generation = 0;
  var _isDisposed = false;

  bool get ownsImageStream {
    final controller = _ownedController;
    return controller != null &&
        _safeControllerValue(controller)?.isStreamingImages == true;
  }

  CameraController? get ownedController => _ownedController;

  /// Completes when all currently scheduled ownership operations finish.
  Future<void> waitForIdle() => _operation;

  /// Ensures that [controller] streams frames to [onFrame].
  ///
  /// Repeated calls for the same controller are coalesced. If the controller is
  /// already streaming, its previous callback is stopped before this owner is
  /// attached because the camera plugin supports only one callback.
  void ensureStarted({
    required CameraController controller,
    required bool Function() shouldStart,
    required void Function(CameraImage image, CameraController controller)
    onFrame,
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
        onError: onError,
      ),
    );
  }

  /// Stops only the stream owned by this coordinator.
  Future<void> stop() {
    if (_isDisposed) {
      return _operation;
    }
    return _scheduleStop();
  }

  /// Cancels pending claims and releases the owned image stream.
  Future<void> dispose() {
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
    required void Function(CameraImage image, CameraController controller)
    onFrame,
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

      await controller.startImageStream((image) {
        onFrame(image, controller);
      });

      if (!_isCurrentClaim(generation, controller, shouldStart)) {
        await _stopControllerStream(controller);
        return;
      }

      _ownedController = controller;
    } catch (error, stackTrace) {
      await _stopControllerStream(controller);
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
    final controller = _ownedController;
    _ownedController = null;
    if (controller == null) {
      return;
    }
    await _stopControllerStream(controller);
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
