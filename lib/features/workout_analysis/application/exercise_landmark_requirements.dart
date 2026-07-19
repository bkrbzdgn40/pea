import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/exercise_config.dart';
import '../domain/models/analysis_signal_role.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_metrics.dart';
import 'pose_landmark_mirror.dart';

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
    signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{},
  );

  ExerciseLandmarkRequirementSet resolve({
    required ExerciseConfig config,
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    RangeRepSignalSet rangeRepSignalSet = RangeRepSignalSet.supportedAnalysis,
    HoldContract? holdContract,
    RangeRepSide? side,
    HoldSide? holdSide,
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        final contract = rangeRepContract ?? _emptyRangeRepContract;
        final resolvedSide = side;
        if (resolvedSide != null) {
          return _resolveRangeRep(
            config,
            resolvedSide,
            contract,
            rangeRepSignalSet,
          );
        }
        if (contract.sideMode == RangeRepSideMode.bilateral) {
          return _mergeRequirementSets(
            _resolveRangeRep(
              config,
              RangeRepSide.left,
              contract,
              rangeRepSignalSet,
            ),
            _resolveRangeRep(
              config,
              RangeRepSide.right,
              contract,
              rangeRepSignalSet,
            ),
          );
        }
        throw ArgumentError.value(
          side,
          'side',
          'Range-rep landmark resolution requires a side.',
        );
      case EngineKind.hold:
        final requiredHoldContract = holdContract;
        if (requiredHoldContract == null) {
          throw StateError(
            'Hold landmark resolution requires a non-null holdContract.',
          );
        }
        final requiredHoldSide = holdSide;
        if (requiredHoldSide == null) {
          throw StateError(
            'Hold landmark resolution requires a non-null holdSide.',
          );
        }
        return _resolveHold(config, requiredHoldContract, requiredHoldSide);
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
    return resolveRangeRepLandmarkForSide(landmarkType, side);
  }

  ExerciseLandmarkRequirementSet _resolveRangeRep(
    ExerciseConfig config,
    RangeRepSide side,
    RangeRepContract rangeRepContract,
    RangeRepSignalSet rangeRepSignalSet,
  ) {
    final requiredLandmarks = <PoseLandmarkType>{};
    final requiredTriplets = <PoseAngleTriplet>[];
    final segmentKeys = <String>{};
    final requiredSegments = <PoseLandmarkSegment>[];

    void addSegment(PoseLandmarkType start, PoseLandmarkType end) {
      requiredLandmarks.addAll(<PoseLandmarkType>{start, end});
      final key = '${start.name}:${end.name}';
      if (segmentKeys.add(key)) {
        requiredSegments.add(PoseLandmarkSegment(first: start, second: end));
      }
    }

    void addTriplet(
      PoseLandmarkType first,
      PoseLandmarkType middle,
      PoseLandmarkType last,
    ) {
      requiredTriplets.add(
        PoseAngleTriplet(first: first, middle: middle, last: last),
      );
      requiredLandmarks.addAll(<PoseLandmarkType>{first, middle, last});
      addSegment(first, middle);
      addSegment(middle, last);
    }

    PoseLandmarkType sideLandmark(PoseLandmarkType type) {
      return landmarkTypeForSide(type, side);
    }

    bool includesSignal(RangeRepSignal signal) {
      return rangeRepContract.signalsFor(rangeRepSignalSet).contains(signal);
    }

    if (includesSignal(RangeRepSignal.primaryMetric)) {
      switch (rangeRepContract.primaryMetricKind) {
        case RangeRepPrimaryMetricKind.jointAngle:
          addTriplet(
            sideLandmark(config.joint1),
            sideLandmark(config.primaryJoint),
            sideLandmark(config.joint2),
          );
        case RangeRepPrimaryMetricKind.imagePlaneInclination:
          addSegment(
            sideLandmark(config.joint1),
            sideLandmark(config.primaryJoint),
          );
      }
    }

    if (includesSignal(RangeRepSignal.formMetric)) {
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
      if (!includesSignal(signal)) {
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
      requiredSegments: List<PoseLandmarkSegment>.unmodifiable(requiredSegments),
    );
  }

  ExerciseLandmarkRequirementSet _resolveHold(
    ExerciseConfig config,
    HoldContract contract,
    HoldSide holdSide,
  ) {
    final holdSignals = config.holdSignals;
    if (holdSignals == null) {
      throw StateError('Hold landmark resolution requires holdSignals config.');
    }

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

    for (final signal in contract.requiredSignals) {
      final definition = holdSignals.definitionFor(signal);
      if (definition == null) {
        throw StateError(
          'Hold landmark resolution missing ${signal.name} definition.',
        );
      }
      addTriplet(
        resolveHoldLandmarkForSide(
          configuredLandmark: definition.first,
          referenceSide: holdSignals.referenceSide,
          targetSide: holdSide,
        ),
        resolveHoldLandmarkForSide(
          configuredLandmark: definition.middle,
          referenceSide: holdSignals.referenceSide,
          targetSide: holdSide,
        ),
        resolveHoldLandmarkForSide(
          configuredLandmark: definition.last,
          referenceSide: holdSignals.referenceSide,
          targetSide: holdSide,
        ),
      );
    }

    return ExerciseLandmarkRequirementSet(
      requiredLandmarks: Set<PoseLandmarkType>.unmodifiable(requiredLandmarks),
      requiredAngleTriplets: List<PoseAngleTriplet>.unmodifiable(
        requiredTriplets,
      ),
      requiredSegments: List<PoseLandmarkSegment>.unmodifiable(requiredSegments),
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
      switch (rangeRepContractPrimaryMetricKindForConfig(config)) {
        case RangeRepPrimaryMetricKind.jointAngle:
          addTriplet(
            landmarkTypeForSide(config.joint1, side),
            landmarkTypeForSide(config.primaryJoint, side),
            landmarkTypeForSide(config.joint2, side),
          );
        case RangeRepPrimaryMetricKind.imagePlaneInclination:
          // Primary-source secondary signals are not used by the current
          // inclination-backed contract outside primary pose acceptance.
          break;
      }
    }
  }

  RangeRepPrimaryMetricKind rangeRepContractPrimaryMetricKindForConfig(
    ExerciseConfig config,
  ) {
    return RangeRepPrimaryMetricKind.jointAngle;
  }

  ExerciseLandmarkRequirementSet _mergeRequirementSets(
    ExerciseLandmarkRequirementSet first,
    ExerciseLandmarkRequirementSet second,
  ) {
    final requiredSegments = <PoseLandmarkSegment>[];
    final segmentKeys = <String>{};
    for (final segment in <PoseLandmarkSegment>[
      ...first.requiredSegments,
      ...second.requiredSegments,
    ]) {
      final key = '${segment.first.name}:${segment.second.name}';
      if (segmentKeys.add(key)) {
        requiredSegments.add(segment);
      }
    }

    return ExerciseLandmarkRequirementSet(
      requiredLandmarks: Set<PoseLandmarkType>.unmodifiable(<PoseLandmarkType>{
        ...first.requiredLandmarks,
        ...second.requiredLandmarks,
      }),
      requiredAngleTriplets: List<PoseAngleTriplet>.unmodifiable(
        <PoseAngleTriplet>[
          ...first.requiredAngleTriplets,
          ...second.requiredAngleTriplets,
        ],
      ),
      requiredSegments: List<PoseLandmarkSegment>.unmodifiable(requiredSegments),
    );
  }
}
