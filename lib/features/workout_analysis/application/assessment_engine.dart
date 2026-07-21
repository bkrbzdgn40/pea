import '../domain/models/assessment_models.dart';
import '../domain/stability_engine.dart';

class AssessmentEngineConfig {
  const AssessmentEngineConfig({
    this.minimumBalanceSamples = 10,
    this.minimumBalanceDuration = const Duration(seconds: 5),
    this.minimumRaisedFootClearanceRatio = 0.10,
    this.balanceStandardDeviationAtZeroScore = 0.10,
  }) : assert(minimumBalanceSamples >= 2),
       assert(minimumRaisedFootClearanceRatio >= 0.0),
       assert(balanceStandardDeviationAtZeroScore > 0.0);

  /// Product-level evidence threshold, not a clinical cutoff.
  final int minimumBalanceSamples;

  /// Minimum accepted one-leg-stance observation duration. This is a product
  /// evidence threshold rather than a diagnostic standard.
  final Duration minimumBalanceDuration;

  /// Minimum image-plane ankle-height separation used to accept a frame as a
  /// one-leg stance sample. The value is normalized by torso length.
  final double minimumRaisedFootClearanceRatio;

  /// Normalized image-plane sway dispersion mapped to a zero stability score.
  /// This score is a product heuristic and must not be presented as a clinical
  /// balance score.
  final double balanceStandardDeviationAtZeroScore;
}

enum BalanceAssessmentSignal { shoulderCenterX, hipCenterX }

/// Stateful assessment-mode engine for Squat, single-leg Balance, and Shoulder
/// Mobility assessments.
///
/// The engine owns assessment lifecycle and aggregation only. Pose extraction,
/// UI, persistence, voice, and haptic delivery stay outside this class.
class AssessmentEngine {
  AssessmentEngine({
    required this.type,
    this.config = const AssessmentEngineConfig(),
  }) : _balanceStability = StabilityEngine<BalanceAssessmentSignal>(
         config: StabilityEngineConfig(
           minimumSamplesPerSignal: 2,
           standardDeviationAtZeroScore:
               config.balanceStandardDeviationAtZeroScore,
         ),
       );

  final AssessmentType type;
  final AssessmentEngineConfig config;
  final StabilityEngine<BalanceAssessmentSignal> _balanceStability;

  AssessmentPhase _phase = AssessmentPhase.idle;
  AssessmentSide? _balanceSide;
  AssessmentResult? _result;

  int _squatSampleCount = 0;
  SquatAssessmentObservation? _deepestSquat;

  int _balanceRejectedSampleCount = 0;
  DateTime? _balanceFirstCapturedAt;
  DateTime? _balanceLastCapturedAt;

  int _shoulderSampleCount = 0;
  double? _leftMaximumElevation;
  double? _rightMaximumElevation;
  double? _torsoAtLeftMaximum;
  double? _torsoAtRightMaximum;

  AssessmentSnapshot get snapshot => _buildSnapshot();

  AssessmentSnapshot start({AssessmentSide? balanceSide}) {
    if (_phase != AssessmentPhase.idle) {
      throw StateError('AssessmentEngine can only be started from idle state.');
    }
    if (type == AssessmentType.balance && balanceSide == null) {
      throw ArgumentError.notNull('balanceSide');
    }
    if (type != AssessmentType.balance && balanceSide != null) {
      throw ArgumentError('balanceSide is only valid for balance assessment.');
    }

    _phase = AssessmentPhase.active;
    _balanceSide = balanceSide;
    _result = null;
    _clearAccumulators();
    if (type == AssessmentType.balance) {
      _balanceStability.beginWindow();
    }

    return _buildSnapshot();
  }

  AssessmentSnapshot observe(AssessmentObservation observation) {
    if (_phase != AssessmentPhase.active) {
      throw StateError('Assessment observations require an active assessment.');
    }
    if (observation.type != type) {
      throw ArgumentError.value(
        observation.type,
        'observation.type',
        'Expected ${type.name} observation.',
      );
    }

    switch (type) {
      case AssessmentType.squat:
        _observeSquat(observation as SquatAssessmentObservation);
        break;
      case AssessmentType.balance:
        _observeBalance(observation as BalanceAssessmentObservation);
        break;
      case AssessmentType.shoulderMobility:
        _observeShoulderMobility(
          observation as ShoulderMobilityAssessmentObservation,
        );
        break;
    }

    return _buildSnapshot();
  }

  AssessmentResult complete() {
    if (_phase != AssessmentPhase.active) {
      throw StateError('AssessmentEngine can only complete from active state.');
    }

    final completed = switch (type) {
      AssessmentType.squat => _buildSquatResult(),
      AssessmentType.balance => _buildBalanceResult(),
      AssessmentType.shoulderMobility => _buildShoulderMobilityResult(),
    };
    _result = completed;
    _phase = AssessmentPhase.completed;
    return completed;
  }

  AssessmentSnapshot reset() {
    if (_balanceStability.isWindowActive) {
      _balanceStability.abandonWindow();
    }
    _balanceStability.reset();
    _phase = AssessmentPhase.idle;
    _balanceSide = null;
    _result = null;
    _clearAccumulators();
    return _buildSnapshot();
  }

  void _observeSquat(SquatAssessmentObservation observation) {
    if (!observation.isComplete) {
      return;
    }

    _squatSampleCount += 1;
    final currentDeepest = _deepestSquat;
    if (currentDeepest == null ||
        observation.hipDepthRatio! < currentDeepest.hipDepthRatio!) {
      _deepestSquat = observation;
    }
  }

  void _observeBalance(BalanceAssessmentObservation observation) {
    if (observation.side != _balanceSide) {
      throw ArgumentError.value(
        observation.side,
        'observation.side',
        'Expected ${_balanceSide!.name} balance observation.',
      );
    }

    final shoulder = observation.shoulderCenterXNormalized;
    final hip = observation.hipCenterXNormalized;
    final clearance = observation.raisedFootClearanceRatio;
    final isAccepted =
        observation.isComplete &&
        shoulder!.isFinite &&
        hip!.isFinite &&
        clearance!.isFinite &&
        clearance >= config.minimumRaisedFootClearanceRatio;

    if (!isAccepted) {
      _balanceRejectedSampleCount += 1;
      return;
    }

    _balanceFirstCapturedAt ??= observation.capturedAt;
    _balanceLastCapturedAt = observation.capturedAt;
    _balanceStability.recordSample(<BalanceAssessmentSignal, double>{
      BalanceAssessmentSignal.shoulderCenterX: shoulder,
      BalanceAssessmentSignal.hipCenterX: hip,
    });
  }

  void _observeShoulderMobility(
    ShoulderMobilityAssessmentObservation observation,
  ) {
    if (!observation.hasAnyElevation) {
      return;
    }

    _shoulderSampleCount += 1;
    final left = observation.leftElevationDegrees;
    if (left != null &&
        left.isFinite &&
        (_leftMaximumElevation == null || left > _leftMaximumElevation!)) {
      _leftMaximumElevation = left;
      _torsoAtLeftMaximum = observation.torsoInclinationDegrees;
    }

    final right = observation.rightElevationDegrees;
    if (right != null &&
        right.isFinite &&
        (_rightMaximumElevation == null || right > _rightMaximumElevation!)) {
      _rightMaximumElevation = right;
      _torsoAtRightMaximum = observation.torsoInclinationDegrees;
    }
  }

  SquatAssessmentResult _buildSquatResult() {
    final deepest = _deepestSquat;
    if (deepest == null) {
      return const SquatAssessmentResult(
        sampleCount: 0,
        hasSufficientData: false,
        leftKneeFlexionDegrees: null,
        rightKneeFlexionDegrees: null,
        kneeFlexionAsymmetryDegrees: null,
        deepestHipDepthRatio: null,
        torsoInclinationAtDeepestDegrees: null,
      );
    }

    final leftFlexion = 180.0 - deepest.leftKneeAngleDegrees!;
    final rightFlexion = 180.0 - deepest.rightKneeAngleDegrees!;
    return SquatAssessmentResult(
      sampleCount: _squatSampleCount,
      hasSufficientData: true,
      leftKneeFlexionDegrees: leftFlexion,
      rightKneeFlexionDegrees: rightFlexion,
      kneeFlexionAsymmetryDegrees: (leftFlexion - rightFlexion).abs(),
      deepestHipDepthRatio: deepest.hipDepthRatio,
      torsoInclinationAtDeepestDegrees: deepest.torsoInclinationDegrees,
    );
  }

  BalanceAssessmentResult _buildBalanceResult() {
    final summary = _balanceStability.endWindow();
    final sampleCount = summary?.sampleCount ?? 0;
    final first = _balanceFirstCapturedAt;
    final last = _balanceLastCapturedAt;
    final duration = first == null || last == null
        ? Duration.zero
        : last.difference(first);

    final hasSufficientData =
        sampleCount >= config.minimumBalanceSamples &&
        duration.compareTo(config.minimumBalanceDuration) >= 0;

    return BalanceAssessmentResult(
      sampleCount: sampleCount,
      hasSufficientData: hasSufficientData,
      side: _balanceSide!,
      rejectedSampleCount: _balanceRejectedSampleCount,
      observedDuration: duration,
      shoulderSwayStandardDeviation: summary
          ?.signalSummaries[BalanceAssessmentSignal.shoulderCenterX]
          ?.standardDeviation,
      hipSwayStandardDeviation: summary
          ?.signalSummaries[BalanceAssessmentSignal.hipCenterX]
          ?.standardDeviation,
      averageSwayStandardDeviation: summary?.averageStandardDeviation,
      stabilityScore: hasSufficientData ? summary?.stabilityScore : null,
    );
  }

  ShoulderMobilityAssessmentResult _buildShoulderMobilityResult() {
    final left = _leftMaximumElevation;
    final right = _rightMaximumElevation;
    return ShoulderMobilityAssessmentResult(
      sampleCount: _shoulderSampleCount,
      hasSufficientData: left != null && right != null,
      leftMaximumElevationDegrees: left,
      rightMaximumElevationDegrees: right,
      sideDifferenceDegrees: left == null || right == null
          ? null
          : (left - right).abs(),
      torsoInclinationAtLeftMaximumDegrees: _torsoAtLeftMaximum,
      torsoInclinationAtRightMaximumDegrees: _torsoAtRightMaximum,
    );
  }

  AssessmentSnapshot _buildSnapshot() {
    final sampleCount = switch (type) {
      AssessmentType.squat => _squatSampleCount,
      AssessmentType.balance =>
        _balanceStability.currentWindowSummary?.sampleCount ??
            (_result is BalanceAssessmentResult ? _result!.sampleCount : 0),
      AssessmentType.shoulderMobility => _shoulderSampleCount,
    };

    return AssessmentSnapshot(
      type: type,
      phase: _phase,
      sampleCount: sampleCount,
      result: _result,
    );
  }

  void _clearAccumulators() {
    _squatSampleCount = 0;
    _deepestSquat = null;
    _balanceRejectedSampleCount = 0;
    _balanceFirstCapturedAt = null;
    _balanceLastCapturedAt = null;
    _shoulderSampleCount = 0;
    _leftMaximumElevation = null;
    _rightMaximumElevation = null;
    _torsoAtLeftMaximum = null;
    _torsoAtRightMaximum = null;
  }
}
