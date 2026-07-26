import 'package:flutter/foundation.dart';

enum PreparationLiveCameraHandoffPhase {
  preparation,
  releasingPreparation,
  liveAnalysis,
  reclaimingPreparation,
  disposed,
}

typedef CameraHandoffStep = Future<void> Function();

/// Serializes camera ownership while moving from preparation to live analysis
/// and back again.
///
/// The preparation and live routes share one native camera resource, but they
/// must never own its image stream at the same time. This coordinator keeps the
/// handoff phases explicit and coalesces repeated start requests into the same
/// in-flight transition.
class PreparationLiveCameraHandoffCoordinator extends ChangeNotifier {
  PreparationLiveCameraHandoffPhase _phase =
      PreparationLiveCameraHandoffPhase.preparation;
  Future<void>? _activeHandoff;
  bool _isDisposed = false;

  PreparationLiveCameraHandoffPhase get phase => _phase;

  bool get isHandoffInProgress =>
      _phase != PreparationLiveCameraHandoffPhase.preparation &&
      _phase != PreparationLiveCameraHandoffPhase.disposed;

  bool get canUsePreparationCamera =>
      _phase == PreparationLiveCameraHandoffPhase.preparation;

  bool get canRecoverPreparationCamera =>
      _phase == PreparationLiveCameraHandoffPhase.preparation ||
      _phase == PreparationLiveCameraHandoffPhase.reclaimingPreparation;

  Future<void> waitForIdle() => _activeHandoff ?? Future<void>.value();

  Future<void> run({
    required CameraHandoffStep releasePreparation,
    required CameraHandoffStep runLiveAnalysis,
    required CameraHandoffStep reclaimPreparation,
  }) {
    if (_isDisposed) {
      return Future<void>.value();
    }

    final activeHandoff = _activeHandoff;
    if (activeHandoff != null) {
      return activeHandoff;
    }

    _setPhase(PreparationLiveCameraHandoffPhase.releasingPreparation);
    late final Future<void> handoff;
    handoff =
        _execute(
          releasePreparation: releasePreparation,
          runLiveAnalysis: runLiveAnalysis,
          reclaimPreparation: reclaimPreparation,
        ).whenComplete(() {
          if (identical(_activeHandoff, handoff)) {
            _activeHandoff = null;
          }
        });
    _activeHandoff = handoff;
    return handoff;
  }

  Future<void> _execute({
    required CameraHandoffStep releasePreparation,
    required CameraHandoffStep runLiveAnalysis,
    required CameraHandoffStep reclaimPreparation,
  }) async {
    try {
      await releasePreparation();
      if (_isDisposed) {
        return;
      }

      _setPhase(PreparationLiveCameraHandoffPhase.liveAnalysis);
      await runLiveAnalysis();
    } finally {
      if (!_isDisposed) {
        _setPhase(PreparationLiveCameraHandoffPhase.reclaimingPreparation);
        try {
          await reclaimPreparation();
        } finally {
          if (!_isDisposed) {
            _setPhase(PreparationLiveCameraHandoffPhase.preparation);
          }
        }
      }
    }
  }

  void _setPhase(PreparationLiveCameraHandoffPhase nextPhase) {
    if (_isDisposed || _phase == nextPhase) {
      return;
    }
    _phase = nextPhase;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _phase = PreparationLiveCameraHandoffPhase.disposed;
    super.dispose();
  }
}
