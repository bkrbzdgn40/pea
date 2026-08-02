import 'models/setup_camera_view_orientation.dart';
import 'models/setup_framing_geometry.dart';
import 'models/setup_readiness_state.dart';
import 'models/setup_start_pose.dart';

/// Combines per-frame setup diagnostics into a conservative stable state.
///
/// Valid evidence must remain current for the configured stable window before the
/// state becomes ready. Brief evidence loss is represented as temporarily lost
/// so one dropped pose frame does not immediately collapse a ready setup.
class SetupReadinessStateMachine {
  SetupReadinessStateMachine({
    this.thresholds = SetupReadinessThresholds.defaults,
  });

  final SetupReadinessThresholds thresholds;

  SetupReadinessPhase _phase = SetupReadinessPhase.initializing;
  SetupReadinessPhase _rawPhase = SetupReadinessPhase.initializing;
  SetupReadinessEvidence _evidence = const SetupReadinessEvidence();
  DateTime? _phaseEnteredAt;
  DateTime? _lastUpdatedAt;
  DateTime? _stableSince;
  DateTime? _lossStartedAt;
  DateTime? _evidenceUpdatedAt;
  bool _restoreReadyAfterLoss = false;

  SetupReadinessSnapshot reset({required DateTime now}) {
    _phase = SetupReadinessPhase.initializing;
    _rawPhase = SetupReadinessPhase.initializing;
    _evidence = const SetupReadinessEvidence();
    _phaseEnteredAt = now;
    _lastUpdatedAt = now;
    _stableSince = null;
    _lossStartedAt = null;
    _evidenceUpdatedAt = null;
    _restoreReadyAfterLoss = false;
    return _snapshot(now);
  }

  SetupReadinessSnapshot update({
    required SetupReadinessEvidence evidence,
    required DateTime now,
  }) {
    final effectiveNow = _monotonic(now);
    _evidence = evidence;
    _rawPhase = _classify(evidence);
    _evidenceUpdatedAt = effectiveNow;
    return _evaluate(effectiveNow);
  }

  /// Advances a pending stability or grace window without new camera evidence.
  SetupReadinessSnapshot tick({required DateTime now}) {
    return _evaluate(_monotonic(now));
  }

  /// Delay until the next time-only transition, if one is pending.
  Duration? nextTransitionDelay({required DateTime now}) {
    final effectiveNow = _monotonic(now, updateClock: false);
    final candidates = <Duration>[
      if (_phase == SetupReadinessPhase.stabilizing && _stableSince != null)
        _remaining(
          thresholds.stableEvidenceDuration,
          effectiveNow.difference(_stableSince!),
        ),
      if ((_phase == SetupReadinessPhase.stabilizing ||
              _phase == SetupReadinessPhase.ready) &&
          _rawPhase == SetupReadinessPhase.ready &&
          _evidenceUpdatedAt != null)
        _remaining(
          thresholds.maximumEvidenceAge,
          effectiveNow.difference(_evidenceUpdatedAt!),
        ),
      if (_phase == SetupReadinessPhase.temporarilyLost &&
          _lossStartedAt != null)
        _remaining(
          thresholds.temporaryLossGraceDuration,
          effectiveNow.difference(_lossStartedAt!),
        ),
    ];
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.reduce(
      (current, candidate) => candidate < current ? candidate : current,
    );
  }

  SetupReadinessSnapshot _evaluate(DateTime now) {
    final rawPhase = _effectiveRawPhase(now);
    if (rawPhase == SetupReadinessPhase.ready) {
      return _handleValidEvidence(now);
    }

    if (_isTransientLoss(rawPhase) &&
        (_phase == SetupReadinessPhase.ready ||
            _phase == SetupReadinessPhase.stabilizing ||
            _phase == SetupReadinessPhase.temporarilyLost)) {
      return _handleTemporaryLoss(now, rawPhase);
    }

    _clearTimingWindows();
    return _commit(rawPhase, now);
  }

  SetupReadinessSnapshot _handleValidEvidence(DateTime now) {
    if (_phase == SetupReadinessPhase.temporarilyLost) {
      final restoreReady = _restoreReadyAfterLoss;
      _lossStartedAt = null;
      _restoreReadyAfterLoss = false;
      if (restoreReady) {
        _stableSince = now.subtract(thresholds.stableEvidenceDuration);
        return _commit(SetupReadinessPhase.ready, now);
      }
      _stableSince = now;
    } else {
      _lossStartedAt = null;
      _restoreReadyAfterLoss = false;
      _stableSince ??= now;
    }

    final stableDuration = now.difference(_stableSince!);
    if (stableDuration >= thresholds.stableEvidenceDuration) {
      return _commit(SetupReadinessPhase.ready, now);
    }
    return _commit(SetupReadinessPhase.stabilizing, now);
  }

  SetupReadinessSnapshot _handleTemporaryLoss(
    DateTime now,
    SetupReadinessPhase rawPhase,
  ) {
    if (_lossStartedAt == null) {
      _lossStartedAt = now;
      _restoreReadyAfterLoss = _phase == SetupReadinessPhase.ready;
    }

    final lossDuration = now.difference(_lossStartedAt!);
    if (lossDuration < thresholds.temporaryLossGraceDuration) {
      return _commit(SetupReadinessPhase.temporarilyLost, now);
    }

    _clearTimingWindows();
    return _commit(rawPhase, now);
  }

  SetupReadinessPhase _effectiveRawPhase(DateTime now) {
    if (_rawPhase != SetupReadinessPhase.ready || _evidenceUpdatedAt == null) {
      return _rawPhase;
    }
    final evidenceAge = now.difference(_evidenceUpdatedAt!);
    return evidenceAge >= thresholds.maximumEvidenceAge
        ? SetupReadinessPhase.initializing
        : _rawPhase;
  }

  SetupReadinessPhase _classify(SetupReadinessEvidence evidence) {
    if (evidence.hasError) {
      return SetupReadinessPhase.error;
    }

    final framing = evidence.framingAssessment;
    if (framing == null) {
      return SetupReadinessPhase.initializing;
    }

    final framingPhase = switch (framing.status) {
      SetupFramingStatus.noPerson => SetupReadinessPhase.noPerson,
      SetupFramingStatus.incompleteCoverage =>
        SetupReadinessPhase.incompleteCoverage,
      SetupFramingStatus.clipped => SetupReadinessPhase.clipped,
      SetupFramingStatus.tooNear => SetupReadinessPhase.tooNear,
      SetupFramingStatus.tooFar => SetupReadinessPhase.tooFar,
      SetupFramingStatus.offCenter => SetupReadinessPhase.offCenter,
      SetupFramingStatus.ready => null,
    };
    if (framingPhase != null) {
      return framingPhase;
    }

    final cameraView = evidence.cameraViewAssessment;
    if (cameraView == null ||
        cameraView.status ==
            SetupCameraViewAdvisoryStatus.insufficientEvidence ||
        cameraView.status == SetupCameraViewAdvisoryStatus.indeterminate) {
      return SetupReadinessPhase.initializing;
    }
    if (cameraView.status == SetupCameraViewAdvisoryStatus.unsupported) {
      return SetupReadinessPhase.wrongView;
    }

    final startPose = evidence.startPoseAssessment;
    if (startPose == null ||
        startPose.status == SetupStartPoseStatus.insufficientEvidence) {
      return SetupReadinessPhase.initializing;
    }
    if (startPose.status == SetupStartPoseStatus.notMatched) {
      return SetupReadinessPhase.startPoseMissing;
    }

    return SetupReadinessPhase.ready;
  }

  bool _isTransientLoss(SetupReadinessPhase phase) {
    return phase == SetupReadinessPhase.initializing ||
        phase == SetupReadinessPhase.noPerson ||
        phase == SetupReadinessPhase.incompleteCoverage ||
        phase == SetupReadinessPhase.startPoseMissing;
  }

  SetupReadinessSnapshot _commit(SetupReadinessPhase next, DateTime now) {
    if (_phase != next || _phaseEnteredAt == null) {
      _phase = next;
      _phaseEnteredAt = now;
    }
    _lastUpdatedAt = now;
    return _snapshot(now);
  }

  SetupReadinessSnapshot _snapshot(DateTime now) {
    final stableDuration = _stableSince == null
        ? Duration.zero
        : _nonNegative(now.difference(_stableSince!));
    final lossDuration = _lossStartedAt == null
        ? Duration.zero
        : _nonNegative(now.difference(_lossStartedAt!));
    final stableMilliseconds = thresholds.stableEvidenceDuration.inMilliseconds;
    final stabilityProgress = _phase == SetupReadinessPhase.ready
        ? 1.0
        : stableMilliseconds == 0
        ? (_rawPhase == SetupReadinessPhase.ready ? 1.0 : 0.0)
        : (stableDuration.inMilliseconds / stableMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();

    return SetupReadinessSnapshot(
      phase: _phase,
      evidence: _evidence,
      enteredAt: _phaseEnteredAt ?? now,
      updatedAt: now,
      diagnostics: SetupReadinessDiagnosticsSnapshot(
        rawPhase: _effectiveRawPhase(now),
        framingStatus: _evidence.framingAssessment?.status,
        cameraViewStatus: _evidence.cameraViewAssessment?.status,
        startPoseStatus: _evidence.startPoseAssessment?.status,
        stableEvidenceDuration: stableDuration,
        temporaryLossDuration: lossDuration,
        stabilityProgress: stabilityProgress,
        confidence: _confidence(_evidence),
      ),
    );
  }

  DateTime _monotonic(DateTime now, {bool updateClock = true}) {
    final previous = _lastUpdatedAt;
    final result = previous != null && now.isBefore(previous) ? previous : now;
    if (updateClock) {
      _lastUpdatedAt = result;
    }
    return result;
  }

  void _clearTimingWindows() {
    _stableSince = null;
    _lossStartedAt = null;
    _restoreReadyAfterLoss = false;
  }

  Duration _remaining(Duration total, Duration elapsed) {
    final remaining = total - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration _nonNegative(Duration value) {
    return value.isNegative ? Duration.zero : value;
  }

  double _confidence(SetupReadinessEvidence evidence) {
    final values = <double>[
      ?evidence.framingAssessment?.confidence,
      ?evidence.cameraViewAssessment?.confidence,
      ?evidence.startPoseAssessment?.confidence,
    ];
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((sum, value) => sum + value) / values.length;
  }
}
