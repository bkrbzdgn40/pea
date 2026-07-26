import 'exercise_setup_contract.dart';
import 'exercise_type.dart';

/// Semantic joints consumed by preparation start-pose evaluation.
enum SetupStartPoseJoint {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex,
}

/// Exercise-independent start-pose checks shared by related movement families.
enum SetupStartPoseCheck {
  uprightTorso,
  horizontalTorso,
  straightBodyLine,
  kneesExtended,
  kneesBent,
  armsDown,
  armsExtended,
  elbowsBent,
  splitStance,
  feetTogether,
  supportUnderShoulders,
  hollowCompression,
  wallSitDepth,
  dipSupport,
}

/// Outcome of one start-pose check.
enum SetupStartPoseCheckOutcome { unavailable, failed, passed }

/// Highest-level start-pose result for one preparation frame.
enum SetupStartPoseStatus { insufficientEvidence, notMatched, matched }

/// A pose point normalized with one shared image scale.
class SetupStartPosePoint {
  SetupStartPosePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  }) {
    if (!x.isFinite || !y.isFinite || !z.isFinite || !likelihood.isFinite) {
      throw ArgumentError('Setup start-pose points must be finite.');
    }
    if (likelihood < 0 || likelihood > 1) {
      throw ArgumentError.value(
        likelihood,
        'likelihood',
        'Landmark likelihood must be between zero and one.',
      );
    }
  }

  final double x;
  final double y;
  final double z;
  final double likelihood;

  bool isConfident(double minimumLikelihood) {
    return likelihood >= minimumLikelihood;
  }
}

/// Landmark set used by the pure start-pose evaluator.
class SetupStartPose {
  SetupStartPose({
    required Map<SetupStartPoseJoint, SetupStartPosePoint> points,
  }) : points = Map<SetupStartPoseJoint, SetupStartPosePoint>.unmodifiable(
         points,
       );

  final Map<SetupStartPoseJoint, SetupStartPosePoint> points;

  SetupStartPosePoint? pointFor(SetupStartPoseJoint joint) => points[joint];
}

/// Exercise-aware set of start-pose checks.
class SetupStartPoseContract {
  SetupStartPoseContract({
    required this.exerciseType,
    required this.family,
    required Set<SetupStartPoseCheck> checks,
  }) : checks = Set<SetupStartPoseCheck>.unmodifiable(checks) {
    if (this.checks.isEmpty) {
      throw ArgumentError.value(
        checks,
        'checks',
        'A start-pose contract must contain at least one check.',
      );
    }
  }

  final ExerciseType exerciseType;
  final StartPoseFamily family;
  final Set<SetupStartPoseCheck> checks;
}

/// Result of one check, including conservative diagnostic confidence.
class SetupStartPoseCheckResult {
  const SetupStartPoseCheckResult({
    required this.check,
    required this.outcome,
    required this.confidence,
    this.observedValue,
  });

  final SetupStartPoseCheck check;
  final SetupStartPoseCheckOutcome outcome;
  final double confidence;
  final double? observedValue;
}

/// Full start-pose diagnostic produced for one preparation frame.
class SetupStartPoseAssessment {
  SetupStartPoseAssessment({
    required this.contract,
    required this.status,
    required Map<SetupStartPoseCheck, SetupStartPoseCheckResult> results,
    required this.confidence,
  }) : results =
           Map<SetupStartPoseCheck, SetupStartPoseCheckResult>.unmodifiable(
             results,
           );

  final SetupStartPoseContract contract;
  final SetupStartPoseStatus status;
  final Map<SetupStartPoseCheck, SetupStartPoseCheckResult> results;
  final double confidence;

  Set<SetupStartPoseCheck> get passedChecks =>
      _checksWith(SetupStartPoseCheckOutcome.passed);

  Set<SetupStartPoseCheck> get failedChecks =>
      _checksWith(SetupStartPoseCheckOutcome.failed);

  Set<SetupStartPoseCheck> get unavailableChecks =>
      _checksWith(SetupStartPoseCheckOutcome.unavailable);

  bool get isMatched => status == SetupStartPoseStatus.matched;

  Set<SetupStartPoseCheck> _checksWith(SetupStartPoseCheckOutcome outcome) {
    return Set<SetupStartPoseCheck>.unmodifiable(
      results.entries
          .where((entry) => entry.value.outcome == outcome)
          .map((entry) => entry.key),
    );
  }
}
