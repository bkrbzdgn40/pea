import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../application/workout_session_lifecycle_controller.dart';
import '../camera_focus_stabilizer.dart';
import '../camera_image_stream_coordinator.dart';
import '../providers/active_analysis_exercise_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/live_pause_controller.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/workout_controller.dart';

/// Owns the live route's camera stream, recovery, and geometry lifecycle.
///
/// The controller deliberately does not own navigation or workout-plan state.
/// Those decisions are supplied through narrow callbacks so camera ownership
/// stays centralized and route rendering remains side-effect free.
class LiveCameraSessionController {
  LiveCameraSessionController({
    required WidgetRef ref,
    required bool Function() isMounted,
    required VoidCallback notifyStateChanged,
    required bool Function() hasAnalysisSelection,
    required bool Function() isPlanTransitionLocked,
    required WorkoutSessionLifecycleOwner? Function() sessionLifecycle,
    required Future<void> Function(bool enable) setScreenAwake,
    required VoidCallback onPermissionRequired,
    CameraFocusStabilizer? cameraFocusStabilizer,
    CameraImageStreamCoordinator? imageStreamCoordinator,
  }) : _ref = ref,
       _isMounted = isMounted,
       _notifyStateChanged = notifyStateChanged,
       _hasAnalysisSelection = hasAnalysisSelection,
       _isPlanTransitionLocked = isPlanTransitionLocked,
       _sessionLifecycle = sessionLifecycle,
       _setScreenAwake = setScreenAwake,
       _onPermissionRequired = onPermissionRequired,
       _cameraFocusStabilizer =
           cameraFocusStabilizer ??
           CameraFocusStabilizer(debugLabel: 'live-analysis'),
       _imageStreamCoordinator =
           imageStreamCoordinator ?? CameraImageStreamCoordinator();

  final WidgetRef _ref;
  final bool Function() _isMounted;
  final VoidCallback _notifyStateChanged;
  final bool Function() _hasAnalysisSelection;
  final bool Function() _isPlanTransitionLocked;
  final WorkoutSessionLifecycleOwner? Function() _sessionLifecycle;
  final Future<void> Function(bool enable) _setScreenAwake;
  final VoidCallback _onPermissionRequired;
  final CameraFocusStabilizer _cameraFocusStabilizer;
  final CameraImageStreamCoordinator _imageStreamCoordinator;

  ProviderSubscription<AsyncValue<CameraController>>? _cameraSubscription;
  Timer? _recoveryTimer;
  CameraController? _latestCameraController;
  CameraController? _observedCameraController;
  DeviceOrientation? _observedDeviceOrientation;
  Size? _observedPreviewSize;
  DeviceOrientation _displayDeviceOrientation = DeviceOrientation.portraitUp;
  bool _isRecoveringCamera = false;
  bool _isRecoveringCameraRefreshInFlight = false;
  bool _ensureStartScheduled = false;
  bool _isDisposed = false;

  bool get isRecovering => _isRecoveringCamera;

  DeviceOrientation get displayDeviceOrientation => _displayDeviceOrientation;

  void start() {
    if (_isDisposed || _cameraSubscription != null) {
      return;
    }

    _cameraSubscription = _ref.listenManual<AsyncValue<CameraController>>(
      cameraProvider,
      (_, next) {
        next.whenData((controller) {
          _latestCameraController = controller;
          unawaited(
            _cameraFocusStabilizer.lockForAnalysis(
              controller,
              settleDuration: const Duration(milliseconds: 900),
            ),
          );
          _scheduleEnsureLatestStream();
        });
      },
      fireImmediately: true,
    );
  }

  void updateDisplayDeviceOrientation(DeviceOrientation orientation) {
    _displayDeviceOrientation = orientation;
  }

  void onSessionLifecycleChanged() {
    _scheduleEnsureLatestStream();
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (_sessionLifecycle()?.isFinishing ?? false) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _ref
          .read(workoutControllerProvider.notifier)
          .handleLifecycleInterruption(reason: 'app lifecycle pause');
      _ref
          .read(livePauseControllerProvider.notifier)
          .handleLifecycleInterruption();
      unawaited(_setScreenAwake(false));
      markRecovering();
      _cameraFocusStabilizer.cancelPending();
      await stopImageStream();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_hasAnalysisSelection()) {
        unawaited(_setScreenAwake(true));
      }
      await recoverIfAllowed();
    }
  }

  Future<void> recoverIfAllowed() async {
    final sessionLifecycle = _sessionLifecycle();
    if ((sessionLifecycle?.isFinishing ?? false) ||
        _isRecoveringCameraRefreshInFlight) {
      return;
    }
    if (_isRecoveringCamera && _ref.read(cameraProvider).isLoading) {
      return;
    }
    if (!_hasAnalysisSelection()) {
      return;
    }

    _isRecoveringCameraRefreshInFlight = true;
    markRecovering();

    try {
      final status = await Permission.camera.status;
      if (!_isMounted() || (sessionLifecycle?.isFinishing ?? false)) {
        return;
      }

      if (!status.isGranted) {
        await stopImageStream();
        if (!_isMounted() || (sessionLifecycle?.isFinishing ?? false)) {
          return;
        }

        _ref.invalidate(cameraProvider);
        _onPermissionRequired();
        return;
      }

      await stopImageStream();
      if (!_isMounted() || (sessionLifecycle?.isFinishing ?? false)) {
        return;
      }

      _ref.invalidate(cameraProvider);
    } finally {
      _isRecoveringCameraRefreshInFlight = false;
    }
  }

  void markRecovering() {
    if (!_isMounted()) {
      return;
    }

    _stopObservingCameraGeometry();
    if (!_isRecoveringCamera) {
      _isRecoveringCamera = true;
      _notifyStateChanged();
    }

    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(seconds: 3), () {
      if (!_isMounted() || !_isRecoveringCamera) {
        return;
      }
      _isRecoveringCamera = false;
      _notifyStateChanged();
      _scheduleEnsureLatestStream();
    });
  }

  CameraValue? safeControllerValue(CameraController controller) {
    try {
      return controller.value;
    } catch (_) {
      return null;
    }
  }

  void ensureLatestStream() {
    _scheduleEnsureLatestStream();
  }

  Future<void> stopImageStream() {
    return _imageStreamCoordinator.stop();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _cameraSubscription?.close();
    _cameraSubscription = null;
    _recoveryTimer?.cancel();
    _cameraFocusStabilizer.cancelPending();
    _stopObservingCameraGeometry();
    unawaited(_setScreenAwake(false));
    await _imageStreamCoordinator.dispose();
    _cameraFocusStabilizer.dispose();
  }

  void _scheduleEnsureLatestStream() {
    if (_isDisposed || _ensureStartScheduled) {
      return;
    }
    _ensureStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureStartScheduled = false;
      if (_isDisposed || !_isMounted()) {
        return;
      }
      final controller = _latestCameraController;
      if (controller == null) {
        return;
      }
      _ensureImageStream(controller);
    });
  }

  void _ensureImageStream(CameraController controller) {
    _observeCameraGeometry(controller);
    _imageStreamCoordinator.ensureStarted(
      controller: controller,
      shouldStart: _shouldStartImageStream,
      minimumFrameInterval: () =>
          _ref.read(activeAnalysisFrameIntervalProvider),
      debugLabel: 'live-analysis',
      onFrame: (image, streamController) async {
        if (!_isMounted() || _isPlanTransitionLocked()) {
          return;
        }
        if (_ref.read(livePauseControllerProvider).isActive) {
          await _ref
              .read(workoutControllerProvider.notifier)
              .processCameraImage(
                image,
                streamController.description.sensorOrientation,
                cameraLensDirection: streamController.description.lensDirection,
                deviceOrientation: _displayDeviceOrientation,
              );
          return;
        }

        await _ref
            .read(preparationCameraControllerProvider.notifier)
            .processCameraImage(
              image,
              streamController.description.sensorOrientation,
              lensDirection: streamController.description.lensDirection,
              deviceOrientation: _displayDeviceOrientation,
            );
      },
      onError: (_, _) => _markRecoveringAfterFrame(),
    );
  }

  bool _shouldStartImageStream() {
    final cameraState = _ref.read(cameraProvider);
    final activeController = cameraState.asData?.value;
    return !_isDisposed &&
        _isMounted() &&
        !_isRecoveringCamera &&
        !_isPlanTransitionLocked() &&
        !cameraState.isLoading &&
        identical(activeController, _latestCameraController) &&
        !(_sessionLifecycle()?.isFinishing ?? false) &&
        _hasAnalysisSelection();
  }

  void _observeCameraGeometry(CameraController controller) {
    if (identical(_observedCameraController, controller)) {
      return;
    }

    _stopObservingCameraGeometry();
    _observedCameraController = controller;
    final value = safeControllerValue(controller);
    _observedDeviceOrientation = value?.deviceOrientation;
    _observedPreviewSize = value?.previewSize;
    controller.addListener(_handleObservedCameraGeometryChanged);
  }

  void _handleObservedCameraGeometryChanged() {
    final controller = _observedCameraController;
    if (!_isMounted() || controller == null) {
      return;
    }

    final value = safeControllerValue(controller);
    final nextOrientation = value?.deviceOrientation;
    final nextPreviewSize = value?.previewSize;
    if (_observedDeviceOrientation == nextOrientation &&
        _observedPreviewSize == nextPreviewSize) {
      return;
    }

    _observedDeviceOrientation = nextOrientation;
    _observedPreviewSize = nextPreviewSize;
    _notifyStateChanged();
  }

  void _stopObservingCameraGeometry() {
    _observedCameraController?.removeListener(
      _handleObservedCameraGeometryChanged,
    );
    _observedCameraController = null;
    _observedDeviceOrientation = null;
    _observedPreviewSize = null;
  }

  void _markRecoveringAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markRecovering();
    });
  }
}
