import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/measurement_confidence_breakdown.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';
import 'prepared_exercise_analysis_context.dart';
import 'side_plank_support_stacking_measurement.dart';

enum PoseRejectionReason {
  missingRequiredLandmark,
  lowLandmarkLikelihood,
  lowMeanLikelihood,
  nonFiniteCoordinate,
  degenerateGeometry,
}

extension PoseRejectionReasonX on PoseRejectionReason {
  String get code {
    switch (this) {
      case PoseRejectionReason.missingRequiredLandmark:
        return 'missing_required_landmark';
      case PoseRejectionReason.lowLandmarkLikelihood:
        return 'low_landmark_likelihood';
      case PoseRejectionReason.lowMeanLikelihood:
        return 'low_mean_likelihood';
      case PoseRejectionReason.nonFiniteCoordinate:
        return 'non_finite_coordinate';
      case PoseRejectionReason.degenerateGeometry:
        return 'degenerate_geometry';
    }
  }

  bool get isLowConfidence {
    return this == PoseRejectionReason.lowLandmarkLikelihood ||
        this == PoseRejectionReason.lowMeanLikelihood;
  }

  bool get isGeometryFailure {
    return this == PoseRejectionReason.nonFiniteCoordinate ||
        this == PoseRejectionReason.degenerateGeometry;
  }
}

class PoseQualityAssessment {
  PoseQualityAssessment({
    required this.isAccepted,
    required this.minimumRequiredLikelihood,
    required this.meanRequiredLikelihood,
    required this.requiredLandmarkCount,
    required this.acceptedLandmarkCount,
    required this.qualityScore,
    this.rejectionReason,
    Set<RangeRepSide> acceptedRangeRepSides = const <RangeRepSide>{},
    Map<RangeRepSide, MeasurementConfidenceBreakdown>
        rangeRepMeasurementConfidenceSeeds =
        const <RangeRepSide, MeasurementConfidenceBreakdown>{},
    this.preferredRangeRepSide,
    Set<HoldSide> acceptedHoldSides = const <HoldSide>{},
    this.preferredHoldSide,
  }) : acceptedRangeRepSides = Set<RangeRepSide>.unmodifiable(
         acceptedRangeRepSides,
       ),
       rangeRepMeasurementConfidenceSeeds =
           Map<RangeRepSide, MeasurementConfidenceBreakdown>.unmodifiable(
             rangeRepMeasurementConfidenceSeeds,
           ),
       acceptedHoldSides = Set<HoldSide>.unmodifiable(acceptedHoldSides);

  final bool isAccepted;
  final PoseRejectionReason? rejectionReason;
  final double? minimumRequiredLikelihood;
  final double? meanRequiredLikelihood;
  final int requiredLandmarkCount;
  final int acceptedLandmarkCount;
  final Set<RangeRepSide> acceptedRangeRepSides;
  final Map<RangeRepSide, MeasurementConfidenceBreakdown>
  rangeRepMeasurementConfidenceSeeds;
  final RangeRepSide? preferredRangeRepSide;
  final Set<HoldSide> acceptedHoldSides;
  final HoldSide? preferredHoldSide;
  final double qualityScore;

  RangeRepSide? get acceptedSide => preferredRangeRepSide;

  MeasurementConfidenceBreakdown? rangeRepMeasurementConfidenceFor(
    RangeRepSide side,
  ) {
    return rangeRepMeasurementConfidenceSeeds[side];
  }

  PoseQualityAssessment rejectedWith({
    required PoseRejectionReason rejectionReason,
    required int acceptedLandmarkCount,
    double? minimumRequiredLikelihood,
    double? meanRequiredLikelihood,
  }) {
    return PoseQualityAssessment(
      isAccepted: false,
      rejectionReason: rejectionReason,
      minimumRequiredLikelihood: minimumRequiredLikelihood,
      meanRequiredLikelihood: meanRequiredLikelihood,
      requiredLandmarkCount: requiredLandmarkCount,
      acceptedLandmarkCount: acceptedLandmarkCount,
      acceptedRangeRepSides: acceptedRangeRepSides,
      rangeRepMeasurementConfidenceSeeds: rangeRepMeasurementConfidenceSeeds,
      preferredRangeRepSide: preferredRangeRepSide,
      acceptedHoldSides: acceptedHoldSides,
      preferredHoldSide: preferredHoldSide,
      qualityScore: qualityScore,
    );
  }
}

/// Exercise-aware detector pose gate for runtime-safe analysis input.
class PoseQualityPolicy {
  const PoseQualityPolicy({
    ExerciseLandmarkRequirements requirements =
        const ExerciseLandmarkRequirements(),
  }) : _requirements = requirements;

  static const double minimumRequiredLandmarkLikelihood = 0.50;
  static const double minimumMeanRequiredLandmarkLikelihood = 0.65;
  static const double _degenerateDistanceEpsilon = 1e-3;

  final ExerciseLandmarkRequirements _requirements;

  /// Applies the shared runtime pose-quality gate to an explicit landmark
  /// requirement set. This keeps non-exercise flows, such as assessment mode,
  /// on the same confidence and geometry semantics as workout analysis.
  PoseQualityAssessment assessRequirementSet({
    required Pose pose,
    required ExerciseLandmarkRequirementSet requirementSet,
    RangeRepSide? side,
    HoldSide? holdSide,
  }) {
    return _assessRequirementSet(
      pose: pose,
      requirementSet: requirementSet,
      side: side,
      holdSide: holdSide,
    );
  }

  PoseQualityAssessment assess({
    required Pose pose,
    required ExerciseConfig config,
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    HoldContract? holdContract,
    HoldSide? requiredHoldSide,
  }) {
    final preparedContext = PreparedExerciseAnalysisContext.resolve(
      config: config,
      engineKind: engineKind,
      rangeRepContract: rangeRepContract,
      holdContract: holdContract,
      requirements: _requirements,
    );
    return assessPrepared(
      pose: pose,
      config: config,
      preparedContext: preparedContext,
      requiredHoldSide: requiredHoldSide,
    );
  }

  /// Applies pose-quality checks using landmark requirements prepared once for
  /// the current analysis build.
  PoseQualityAssessment assessPrepared({
    required Pose pose,
    required ExerciseConfig config,
    required PreparedExerciseAnalysisContext preparedContext,
    HoldSide? requiredHoldSide,
  }) {
    switch (preparedContext.engineKind) {
      case EngineKind.rangeRep:
        if (requiredHoldSide != null) {
          throw StateError(
            'requiredHoldSide is only valid for hold pose-quality assessment.',
          );
        }
        if (preparedContext.rangeRepContract?.sideMode ==
            RangeRepSideMode.bilateral) {
          return _assessBilateralRangeRep(
            pose: pose,
            requirementSet: preparedContext
                .bilateralRangeRepPoseAcceptanceOrThrow(),
          );
        }
        final leftAssessment = _assessRequirementSet(
          pose: pose,
          side: RangeRepSide.left,
          requirementSet: preparedContext.rangeRepPoseAcceptanceFor(
            RangeRepSide.left,
          ),
        );
        final rightAssessment = _assessRequirementSet(
          pose: pose,
          side: RangeRepSide.right,
          requirementSet: preparedContext.rangeRepPoseAcceptanceFor(
            RangeRepSide.right,
          ),
        );
        return _combineRangeRepAssessments(
          leftAssessment: leftAssessment,
          rightAssessment: rightAssessment,
        );
      case EngineKind.hold:
        if (requiredHoldSide != null) {
          return _assessRequirementSet(
            pose: pose,
            holdSide: requiredHoldSide,
            requirementSet: preparedContext.holdPoseAcceptanceFor(
              requiredHoldSide,
            ),
          );
        }

        final leftAssessment = _assessRequirementSet(
          pose: pose,
          holdSide: HoldSide.left,
          requirementSet: preparedContext.holdPoseAcceptanceFor(HoldSide.left),
        );
        final rightAssessment = _assessRequirementSet(
          pose: pose,
          holdSide: HoldSide.right,
          requirementSet: preparedContext.holdPoseAcceptanceFor(HoldSide.right),
        );
        if (preparedContext.holdContract?.family ==
            HoldAnalysisFamily.sidePlank) {
          return _combineSidePlankHoldAssessments(
            pose: pose,
            config: config,
            leftAssessment: leftAssessment,
            rightAssessment: rightAssessment,
          );
        }
        return _combineHoldAssessments(
          leftAssessment: leftAssessment,
          rightAssessment: rightAssessment,
        );
      case EngineKind.alternatingRep:
        return PoseQualityAssessment(
          isAccepted: true,
          minimumRequiredLikelihood: null,
          meanRequiredLikelihood: null,
          requiredLandmarkCount: 0,
          acceptedLandmarkCount: 0,
          qualityScore: 0.0,
        );
    }
  }

  PoseQualityAssessment _assessBilateralRangeRep({
    required Pose pose,
    required ExerciseLandmarkRequirementSet requirementSet,
  }) {
    final bilateralAssessment = _assessRequirementSet(
      pose: pose,
      requirementSet: requirementSet,
    );

    final bilateralSeed = _measurementConfidenceSeed(
      isAccepted: bilateralAssessment.isAccepted,
      rejectionReason: bilateralAssessment.rejectionReason,
      minimumRequiredLikelihood: bilateralAssessment.minimumRequiredLikelihood,
      requiredLandmarkCount: bilateralAssessment.requiredLandmarkCount,
    );

    return PoseQualityAssessment(
      isAccepted: bilateralAssessment.isAccepted,
      rejectionReason: bilateralAssessment.rejectionReason,
      minimumRequiredLikelihood: bilateralAssessment.minimumRequiredLikelihood,
      meanRequiredLikelihood: bilateralAssessment.meanRequiredLikelihood,
      requiredLandmarkCount: bilateralAssessment.requiredLandmarkCount,
      acceptedLandmarkCount: bilateralAssessment.acceptedLandmarkCount,
      qualityScore: bilateralAssessment.qualityScore,
      acceptedRangeRepSides: bilateralAssessment.isAccepted
          ? const <RangeRepSide>{RangeRepSide.left, RangeRepSide.right}
          : const <RangeRepSide>{},
      rangeRepMeasurementConfidenceSeeds:
          <RangeRepSide, MeasurementConfidenceBreakdown>{
            RangeRepSide.left: bilateralSeed,
            RangeRepSide.right: bilateralSeed,
          },
    );
  }

  PoseQualityAssessment _combineRangeRepAssessments({
    required PoseQualityAssessment leftAssessment,
    required PoseQualityAssessment rightAssessment,
  }) {
    final assessments = <PoseQualityAssessment>[
      leftAssessment,
      rightAssessment,
    ];
    final acceptedAssessments = assessments
        .where((assessment) => assessment.isAccepted)
        .toList(growable: false);

    if (acceptedAssessments.isNotEmpty) {
      final preferredAssessment = acceptedAssessments.reduce(
        _preferHigherQuality,
      );
      final acceptedSides = acceptedAssessments
          .map((assessment) => assessment.acceptedSide)
          .whereType<RangeRepSide>()
          .toSet();

      return PoseQualityAssessment(
        isAccepted: true,
        minimumRequiredLikelihood:
            preferredAssessment.minimumRequiredLikelihood,
        meanRequiredLikelihood: preferredAssessment.meanRequiredLikelihood,
        requiredLandmarkCount: preferredAssessment.requiredLandmarkCount,
        acceptedLandmarkCount: preferredAssessment.acceptedLandmarkCount,
        qualityScore: preferredAssessment.qualityScore,
        acceptedRangeRepSides: acceptedSides,
        rangeRepMeasurementConfidenceSeeds:
            <RangeRepSide, MeasurementConfidenceBreakdown>{
              ...leftAssessment.rangeRepMeasurementConfidenceSeeds,
              ...rightAssessment.rangeRepMeasurementConfidenceSeeds,
            },
        preferredRangeRepSide: preferredAssessment.acceptedSide,
      );
    }

    final bestRejectedAssessment = assessments.reduce(_preferHigherQuality);
    return PoseQualityAssessment(
      isAccepted: false,
      rejectionReason: bestRejectedAssessment.rejectionReason,
      minimumRequiredLikelihood:
          bestRejectedAssessment.minimumRequiredLikelihood,
      meanRequiredLikelihood: bestRejectedAssessment.meanRequiredLikelihood,
      requiredLandmarkCount: bestRejectedAssessment.requiredLandmarkCount,
      acceptedLandmarkCount: bestRejectedAssessment.acceptedLandmarkCount,
      qualityScore: bestRejectedAssessment.qualityScore,
      rangeRepMeasurementConfidenceSeeds:
          <RangeRepSide, MeasurementConfidenceBreakdown>{
            ...leftAssessment.rangeRepMeasurementConfidenceSeeds,
            ...rightAssessment.rangeRepMeasurementConfidenceSeeds,
          },
      preferredRangeRepSide: bestRejectedAssessment.acceptedSide,
    );
  }

  PoseQualityAssessment _preferHigherQuality(
    PoseQualityAssessment current,
    PoseQualityAssessment candidate,
  ) {
    if (candidate.qualityScore > current.qualityScore) {
      return candidate;
    }
    if (candidate.qualityScore < current.qualityScore) {
      return current;
    }

    if (candidate.acceptedLandmarkCount > current.acceptedLandmarkCount) {
      return candidate;
    }
    if (candidate.acceptedLandmarkCount < current.acceptedLandmarkCount) {
      return current;
    }

    if (current.acceptedSide == RangeRepSide.left &&
        candidate.acceptedSide == RangeRepSide.right) {
      return current;
    }
    return candidate;
  }

  PoseQualityAssessment _combineSidePlankHoldAssessments({
    required Pose pose,
    required ExerciseConfig config,
    required PoseQualityAssessment leftAssessment,
    required PoseQualityAssessment rightAssessment,
  }) {
    final assessments = <PoseQualityAssessment>[
      leftAssessment,
      rightAssessment,
    ];
    final acceptedAssessments = assessments
        .where((assessment) => assessment.isAccepted)
        .toList(growable: false);

    if (acceptedAssessments.isEmpty) {
      return _combineHoldAssessments(
        leftAssessment: leftAssessment,
        rightAssessment: rightAssessment,
      );
    }

    const stackingMeasurement = SidePlankSupportStackingMeasurement();
    final referenceSide = config.holdSignals?.referenceSide ?? HoldSide.left;
    PoseQualityAssessment preferredAssessment = acceptedAssessments.first;
    double? preferredStacking = stackingMeasurement.measure(
      pose,
      side: preferredAssessment.preferredHoldSide!,
      referenceSide: referenceSide,
    );

    for (final candidate in acceptedAssessments.skip(1)) {
      final candidateStacking = stackingMeasurement.measure(
        pose,
        side: candidate.preferredHoldSide!,
        referenceSide: referenceSide,
      );
      if (candidateStacking != null &&
          (preferredStacking == null ||
              candidateStacking > preferredStacking)) {
        preferredAssessment = candidate;
        preferredStacking = candidateStacking;
        continue;
      }
      if (candidateStacking == preferredStacking) {
        preferredAssessment = _preferHigherQualityHold(
          preferredAssessment,
          candidate,
        );
      }
    }

    final acceptedSides = acceptedAssessments
        .map((assessment) => assessment.preferredHoldSide)
        .whereType<HoldSide>()
        .toSet();

    return PoseQualityAssessment(
      isAccepted: true,
      minimumRequiredLikelihood: preferredAssessment.minimumRequiredLikelihood,
      meanRequiredLikelihood: preferredAssessment.meanRequiredLikelihood,
      requiredLandmarkCount: preferredAssessment.requiredLandmarkCount,
      acceptedLandmarkCount: preferredAssessment.acceptedLandmarkCount,
      qualityScore: preferredAssessment.qualityScore,
      acceptedHoldSides: acceptedSides,
      preferredHoldSide: preferredAssessment.preferredHoldSide,
    );
  }

  PoseQualityAssessment _combineHoldAssessments({
    required PoseQualityAssessment leftAssessment,
    required PoseQualityAssessment rightAssessment,
  }) {
    final assessments = <PoseQualityAssessment>[
      leftAssessment,
      rightAssessment,
    ];
    final acceptedAssessments = assessments
        .where((assessment) => assessment.isAccepted)
        .toList(growable: false);

    if (acceptedAssessments.isNotEmpty) {
      final preferredAssessment = acceptedAssessments.reduce(
        _preferHigherQualityHold,
      );
      final acceptedSides = acceptedAssessments
          .map((assessment) => assessment.preferredHoldSide)
          .whereType<HoldSide>()
          .toSet();

      return PoseQualityAssessment(
        isAccepted: true,
        minimumRequiredLikelihood:
            preferredAssessment.minimumRequiredLikelihood,
        meanRequiredLikelihood: preferredAssessment.meanRequiredLikelihood,
        requiredLandmarkCount: preferredAssessment.requiredLandmarkCount,
        acceptedLandmarkCount: preferredAssessment.acceptedLandmarkCount,
        qualityScore: preferredAssessment.qualityScore,
        acceptedHoldSides: acceptedSides,
        preferredHoldSide: preferredAssessment.preferredHoldSide,
      );
    }

    final bestRejectedAssessment = assessments.reduce(_preferHigherQualityHold);
    return PoseQualityAssessment(
      isAccepted: false,
      rejectionReason: bestRejectedAssessment.rejectionReason,
      minimumRequiredLikelihood:
          bestRejectedAssessment.minimumRequiredLikelihood,
      meanRequiredLikelihood: bestRejectedAssessment.meanRequiredLikelihood,
      requiredLandmarkCount: bestRejectedAssessment.requiredLandmarkCount,
      acceptedLandmarkCount: bestRejectedAssessment.acceptedLandmarkCount,
      qualityScore: bestRejectedAssessment.qualityScore,
      preferredHoldSide: bestRejectedAssessment.preferredHoldSide,
    );
  }

  PoseQualityAssessment _preferHigherQualityHold(
    PoseQualityAssessment current,
    PoseQualityAssessment candidate,
  ) {
    if (candidate.qualityScore > current.qualityScore) {
      return candidate;
    }
    if (candidate.qualityScore < current.qualityScore) {
      return current;
    }

    if (candidate.acceptedLandmarkCount > current.acceptedLandmarkCount) {
      return candidate;
    }
    if (candidate.acceptedLandmarkCount < current.acceptedLandmarkCount) {
      return current;
    }

    if (current.preferredHoldSide == HoldSide.left &&
        candidate.preferredHoldSide == HoldSide.right) {
      return current;
    }
    return candidate;
  }

  PoseQualityAssessment _assessRequirementSet({
    required Pose pose,
    required ExerciseLandmarkRequirementSet requirementSet,
    RangeRepSide? side,
    HoldSide? holdSide,
  }) {
    final requiredLandmarkCount = requirementSet.requiredLandmarks.length;
    if (requiredLandmarkCount == 0) {
      return PoseQualityAssessment(
        isAccepted: true,
        minimumRequiredLikelihood: null,
        meanRequiredLikelihood: null,
        requiredLandmarkCount: 0,
        acceptedLandmarkCount: 0,
        acceptedRangeRepSides: side == null
            ? const <RangeRepSide>{}
            : <RangeRepSide>{side},
        rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
          side: side,
          isAccepted: true,
          requiredLandmarkCount: 0,
        ),
        preferredRangeRepSide: side,
        acceptedHoldSides: holdSide == null
            ? const <HoldSide>{}
            : <HoldSide>{holdSide},
        preferredHoldSide: holdSide,
        qualityScore: 0.0,
      );
    }

    var observedLandmarkCount = 0;
    var acceptedLandmarkCount = 0;
    var minimumLikelihood = double.infinity;
    var likelihoodTotal = 0.0;
    PoseLandmark? firstNonFiniteLandmark;

    for (final landmarkType in requirementSet.requiredLandmarks) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark == null) {
        return PoseQualityAssessment(
          isAccepted: false,
          rejectionReason: PoseRejectionReason.missingRequiredLandmark,
          minimumRequiredLikelihood: null,
          meanRequiredLikelihood: null,
          requiredLandmarkCount: requiredLandmarkCount,
          acceptedLandmarkCount: observedLandmarkCount,
          acceptedRangeRepSides: const <RangeRepSide>{},
          rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
            side: side,
            isAccepted: false,
            rejectionReason: PoseRejectionReason.missingRequiredLandmark,
            requiredLandmarkCount: requiredLandmarkCount,
          ),
          preferredRangeRepSide: side,
          acceptedHoldSides: const <HoldSide>{},
          preferredHoldSide: holdSide,
          qualityScore: _qualityScore(
            acceptedLandmarkCount: observedLandmarkCount,
            requiredLandmarkCount: requiredLandmarkCount,
          ),
        );
      }

      observedLandmarkCount += 1;
      final likelihood = landmark.likelihood;
      likelihoodTotal += likelihood;
      minimumLikelihood = math.min(minimumLikelihood, likelihood);
      if (likelihood >= minimumRequiredLandmarkLikelihood) {
        acceptedLandmarkCount += 1;
      }
      if (firstNonFiniteLandmark == null && !_hasFiniteCoordinates(landmark)) {
        firstNonFiniteLandmark = landmark;
      }
    }

    final meanLikelihood = likelihoodTotal / requiredLandmarkCount;
    final nonFiniteLandmark = firstNonFiniteLandmark;
    if (nonFiniteLandmark != null) {
      return PoseQualityAssessment(
        isAccepted: false,
        rejectionReason: PoseRejectionReason.nonFiniteCoordinate,
        minimumRequiredLikelihood: nonFiniteLandmark.likelihood,
        meanRequiredLikelihood: meanLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
        acceptedLandmarkCount: 0,
        acceptedRangeRepSides: const <RangeRepSide>{},
        rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
          side: side,
          isAccepted: false,
          rejectionReason: PoseRejectionReason.nonFiniteCoordinate,
          minimumRequiredLikelihood: nonFiniteLandmark.likelihood,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
        preferredRangeRepSide: side,
        acceptedHoldSides: const <HoldSide>{},
        preferredHoldSide: holdSide,
        qualityScore: _qualityScore(
          acceptedLandmarkCount: 0,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
      );
    }

    if (_hasDegenerateGeometry(pose, requirementSet)) {
      return PoseQualityAssessment(
        isAccepted: false,
        rejectionReason: PoseRejectionReason.degenerateGeometry,
        minimumRequiredLikelihood: minimumLikelihood,
        meanRequiredLikelihood: meanLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
        acceptedLandmarkCount: requiredLandmarkCount,
        acceptedRangeRepSides: const <RangeRepSide>{},
        rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
          side: side,
          isAccepted: false,
          rejectionReason: PoseRejectionReason.degenerateGeometry,
          minimumRequiredLikelihood: minimumLikelihood,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
        preferredRangeRepSide: side,
        acceptedHoldSides: const <HoldSide>{},
        preferredHoldSide: holdSide,
        qualityScore: _qualityScore(
          acceptedLandmarkCount: requiredLandmarkCount,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
      );
    }

    if (minimumLikelihood < minimumRequiredLandmarkLikelihood) {
      return PoseQualityAssessment(
        isAccepted: false,
        rejectionReason: PoseRejectionReason.lowLandmarkLikelihood,
        minimumRequiredLikelihood: minimumLikelihood,
        meanRequiredLikelihood: meanLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
        acceptedLandmarkCount: acceptedLandmarkCount,
        acceptedRangeRepSides: const <RangeRepSide>{},
        rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
          side: side,
          isAccepted: false,
          rejectionReason: PoseRejectionReason.lowLandmarkLikelihood,
          minimumRequiredLikelihood: minimumLikelihood,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
        preferredRangeRepSide: side,
        acceptedHoldSides: const <HoldSide>{},
        preferredHoldSide: holdSide,
        qualityScore: _qualityScore(
          acceptedLandmarkCount: acceptedLandmarkCount,
          requiredLandmarkCount: requiredLandmarkCount,
          minimumLikelihood: minimumLikelihood,
          meanLikelihood: meanLikelihood,
        ),
      );
    }

    if (meanLikelihood < minimumMeanRequiredLandmarkLikelihood) {
      return PoseQualityAssessment(
        isAccepted: false,
        rejectionReason: PoseRejectionReason.lowMeanLikelihood,
        minimumRequiredLikelihood: minimumLikelihood,
        meanRequiredLikelihood: meanLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
        acceptedLandmarkCount: acceptedLandmarkCount,
        acceptedRangeRepSides: const <RangeRepSide>{},
        rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
          side: side,
          isAccepted: false,
          rejectionReason: PoseRejectionReason.lowMeanLikelihood,
          minimumRequiredLikelihood: minimumLikelihood,
          requiredLandmarkCount: requiredLandmarkCount,
        ),
        preferredRangeRepSide: side,
        acceptedHoldSides: const <HoldSide>{},
        preferredHoldSide: holdSide,
        qualityScore: _qualityScore(
          acceptedLandmarkCount: acceptedLandmarkCount,
          requiredLandmarkCount: requiredLandmarkCount,
          minimumLikelihood: minimumLikelihood,
          meanLikelihood: meanLikelihood,
        ),
      );
    }

    return PoseQualityAssessment(
      isAccepted: true,
      minimumRequiredLikelihood: minimumLikelihood,
      meanRequiredLikelihood: meanLikelihood,
      requiredLandmarkCount: requiredLandmarkCount,
      acceptedLandmarkCount: requiredLandmarkCount,
      acceptedRangeRepSides: side == null
          ? const <RangeRepSide>{}
          : <RangeRepSide>{side},
      rangeRepMeasurementConfidenceSeeds: _measurementConfidenceSeedsFor(
        side: side,
        isAccepted: true,
        minimumRequiredLikelihood: minimumLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
      ),
      preferredRangeRepSide: side,
      acceptedHoldSides: holdSide == null
          ? const <HoldSide>{}
          : <HoldSide>{holdSide},
      preferredHoldSide: holdSide,
      qualityScore: _qualityScore(
        acceptedLandmarkCount: requiredLandmarkCount,
        requiredLandmarkCount: requiredLandmarkCount,
        minimumLikelihood: minimumLikelihood,
        meanLikelihood: meanLikelihood,
      ),
    );
  }

  Map<RangeRepSide, MeasurementConfidenceBreakdown>
  _measurementConfidenceSeedsFor({
    required RangeRepSide? side,
    required bool isAccepted,
    required int requiredLandmarkCount,
    PoseRejectionReason? rejectionReason,
    double? minimumRequiredLikelihood,
  }) {
    if (side == null) {
      return const <RangeRepSide, MeasurementConfidenceBreakdown>{};
    }
    return <RangeRepSide, MeasurementConfidenceBreakdown>{
      side: _measurementConfidenceSeed(
        isAccepted: isAccepted,
        rejectionReason: rejectionReason,
        minimumRequiredLikelihood: minimumRequiredLikelihood,
        requiredLandmarkCount: requiredLandmarkCount,
      ),
    };
  }

  MeasurementConfidenceBreakdown _measurementConfidenceSeed({
    required bool isAccepted,
    required int requiredLandmarkCount,
    PoseRejectionReason? rejectionReason,
    double? minimumRequiredLikelihood,
  }) {
    final issues = <MeasurementConfidenceIssue>[
      if (rejectionReason == PoseRejectionReason.missingRequiredLandmark)
        MeasurementConfidenceIssue.missingRequiredLandmark,
      if (rejectionReason == PoseRejectionReason.lowLandmarkLikelihood)
        MeasurementConfidenceIssue.lowLandmarkLikelihood,
      if (rejectionReason == PoseRejectionReason.lowMeanLikelihood)
        MeasurementConfidenceIssue.lowMeanLikelihood,
      if (rejectionReason == PoseRejectionReason.nonFiniteCoordinate)
        MeasurementConfidenceIssue.nonFiniteGeometry,
      if (rejectionReason == PoseRejectionReason.degenerateGeometry)
        MeasurementConfidenceIssue.degenerateGeometry,
    ];

    double? geometryPlausibility;
    if (rejectionReason == PoseRejectionReason.nonFiniteCoordinate ||
        rejectionReason == PoseRejectionReason.degenerateGeometry) {
      geometryPlausibility = 0.0;
    } else if (requiredLandmarkCount > 0 &&
        (isAccepted ||
            rejectionReason == PoseRejectionReason.lowLandmarkLikelihood ||
            rejectionReason == PoseRejectionReason.lowMeanLikelihood)) {
      geometryPlausibility = 1.0;
    }

    return MeasurementConfidenceBreakdown(
      landmarkLikelihood: minimumRequiredLikelihood,
      signalAvailability: null,
      geometryPlausibility: geometryPlausibility,
      temporalContinuity: null,
      combined: null,
      issues: issues,
    );
  }

  bool _hasFiniteCoordinates(PoseLandmark landmark) {
    return landmark.x.isFinite && landmark.y.isFinite && landmark.z.isFinite;
  }

  bool _hasDegenerateGeometry(
    Pose pose,
    ExerciseLandmarkRequirementSet requirementSet,
  ) {
    for (final triplet in requirementSet.requiredAngleTriplets) {
      final first = pose.landmarks[triplet.first];
      final middle = pose.landmarks[triplet.middle];
      final last = pose.landmarks[triplet.last];
      if (first == null || middle == null || last == null) {
        return true;
      }

      if (_pointsNearlyCoincident(first, middle) ||
          _pointsNearlyCoincident(middle, last)) {
        return true;
      }
    }

    for (final segment in requirementSet.requiredSegments) {
      final first = pose.landmarks[segment.first];
      final second = pose.landmarks[segment.second];
      if (first == null || second == null) {
        return true;
      }
      if (_pointsNearlyCoincident(first, second)) {
        return true;
      }
    }

    return false;
  }

  bool _pointsNearlyCoincident(PoseLandmark first, PoseLandmark second) {
    final deltaX = first.x - second.x;
    final deltaY = first.y - second.y;
    final deltaZ = first.z - second.z;
    final squaredDistance = deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ;
    return squaredDistance <=
        _degenerateDistanceEpsilon * _degenerateDistanceEpsilon;
  }

  double _qualityScore({
    required int acceptedLandmarkCount,
    required int requiredLandmarkCount,
    double? minimumLikelihood,
    double? meanLikelihood,
  }) {
    final coverage = requiredLandmarkCount == 0
        ? 1.0
        : acceptedLandmarkCount / requiredLandmarkCount;
    return (coverage * 1000.0) +
        ((meanLikelihood ?? 0.0) * 10.0) +
        (minimumLikelihood ?? 0.0);
  }
}
