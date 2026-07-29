/// Generic lifecycle phases shared by configurable repetition engines.
enum GenericRepPhase { neutral, towardPeak, peak, returning }

/// Declares how the primary movement metric changes from neutral toward peak.
enum GenericRepMetricDirection { decreasingToPeak, increasingToPeak }

/// Canonical transitions produced by [GenericRepEngine].
enum GenericRepTransitionType {
  acquireNeutral,
  startTowardPeak,
  reachPeak,
  startReturning,
  abortToNeutral,
  completeRep,
}

class GenericRepEngineConfig {
  const GenericRepEngineConfig({
    required this.neutralThreshold,
    required this.activeThreshold,
    required this.peakThreshold,
    this.direction = GenericRepMetricDirection.decreasingToPeak,
    this.minimumRom = 0.0,
    this.activeEntryMargin = 3.0,
    this.peakEntryMargin = 3.0,
    this.peakExitMargin = 8.0,
    this.activeConfirmationDuration = const Duration(milliseconds: 80),
    this.peakConfirmationDuration = const Duration(milliseconds: 80),
    this.returnConfirmationDuration = const Duration(milliseconds: 80),
    this.initialNeutralConfirmationDuration = const Duration(milliseconds: 100),
    this.neutralConfirmationDuration = const Duration(milliseconds: 100),
    this.neutralBaselineWindow = Duration.zero,
    this.neutralBaselineThresholdMargin = 0.0,
    this.retainPeakEvidenceAcrossActiveTransition = false,
    this.allowSparseCycleRecovery = false,
    this.retainedPeakEvidenceMaxAge = const Duration(milliseconds: 750),
  }) : assert(minimumRom >= 0.0),
       assert(activeEntryMargin >= 0.0),
       assert(peakEntryMargin >= 0.0),
       assert(peakExitMargin >= 0.0),
       assert(neutralBaselineThresholdMargin >= 0.0);

  final double neutralThreshold;
  final double activeThreshold;
  final double peakThreshold;
  final GenericRepMetricDirection direction;

  /// Minimum primary-metric range required before a completed lifecycle is
  /// counted as a repetition.
  final double minimumRom;

  /// Hysteresis margins that keep state changes from chattering around a
  /// threshold.
  final double activeEntryMargin;
  final double peakEntryMargin;
  final double peakExitMargin;

  /// Debounce/confirmation windows for lifecycle transitions.
  final Duration activeConfirmationDuration;
  final Duration peakConfirmationDuration;
  final Duration returnConfirmationDuration;

  /// Confirmation window used only while the engine is initially unarmed.
  ///
  /// Floor exercises can require a longer stable neutral hold before analysis
  /// begins without forcing the same delay at the end of every repetition.
  final Duration initialNeutralConfirmationDuration;

  final Duration neutralConfirmationDuration;

  /// Optional look-back window used to resolve a stable neutral baseline.
  ///
  /// Disabled by default so existing exercises preserve their first-crossing
  /// semantics. Small-excursion movements may opt in when the final neutral
  /// sample before active confirmation is too noisy to represent true start.
  final Duration neutralBaselineWindow;

  /// Distance from the configured neutral threshold required before a sample
  /// may contribute to the neutral baseline.
  final double neutralBaselineThresholdMargin;

  /// Preserves a strict peak observation that arrives while active-entry
  /// confirmation is still pending. This is opt-in because it relaxes the
  /// default consecutive-sample lifecycle only for exercises whose real-device
  /// validation proves sparse analysis sampling can consume a valid peak.
  final bool retainPeakEvidenceAcrossActiveTransition;

  /// Allows a strict peak sample to start and reach peak in one analysis frame,
  /// then allows a later strict neutral sample to return and complete the rep in
  /// one frame. This is opt-in for fast movements whose device validation shows
  /// that intermediate lifecycle samples are routinely dropped.
  final bool allowSparseCycleRecovery;

  /// Upper bound for carrying a peak sample across a delayed analysis update.
  /// The default covers the measured p95 detector latency of the blocked
  /// exercises without allowing an old peak to survive indefinitely.
  final Duration retainedPeakEvidenceMaxAge;
}

class GenericRepConfirmedTransition {
  const GenericRepConfirmedTransition({
    required this.type,
    required this.effectiveAt,
  });

  final GenericRepTransitionType type;
  final DateTime effectiveAt;
}

class GenericRepCompletedRep {
  const GenericRepCompletedRep({
    required this.repIndex,
    required this.startMetric,
    required this.peakMetric,
    required this.rom,
  });

  final int repIndex;
  final double startMetric;
  final double peakMetric;
  final double rom;
}

class GenericRepEngineFrameResult {
  GenericRepEngineFrameResult({
    required this.wasArmedAtFrameStart,
    required this.isArmedAfterUpdate,
    required this.phaseBeforeUpdate,
    required this.phaseAfterUpdate,
    GenericRepConfirmedTransition? confirmedTransition,
    List<GenericRepConfirmedTransition>? confirmedTransitions,
    this.repStarted = false,
    this.repAborted = false,
    this.completedRep,
  }) : confirmedTransitions = List<GenericRepConfirmedTransition>.unmodifiable(
         confirmedTransitions ??
             (confirmedTransition == null
                 ? const <GenericRepConfirmedTransition>[]
                 : <GenericRepConfirmedTransition>[confirmedTransition]),
       );

  final bool wasArmedAtFrameStart;
  final bool isArmedAfterUpdate;
  final GenericRepPhase phaseBeforeUpdate;
  final GenericRepPhase phaseAfterUpdate;
  final List<GenericRepConfirmedTransition> confirmedTransitions;
  final bool repStarted;
  final bool repAborted;
  final GenericRepCompletedRep? completedRep;

  GenericRepConfirmedTransition? get confirmedTransition =>
      confirmedTransitions.isEmpty ? null : confirmedTransitions.last;
}

class _TimedNeutralMetricSample {
  const _TimedNeutralMetricSample({
    required this.metric,
    required this.observedAt,
  });

  final double metric;
  final DateTime observedAt;
}

/// Reusable, metric-driven repetition lifecycle engine.
///
/// The engine deliberately knows nothing about pose landmarks, technique
/// scoring, UI feedback, persistence, or a specific exercise. Exercises share
/// it by supplying thresholds, movement direction, ROM requirements, and
/// debounce durations through [GenericRepEngineConfig].
class GenericRepEngine {
  GenericRepEngine({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _validateConfig();
  }

  final GenericRepEngineConfig config;
  final DateTime Function() _now;

  GenericRepPhase phase = GenericRepPhase.neutral;
  int repCount = 0;

  bool _isArmed = false;
  GenericRepTransitionType? _pendingTransition;
  DateTime? _pendingTransitionStartedAt;

  double? _pendingStartTowardPeakMetric;
  DateTime? _retainedPeakEvidenceStartedAt;
  double? _retainedPeakMetric;
  double? _lastNeutralMetric;
  DateTime? _lastNeutralObservedAt;
  DateTime? _sparsePeakObservedAt;
  double? _currentRepStartMetric;
  double? _currentRepMinMetric;
  double? _currentRepMaxMetric;
  final List<_TimedNeutralMetricSample> _neutralBaselineSamples =
      <_TimedNeutralMetricSample>[];

  bool get isArmed => _isArmed;
  GenericRepTransitionType? get pendingTransition => _pendingTransition;
  DateTime? get pendingTransitionStartedAt => _pendingTransitionStartedAt;

  Duration? get pendingTransitionRequiredDuration {
    final transition = _pendingTransition;
    return transition == null ? null : _confirmationDurationFor(transition);
  }

  GenericRepEngineFrameResult update({required double primaryMetric}) {
    final now = _now();
    final wasArmedAtFrameStart = _isArmed;
    final phaseBeforeUpdate = phase;

    if ((!_isArmed || phase == GenericRepPhase.neutral) &&
        _isNeutralBaselineMetric(primaryMetric)) {
      _recordNeutralBaseline(primaryMetric, now);
    }

    if (!_isArmed) {
      final armedAt = _confirmTransition(
        transition: GenericRepTransitionType.acquireNeutral,
        condition: isNeutralMetric(primaryMetric),
        now: now,
      );
      if (armedAt != null) {
        _isArmed = true;
        phase = GenericRepPhase.neutral;
        _lastNeutralMetric = primaryMetric;
        _lastNeutralObservedAt = now;
      }
      return GenericRepEngineFrameResult(
        wasArmedAtFrameStart: wasArmedAtFrameStart,
        isArmedAfterUpdate: _isArmed,
        phaseBeforeUpdate: phaseBeforeUpdate,
        phaseAfterUpdate: phase,
        confirmedTransition: armedAt == null
            ? null
            : GenericRepConfirmedTransition(
                type: GenericRepTransitionType.acquireNeutral,
                effectiveAt: armedAt,
              ),
      );
    }

    if (isNeutralMetric(primaryMetric)) {
      _lastNeutralMetric = primaryMetric;
      _lastNeutralObservedAt = now;
    }

    GenericRepConfirmedTransition? confirmedTransition;
    var repStarted = false;
    var repAborted = false;
    GenericRepCompletedRep? completedRep;

    switch (phase) {
      case GenericRepPhase.neutral:
        if (_canRecoverSparsePeak(primaryMetric, now)) {
          final startAt =
              _pendingTransitionStartedAt ?? _lastNeutralObservedAt ?? now;
          final repStartMetric = _resolvedNeutralBaseline(
            fallback: _lastNeutralMetric ?? primaryMetric,
            now: now,
          );
          _pendingStartTowardPeakMetric = null;
          _clearPendingTransition();
          _startRep(repStartMetric);
          _recordMetric(primaryMetric);
          _sparsePeakObservedAt = now;
          phase = GenericRepPhase.peak;
          return GenericRepEngineFrameResult(
            wasArmedAtFrameStart: wasArmedAtFrameStart,
            isArmedAfterUpdate: _isArmed,
            phaseBeforeUpdate: phaseBeforeUpdate,
            phaseAfterUpdate: phase,
            confirmedTransitions: <GenericRepConfirmedTransition>[
              GenericRepConfirmedTransition(
                type: GenericRepTransitionType.startTowardPeak,
                effectiveAt: startAt,
              ),
              GenericRepConfirmedTransition(
                type: GenericRepTransitionType.reachPeak,
                effectiveAt: now,
              ),
            ],
            repStarted: true,
          );
        }

        final hasEnteredActive = hasEnteredActiveRange(primaryMetric);
        if (!hasEnteredActive) {
          _pendingStartTowardPeakMetric = null;
          _clearRetainedPeakEvidence();
        } else {
          if (_pendingTransition != GenericRepTransitionType.startTowardPeak ||
              _pendingStartTowardPeakMetric == null) {
            _pendingStartTowardPeakMetric = primaryMetric;
          }
          _captureRetainedPeakEvidence(primaryMetric, now);
        }
        final confirmedAt = _confirmTransition(
          transition: GenericRepTransitionType.startTowardPeak,
          condition: hasEnteredActive,
          now: now,
        );
        if (confirmedAt != null) {
          final fallbackStartMetric =
              config.retainPeakEvidenceAcrossActiveTransition
              ? (_lastNeutralMetric ??
                    _pendingStartTowardPeakMetric ??
                    primaryMetric)
              : (_pendingStartTowardPeakMetric ?? primaryMetric);
          final repStartMetric = _resolvedNeutralBaseline(
            fallback: fallbackStartMetric,
            now: now,
          );
          _pendingStartTowardPeakMetric = null;
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.startTowardPeak,
            effectiveAt: confirmedAt,
          );
          repStarted = true;
          phase = GenericRepPhase.towardPeak;
          _startRep(repStartMetric);
          final retainedPeakMetric = _retainedPeakMetric;
          if (retainedPeakMetric != null) {
            _recordMetric(retainedPeakMetric);
          }
          _recordMetric(primaryMetric);
          _seedRetainedPeakConfirmation(now);
        }
        break;

      case GenericRepPhase.towardPeak:
        _recordMetric(primaryMetric);
        _captureRetainedPeakEvidence(primaryMetric, now);
        final hasEnteredPeak = hasReachedPeakRange(primaryMetric);
        final isPendingPeakWithinHysteresis =
            _pendingTransition == GenericRepTransitionType.reachPeak &&
            !hasExitedPeakRange(primaryMetric);
        final hasRetainedPeakEvidence = _hasUsableRetainedPeakEvidence(now);
        final peakConfirmedAt = _confirmTransition(
          transition: GenericRepTransitionType.reachPeak,
          condition:
              hasEnteredPeak ||
              isPendingPeakWithinHysteresis ||
              hasRetainedPeakEvidence,
          now: now,
        );
        if (peakConfirmedAt != null) {
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.reachPeak,
            effectiveAt: peakConfirmedAt,
          );
          phase = GenericRepPhase.peak;
          if (config.allowSparseCycleRecovery) {
            _sparsePeakObservedAt =
                _retainedPeakEvidenceStartedAt ?? peakConfirmedAt;
          }
          _clearRetainedPeakEvidence();
        } else {
          final abortConfirmedAt = _confirmTransition(
            transition: GenericRepTransitionType.abortToNeutral,
            condition: isNeutralMetric(primaryMetric),
            now: now,
          );
          if (abortConfirmedAt != null) {
            confirmedTransition = GenericRepConfirmedTransition(
              type: GenericRepTransitionType.abortToNeutral,
              effectiveAt: abortConfirmedAt,
            );
            repAborted = true;
            phase = GenericRepPhase.neutral;
            _clearRetainedPeakEvidence();
            _resetCurrentRep();
          }
        }
        break;

      case GenericRepPhase.peak:
        _recordMetric(primaryMetric);
        if (_canRecoverSparseCompletion(primaryMetric, now)) {
          final returnAt = _sparsePeakObservedAt ?? now;
          final completion = _buildCompletion();
          GenericRepCompletedRep? sparseCompletedRep;
          if (completion.rom >= config.minimumRom) {
            repCount++;
            sparseCompletedRep = GenericRepCompletedRep(
              repIndex: repCount,
              startMetric: completion.startMetric,
              peakMetric: completion.peakMetric,
              rom: completion.rom,
            );
          } else {
            repAborted = true;
          }
          phase = GenericRepPhase.neutral;
          _lastNeutralMetric = primaryMetric;
          _lastNeutralObservedAt = now;
          _resetCurrentRep();
          return GenericRepEngineFrameResult(
            wasArmedAtFrameStart: wasArmedAtFrameStart,
            isArmedAfterUpdate: _isArmed,
            phaseBeforeUpdate: phaseBeforeUpdate,
            phaseAfterUpdate: phase,
            confirmedTransitions: <GenericRepConfirmedTransition>[
              GenericRepConfirmedTransition(
                type: GenericRepTransitionType.startReturning,
                effectiveAt: returnAt,
              ),
              GenericRepConfirmedTransition(
                type: GenericRepTransitionType.completeRep,
                effectiveAt: now,
              ),
            ],
            repAborted: repAborted,
            completedRep: sparseCompletedRep,
          );
        }
        final returnConfirmedAt = _confirmTransition(
          transition: GenericRepTransitionType.startReturning,
          condition: hasExitedPeakRange(primaryMetric),
          now: now,
        );
        if (returnConfirmedAt != null) {
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.startReturning,
            effectiveAt: returnConfirmedAt,
          );
          phase = GenericRepPhase.returning;
        }
        break;

      case GenericRepPhase.returning:
        _recordMetric(primaryMetric);
        final completedAt = _confirmTransition(
          transition: GenericRepTransitionType.completeRep,
          condition: isNeutralMetric(primaryMetric),
          now: now,
        );
        if (completedAt != null) {
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.completeRep,
            effectiveAt: completedAt,
          );
          final completion = _buildCompletion();
          if (completion.rom >= config.minimumRom) {
            repCount++;
            completedRep = GenericRepCompletedRep(
              repIndex: repCount,
              startMetric: completion.startMetric,
              peakMetric: completion.peakMetric,
              rom: completion.rom,
            );
          } else {
            repAborted = true;
          }
          phase = GenericRepPhase.neutral;
          _resetCurrentRep();
        }
        break;
    }

    return GenericRepEngineFrameResult(
      wasArmedAtFrameStart: wasArmedAtFrameStart,
      isArmedAfterUpdate: _isArmed,
      phaseBeforeUpdate: phaseBeforeUpdate,
      phaseAfterUpdate: phase,
      confirmedTransition: confirmedTransition,
      repStarted: repStarted,
      repAborted: repAborted,
      completedRep: completedRep,
    );
  }

  bool isNeutralMetric(double value) {
    return switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        value > config.neutralThreshold,
      GenericRepMetricDirection.increasingToPeak =>
        value < config.neutralThreshold,
    };
  }

  bool hasEnteredActiveRange(double value) {
    return switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        value < config.activeThreshold - config.activeEntryMargin,
      GenericRepMetricDirection.increasingToPeak =>
        value > config.activeThreshold + config.activeEntryMargin,
    };
  }

  bool hasReachedPeakRange(double value) {
    return switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        value < config.peakThreshold - config.peakEntryMargin,
      GenericRepMetricDirection.increasingToPeak =>
        value > config.peakThreshold + config.peakEntryMargin,
    };
  }

  bool hasExitedPeakRange(double value) {
    return switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        value > config.peakThreshold + config.peakExitMargin,
      GenericRepMetricDirection.increasingToPeak =>
        value < config.peakThreshold - config.peakExitMargin,
    };
  }

  bool isMetricCompatibleWithPhase(
    double primaryMetric, {
    required GenericRepPhase frozenPhase,
    required bool wasArmed,
  }) {
    if (!wasArmed) {
      return isNeutralMetric(primaryMetric);
    }

    switch (config.direction) {
      case GenericRepMetricDirection.decreasingToPeak:
        switch (frozenPhase) {
          case GenericRepPhase.neutral:
            return isNeutralMetric(primaryMetric);
          case GenericRepPhase.towardPeak:
            return primaryMetric >=
                    config.peakThreshold - config.peakEntryMargin &&
                primaryMetric < config.neutralThreshold;
          case GenericRepPhase.peak:
            return primaryMetric <=
                config.peakThreshold + config.peakExitMargin;
          case GenericRepPhase.returning:
            return primaryMetric >
                    config.peakThreshold + config.peakExitMargin &&
                primaryMetric < config.neutralThreshold;
        }
      case GenericRepMetricDirection.increasingToPeak:
        switch (frozenPhase) {
          case GenericRepPhase.neutral:
            return isNeutralMetric(primaryMetric);
          case GenericRepPhase.towardPeak:
            return primaryMetric <=
                    config.peakThreshold + config.peakEntryMargin &&
                primaryMetric > config.neutralThreshold;
          case GenericRepPhase.peak:
            return primaryMetric >=
                config.peakThreshold - config.peakExitMargin;
          case GenericRepPhase.returning:
            return primaryMetric <
                    config.peakThreshold - config.peakExitMargin &&
                primaryMetric > config.neutralThreshold;
        }
    }
  }

  bool _canRecoverSparsePeak(double primaryMetric, DateTime now) {
    if (!config.allowSparseCycleRecovery ||
        !hasReachedPeakRange(primaryMetric) ||
        _lastNeutralMetric == null) {
      return false;
    }
    final neutralAt = _lastNeutralObservedAt;
    if (neutralAt == null) {
      return false;
    }
    return now.difference(neutralAt) >= config.activeConfirmationDuration;
  }

  bool _canRecoverSparseCompletion(double primaryMetric, DateTime now) {
    final peakAt = _sparsePeakObservedAt;
    return config.allowSparseCycleRecovery &&
        peakAt != null &&
        now.difference(peakAt) <= config.retainedPeakEvidenceMaxAge &&
        isNeutralMetric(primaryMetric);
  }

  void cancelPendingTransition() {
    _pendingStartTowardPeakMetric = null;
    _clearRetainedPeakEvidence();
    _clearPendingTransition();
  }

  void clearActiveRepContext() {
    _isArmed = false;
    phase = GenericRepPhase.neutral;
    _pendingStartTowardPeakMetric = null;
    _lastNeutralMetric = null;
    _lastNeutralObservedAt = null;
    _neutralBaselineSamples.clear();
    _sparsePeakObservedAt = null;
    _clearRetainedPeakEvidence();
    _clearPendingTransition();
    _resetCurrentRep(clearPendingTransition: false);
  }

  void reset() {
    repCount = 0;
    clearActiveRepContext();
  }

  void _captureRetainedPeakEvidence(double primaryMetric, DateTime now) {
    if (!config.retainPeakEvidenceAcrossActiveTransition) {
      return;
    }
    _discardExpiredRetainedPeakEvidence(now);
    if (!hasReachedPeakRange(primaryMetric)) {
      return;
    }

    _retainedPeakEvidenceStartedAt ??= now;
    final retainedMetric = _retainedPeakMetric;
    _retainedPeakMetric = switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        retainedMetric == null || primaryMetric < retainedMetric
            ? primaryMetric
            : retainedMetric,
      GenericRepMetricDirection.increasingToPeak =>
        retainedMetric == null || primaryMetric > retainedMetric
            ? primaryMetric
            : retainedMetric,
    };
  }

  void _seedRetainedPeakConfirmation(DateTime now) {
    if (!_hasUsableRetainedPeakEvidence(now)) {
      return;
    }
    final startedAt = _retainedPeakEvidenceStartedAt;
    if (startedAt == null) {
      return;
    }
    _pendingTransition = GenericRepTransitionType.reachPeak;
    _pendingTransitionStartedAt = startedAt;
  }

  bool _hasUsableRetainedPeakEvidence(DateTime now) {
    if (!config.retainPeakEvidenceAcrossActiveTransition) {
      return false;
    }
    _discardExpiredRetainedPeakEvidence(now);
    return _retainedPeakEvidenceStartedAt != null;
  }

  void _discardExpiredRetainedPeakEvidence(DateTime now) {
    final startedAt = _retainedPeakEvidenceStartedAt;
    if (startedAt == null) {
      return;
    }
    if (now.difference(startedAt) > config.retainedPeakEvidenceMaxAge) {
      _clearRetainedPeakEvidence();
    }
  }

  void _clearRetainedPeakEvidence() {
    _retainedPeakEvidenceStartedAt = null;
    _retainedPeakMetric = null;
  }

  bool _isNeutralBaselineMetric(double value) {
    if (config.neutralBaselineWindow == Duration.zero) {
      return false;
    }
    return switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        value >=
            config.neutralThreshold + config.neutralBaselineThresholdMargin,
      GenericRepMetricDirection.increasingToPeak =>
        value <=
            config.neutralThreshold - config.neutralBaselineThresholdMargin,
    };
  }

  void _recordNeutralBaseline(double primaryMetric, DateTime now) {
    _pruneNeutralBaseline(now);
    _neutralBaselineSamples.add(
      _TimedNeutralMetricSample(metric: primaryMetric, observedAt: now),
    );
    const maxSamples = 24;
    if (_neutralBaselineSamples.length > maxSamples) {
      _neutralBaselineSamples.removeRange(
        0,
        _neutralBaselineSamples.length - maxSamples,
      );
    }
  }

  double _resolvedNeutralBaseline({
    required double fallback,
    required DateTime now,
  }) {
    if (config.neutralBaselineWindow == Duration.zero) {
      return fallback;
    }
    _pruneNeutralBaseline(now);
    if (_neutralBaselineSamples.isEmpty) {
      return fallback;
    }

    final sorted =
        _neutralBaselineSamples
            .map((sample) => sample.metric)
            .toList(growable: false)
          ..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  void _pruneNeutralBaseline(DateTime now) {
    final window = config.neutralBaselineWindow;
    if (window == Duration.zero) {
      _neutralBaselineSamples.clear();
      return;
    }
    _neutralBaselineSamples.removeWhere(
      (sample) => now.difference(sample.observedAt) > window,
    );
  }

  void _startRep(double primaryMetric) {
    _currentRepStartMetric = primaryMetric;
    _neutralBaselineSamples.clear();
    _currentRepMinMetric = primaryMetric;
    _currentRepMaxMetric = primaryMetric;
  }

  void _recordMetric(double primaryMetric) {
    final minMetric = _currentRepMinMetric;
    final maxMetric = _currentRepMaxMetric;
    _currentRepMinMetric = minMetric == null || primaryMetric < minMetric
        ? primaryMetric
        : minMetric;
    _currentRepMaxMetric = maxMetric == null || primaryMetric > maxMetric
        ? primaryMetric
        : maxMetric;
  }

  _GenericRepCompletionData _buildCompletion() {
    final startMetric = _currentRepStartMetric ?? config.neutralThreshold;
    final peakMetric = switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        _currentRepMinMetric ?? startMetric,
      GenericRepMetricDirection.increasingToPeak =>
        _currentRepMaxMetric ?? startMetric,
    };
    final rom = (peakMetric - startMetric).abs();

    return _GenericRepCompletionData(
      startMetric: startMetric,
      peakMetric: peakMetric,
      rom: rom,
    );
  }

  DateTime? _confirmTransition({
    required GenericRepTransitionType transition,
    required bool condition,
    required DateTime now,
  }) {
    if (!condition) {
      if (_pendingTransition == transition) {
        _clearPendingTransition();
      }
      return null;
    }

    if (_pendingTransition != transition ||
        _pendingTransitionStartedAt == null) {
      _pendingTransition = transition;
      _pendingTransitionStartedAt = now;
      return null;
    }

    final startedAt = _pendingTransitionStartedAt!;
    if (now.difference(startedAt) < _confirmationDurationFor(transition)) {
      return null;
    }

    _clearPendingTransition();
    return startedAt;
  }

  Duration _confirmationDurationFor(GenericRepTransitionType transition) {
    return switch (transition) {
      GenericRepTransitionType.acquireNeutral =>
        config.initialNeutralConfirmationDuration,
      GenericRepTransitionType.abortToNeutral =>
        config.neutralConfirmationDuration,
      GenericRepTransitionType.completeRep =>
        config.neutralConfirmationDuration,
      GenericRepTransitionType.startTowardPeak =>
        config.activeConfirmationDuration,
      GenericRepTransitionType.reachPeak => config.peakConfirmationDuration,
      GenericRepTransitionType.startReturning =>
        config.returnConfirmationDuration,
    };
  }

  void _clearPendingTransition() {
    _pendingTransition = null;
    _pendingTransitionStartedAt = null;
  }

  void _resetCurrentRep({bool clearPendingTransition = true}) {
    _currentRepStartMetric = null;
    _sparsePeakObservedAt = null;
    _clearRetainedPeakEvidence();
    _currentRepMinMetric = null;
    _currentRepMaxMetric = null;
    if (clearPendingTransition) {
      _clearPendingTransition();
    }
  }

  void _validateConfig() {
    if (config.initialNeutralConfirmationDuration.isNegative) {
      throw ArgumentError.value(
        config.initialNeutralConfirmationDuration,
        'config.initialNeutralConfirmationDuration',
        'Must not be negative.',
      );
    }
    if (config.neutralBaselineWindow.isNegative) {
      throw ArgumentError.value(
        config.neutralBaselineWindow,
        'config.neutralBaselineWindow',
        'Must not be negative.',
      );
    }
    if (config.retainedPeakEvidenceMaxAge.isNegative) {
      throw ArgumentError.value(
        config.retainedPeakEvidenceMaxAge,
        'config.retainedPeakEvidenceMaxAge',
        'Must not be negative.',
      );
    }

    final isOrdered = switch (config.direction) {
      GenericRepMetricDirection.decreasingToPeak =>
        config.neutralThreshold > config.activeThreshold &&
            config.activeThreshold > config.peakThreshold,
      GenericRepMetricDirection.increasingToPeak =>
        config.neutralThreshold < config.activeThreshold &&
            config.activeThreshold < config.peakThreshold,
    };
    if (!isOrdered) {
      throw ArgumentError.value(
        <double>[
          config.neutralThreshold,
          config.activeThreshold,
          config.peakThreshold,
        ],
        'config',
        'Thresholds must be ordered from neutral to active to peak for the '
            'configured metric direction.',
      );
    }
  }
}

class _GenericRepCompletionData {
  const _GenericRepCompletionData({
    required this.startMetric,
    required this.peakMetric,
    required this.rom,
  });

  final double startMetric;
  final double peakMetric;
  final double rom;
}
