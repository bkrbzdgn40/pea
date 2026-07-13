import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_config.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';

class PoseAngleTriplet {
  const PoseAngleTriplet({
    required this.first,
    required this.middle,
    required this.last,
  });

  final PoseLandmarkType first;
  final PoseLandmarkType middle;
  final PoseLandmarkType last;
}

class PoseLandmarkSegment {
  const PoseLandmarkSegment({required this.first, required this.second});

  final PoseLandmarkType first;
  final PoseLandmarkType second;
}

class ExerciseLandmarkRequirementSet {
  const ExerciseLandmarkRequirementSet({
    required this.requiredLandmarks,
    required this.requiredAngleTriplets,
    required this.requiredSegments,
  });

  final Set<PoseLandmarkType> requiredLandmarks;
  final List<PoseAngleTriplet> requiredAngleTriplets;
  final List<PoseLandmarkSegment> requiredSegments;
}

/// Resolves the exercise-aware landmark set shared by quality and metrics logic.
class ExerciseLandmarkRequirements {
  const ExerciseLandmarkRequirements();

  static final RangeRepContract _emptyRangeRepContract = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{},
    supportedSignals: const <RangeRepSignal>{},
  );

  ExerciseLandmarkRequirementSet resolve({
    required ExerciseConfig config,
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    RangeRepSide? side,
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        final resolvedSide = side;
        if (resolvedSide == null) {
          throw ArgumentError.value(
            side,
            'side',
            'Range-rep landmark resolution requires a side.',
          );
        }
        return _resolveRangeRep(
          config,
          resolvedSide,
          rangeRepContract ?? _emptyRangeRepContract,
        );
      case EngineKind.hold:
        return _resolveHold();
      case EngineKind.alternatingRep:
        return const ExerciseLandmarkRequirementSet(
          requiredLandmarks: <PoseLandmarkType>{},
          requiredAngleTriplets: <PoseAngleTriplet>[],
          requiredSegments: <PoseLandmarkSegment>[],
        );
    }
  }

  PoseLandmarkType landmarkTypeForSide(
    PoseLandmarkType landmarkType,
    RangeRepSide side,
  ) {
    if (side == RangeRepSide.left) {
      return landmarkType;
    }

    switch (landmarkType) {
      case PoseLandmarkType.leftShoulder:
        return PoseLandmarkType.rightShoulder;
      case PoseLandmarkType.leftElbow:
        return PoseLandmarkType.rightElbow;
      case PoseLandmarkType.leftWrist:
        return PoseLandmarkType.rightWrist;
      case PoseLandmarkType.leftHip:
        return PoseLandmarkType.rightHip;
      case PoseLandmarkType.leftKnee:
        return PoseLandmarkType.rightKnee;
      case PoseLandmarkType.leftAnkle:
        return PoseLandmarkType.rightAnkle;
      case PoseLandmarkType.rightShoulder:
        return PoseLandmarkType.leftShoulder;
      case PoseLandmarkType.rightElbow:
        return PoseLandmarkType.leftElbow;
      case PoseLandmarkType.rightWrist:
        return PoseLandmarkType.leftWrist;
      case PoseLandmarkType.rightHip:
        return PoseLandmarkType.leftHip;
      case PoseLandmarkType.rightKnee:
        return PoseLandmarkType.leftKnee;
      case PoseLandmarkType.rightAnkle:
        return PoseLandmarkType.leftAnkle;
      default:
        return landmarkType;
    }
  }

  ExerciseLandmarkRequirementSet _resolveRangeRep(
    ExerciseConfig config,
    RangeRepSide side,
    RangeRepContract rangeRepContract,
  ) {
    final requiredLandmarks = <PoseLandmarkType>{};
    final requiredTriplets = <PoseAngleTriplet>[];
    final segmentKeys = <String>{};
    final requiredSegments = <PoseLandmarkSegment>[];

    void addTriplet(
      PoseLandmarkType first,
      PoseLandmarkType middle,
      PoseLandmarkType last,
    ) {
      final triplet = PoseAngleTriplet(
        first: first,
        middle: middle,
        last: last,
      );
      requiredTriplets.add(triplet);
      requiredLandmarks.addAll(<PoseLandmarkType>{first, middle, last});

      void addSegment(PoseLandmarkType start, PoseLandmarkType end) {
        final key = '${start.name}:${end.name}';
        if (segmentKeys.add(key)) {
          requiredSegments.add(PoseLandmarkSegment(first: start, second: end));
        }
      }

      addSegment(first, middle);
      addSegment(middle, last);
    }

    PoseLandmarkType sideLandmark(PoseLandmarkType type) {
      return landmarkTypeForSide(type, side);
    }

    if (rangeRepContract.supportsSignal(RangeRepSignal.primaryMetric)) {
      addTriplet(
        sideLandmark(config.joint1),
        sideLandmark(config.primaryJoint),
        sideLandmark(config.joint2),
      );
    }

    if (rangeRepContract.supportsSignal(RangeRepSignal.formMetric)) {
      _addConfiguredDefinition(
        addTriplet: addTriplet,
        definition: config.resolvedRangeRepSignals?.postureAngle,
        config: config,
        side: side,
      );
    }

    for (final signal in const <RangeRepSignal>[
      RangeRepSignal.postureAngle,
      RangeRepSignal.depthMetric,
      RangeRepSignal.alignmentMetric,
      RangeRepSignal.stabilityMetric,
      RangeRepSignal.endRangeMetric,
      RangeRepSignal.bottomControlMetric,
    ]) {
      if (!rangeRepContract.supportsSignal(signal)) {
        continue;
      }
      _addConfiguredDefinition(
        addTriplet: addTriplet,
        definition: config.resolvedRangeRepSignals?.definitionFor(signal),
        config: config,
        side: side,
      );
    }

    return ExerciseLandmarkRequirementSet(
      requiredLandmarks: Set<PoseLandmarkType>.unmodifiable(requiredLandmarks),
      requiredAngleTriplets: List<PoseAngleTriplet>.unmodifiable(
        requiredTriplets,
      ),
      requiredSegments: List<PoseLandmarkSegment>.unmodifiable(
        requiredSegments,
      ),
    );
  }

  ExerciseLandmarkRequirementSet _resolveHold() {
    const triplets = <PoseAngleTriplet>[
      PoseAngleTriplet(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      PoseAngleTriplet(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      PoseAngleTriplet(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ];

    return const ExerciseLandmarkRequirementSet(
      requiredLandmarks: <PoseLandmarkType>{
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      },
      requiredAngleTriplets: triplets,
      requiredSegments: <PoseLandmarkSegment>[
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftShoulder,
          second: PoseLandmarkType.leftHip,
        ),
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftHip,
          second: PoseLandmarkType.leftAnkle,
        ),
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftShoulder,
          second: PoseLandmarkType.leftElbow,
        ),
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftElbow,
          second: PoseLandmarkType.leftWrist,
        ),
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftHip,
          second: PoseLandmarkType.leftKnee,
        ),
        PoseLandmarkSegment(
          first: PoseLandmarkType.leftKnee,
          second: PoseLandmarkType.leftAnkle,
        ),
      ],
    );
  }

  void _addConfiguredDefinition({
    required void Function(
      PoseLandmarkType first,
      PoseLandmarkType middle,
      PoseLandmarkType last,
    )
    addTriplet,
    required RangeRepSignalDefinition? definition,
    required ExerciseConfig config,
    required RangeRepSide side,
  }) {
    if (definition == null) {
      return;
    }

    final angle = definition.angle;
    if (angle != null) {
      addTriplet(
        landmarkTypeForSide(angle.first, side),
        landmarkTypeForSide(angle.middle, side),
        landmarkTypeForSide(angle.last, side),
      );
      return;
    }

    if (definition.source == RangeRepSignalSource.primaryMetric) {
      addTriplet(
        landmarkTypeForSide(config.joint1, side),
        landmarkTypeForSide(config.primaryJoint, side),
        landmarkTypeForSide(config.joint2, side),
      );
    }
  }
}
