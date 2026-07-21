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
    this.neutralConfirmationDuration = const Duration(milliseconds: 100),
  }) : assert(minimumRom >= 0.0),
       assert(activeEntryMargin >= 0.0),
       assert(peakEntryMargin >= 0.0),
       assert(peakExitMargin >= 0.0);

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
  final Duration neutralConfirmationDuration;
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
  const GenericRepEngineFrameResult({
    required this.wasArmedAtFrameStart,
    required this.isArmedAfterUpdate,
    required this.phaseBeforeUpdate,
    required this.phaseAfterUpdate,
    this.confirmedTransition,
    this.repStarted = false,
    this.repAborted = false,
    this.completedRep,
  });

  final bool wasArmedAtFrameStart;
  final bool isArmedAfterUpdate;
  final GenericRepPhase phaseBeforeUpdate;
  final GenericRepPhase phaseAfterUpdate;
  final GenericRepConfirmedTransition? confirmedTransition;
  final bool repStarted;
  final bool repAborted;
  final GenericRepCompletedRep? completedRep;
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

  double? _currentRepStartMetric;
  double? _currentRepMinMetric;
  double? _currentRepMaxMetric;

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

    if (!_isArmed) {
      final armedAt = _confirmTransition(
        transition: GenericRepTransitionType.acquireNeutral,
        condition: isNeutralMetric(primaryMetric),
        now: now,
      );
      if (armedAt != null) {
        _isArmed = true;
        phase = GenericRepPhase.neutral;
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

    GenericRepConfirmedTransition? confirmedTransition;
    var repStarted = false;
    var repAborted = false;
    GenericRepCompletedRep? completedRep;

    switch (phase) {
      case GenericRepPhase.neutral:
        final confirmedAt = _confirmTransition(
          transition: GenericRepTransitionType.startTowardPeak,
          condition: hasEnteredActiveRange(primaryMetric),
          now: now,
        );
        if (confirmedAt != null) {
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.startTowardPeak,
            effectiveAt: confirmedAt,
          );
          repStarted = true;
          phase = GenericRepPhase.towardPeak;
          _startRep(primaryMetric);
        }
        break;

      case GenericRepPhase.towardPeak:
        _recordMetric(primaryMetric);
        final peakConfirmedAt = _confirmTransition(
          transition: GenericRepTransitionType.reachPeak,
          condition: hasReachedPeakRange(primaryMetric),
          now: now,
        );
        if (peakConfirmedAt != null) {
          confirmedTransition = GenericRepConfirmedTransition(
            type: GenericRepTransitionType.reachPeak,
            effectiveAt: peakConfirmedAt,
          );
          phase = GenericRepPhase.peak;
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
            _resetCurrentRep();
          }
        }
        break;

      case GenericRepPhase.peak:
        _recordMetric(primaryMetric);
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

  void cancelPendingTransition() {
    _clearPendingTransition();
  }

  void clearActiveRepContext() {
    _isArmed = false;
    phase = GenericRepPhase.neutral;
    _clearPendingTransition();
    _resetCurrentRep(clearPendingTransition: false);
  }

  void reset() {
    repCount = 0;
    clearActiveRepContext();
  }

  void _startRep(double primaryMetric) {
    _currentRepStartMetric = primaryMetric;
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
        config.neutralConfirmationDuration,
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
    _currentRepMinMetric = null;
    _currentRepMaxMetric = null;
    if (clearPendingTransition) {
      _clearPendingTransition();
    }
  }

  void _validateConfig() {
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
