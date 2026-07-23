import '../domain/models/exercise_config.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_side.dart';
import '../domain/models/range_rep_contract.dart';
import 'engine_kind.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';

/// Immutable landmark requirements prepared once for a workout analysis build.
///
/// Exercise config and analysis contracts stay constant for the lifetime of a
/// controller build. Resolving their landmark sets per detected pose creates
/// avoidable sets, lists, triplets, and segments on the frame hot path.
class PreparedExerciseAnalysisContext {
  const PreparedExerciseAnalysisContext._({
    required this.engineKind,
    required this.rangeRepContract,
    required this.holdContract,
    required this.leftRangeRepPoseAcceptance,
    required this.rightRangeRepPoseAcceptance,
    required this.bilateralRangeRepPoseAcceptance,
    required this.leftHoldPoseAcceptance,
    required this.rightHoldPoseAcceptance,
  });

  factory PreparedExerciseAnalysisContext.resolve({
    required ExerciseConfig config,
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    HoldContract? holdContract,
    ExerciseLandmarkRequirements requirements =
        const ExerciseLandmarkRequirements(),
  }) {
    switch (engineKind) {
      case EngineKind.rangeRep:
        final left = requirements.resolve(
          config: config,
          engineKind: engineKind,
          rangeRepContract: rangeRepContract,
          rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
          side: RangeRepSide.left,
        );
        final right = requirements.resolve(
          config: config,
          engineKind: engineKind,
          rangeRepContract: rangeRepContract,
          rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
          side: RangeRepSide.right,
        );
        final bilateral =
            rangeRepContract?.sideMode == RangeRepSideMode.bilateral
            ? requirements.resolve(
                config: config,
                engineKind: engineKind,
                rangeRepContract: rangeRepContract,
                rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
              )
            : null;

        return PreparedExerciseAnalysisContext._(
          engineKind: engineKind,
          rangeRepContract: rangeRepContract,
          holdContract: null,
          leftRangeRepPoseAcceptance: left,
          rightRangeRepPoseAcceptance: right,
          bilateralRangeRepPoseAcceptance: bilateral,
          leftHoldPoseAcceptance: null,
          rightHoldPoseAcceptance: null,
        );
      case EngineKind.hold:
        final left = requirements.resolve(
          config: config,
          engineKind: engineKind,
          holdContract: holdContract,
          holdSide: HoldSide.left,
        );
        final right = requirements.resolve(
          config: config,
          engineKind: engineKind,
          holdContract: holdContract,
          holdSide: HoldSide.right,
        );

        return PreparedExerciseAnalysisContext._(
          engineKind: engineKind,
          rangeRepContract: null,
          holdContract: holdContract,
          leftRangeRepPoseAcceptance: null,
          rightRangeRepPoseAcceptance: null,
          bilateralRangeRepPoseAcceptance: null,
          leftHoldPoseAcceptance: left,
          rightHoldPoseAcceptance: right,
        );
      case EngineKind.alternatingRep:
        return PreparedExerciseAnalysisContext._(
          engineKind: engineKind,
          rangeRepContract: rangeRepContract,
          holdContract: holdContract,
          leftRangeRepPoseAcceptance: null,
          rightRangeRepPoseAcceptance: null,
          bilateralRangeRepPoseAcceptance: null,
          leftHoldPoseAcceptance: null,
          rightHoldPoseAcceptance: null,
        );
    }
  }

  final EngineKind engineKind;
  final RangeRepContract? rangeRepContract;
  final HoldContract? holdContract;
  final ExerciseLandmarkRequirementSet? leftRangeRepPoseAcceptance;
  final ExerciseLandmarkRequirementSet? rightRangeRepPoseAcceptance;
  final ExerciseLandmarkRequirementSet? bilateralRangeRepPoseAcceptance;
  final ExerciseLandmarkRequirementSet? leftHoldPoseAcceptance;
  final ExerciseLandmarkRequirementSet? rightHoldPoseAcceptance;

  ExerciseLandmarkRequirementSet rangeRepPoseAcceptanceFor(RangeRepSide side) {
    final requirementSet = switch (side) {
      RangeRepSide.left => leftRangeRepPoseAcceptance,
      RangeRepSide.right => rightRangeRepPoseAcceptance,
    };
    if (engineKind != EngineKind.rangeRep || requirementSet == null) {
      throw StateError(
        'Range-rep pose-acceptance requirements are unavailable for '
        '${engineKind.name}.',
      );
    }
    return requirementSet;
  }

  ExerciseLandmarkRequirementSet bilateralRangeRepPoseAcceptanceOrThrow() {
    final requirementSet = bilateralRangeRepPoseAcceptance;
    if (engineKind != EngineKind.rangeRep || requirementSet == null) {
      throw StateError(
        'Bilateral range-rep pose-acceptance requirements are unavailable.',
      );
    }
    return requirementSet;
  }

  ExerciseLandmarkRequirementSet holdPoseAcceptanceFor(HoldSide side) {
    final requirementSet = switch (side) {
      HoldSide.left => leftHoldPoseAcceptance,
      HoldSide.right => rightHoldPoseAcceptance,
    };
    if (engineKind != EngineKind.hold || requirementSet == null) {
      throw StateError(
        'Hold pose-acceptance requirements are unavailable for '
        '${engineKind.name}.',
      );
    }
    return requirementSet;
  }
}
