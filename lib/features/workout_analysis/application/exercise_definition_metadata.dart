import '../domain/models/exercise_type.dart';

/// Canonical movement-pattern families used to describe an exercise without
/// coupling the catalog to a concrete analysis implementation.
enum ExerciseMovementPattern {
  squat,
  coreHold,
  lunge,
  horizontalPush,
  trunkFlexion,
  elbowFlexion,
  hipFlexion,
  kneeFlexion,
  hipAbduction,
  elbowExtension,
  hipHinge,
  shoulderAbduction,
  verticalPush,
  anklePlantarFlexion,
  shoulderFlexion,
  hipExtension,
  squatHold,
  sideCoreHold,
  fullBodyAbduction,
}

/// Product-facing body regions used to browse the exercise catalog.
enum ExerciseBodyRegion { lowerBody, upperBody, core, fullBody }

/// Keeps exercise discovery metadata exhaustive and independent from the
/// runtime analysis implementation.
extension ExerciseBodyRegionMetadata on ExerciseType {
  ExerciseBodyRegion get bodyRegion {
    return switch (this) {
      ExerciseType.squat ||
      ExerciseType.lunge ||
      ExerciseType.standingHamstringCurl ||
      ExerciseType.standingHipAbduction ||
      ExerciseType.romanianDeadlift ||
      ExerciseType.goodMorning ||
      ExerciseType.calfRaise ||
      ExerciseType.gluteBridge ||
      ExerciseType.wallSit ||
      ExerciseType.standingHipExtension ||
      ExerciseType.standingStraightLegRaise ||
      ExerciseType.frogPump => ExerciseBodyRegion.lowerBody,
      ExerciseType.pushUp ||
      ExerciseType.bicepsCurl ||
      ExerciseType.tricepsDip ||
      ExerciseType.lateralRaise ||
      ExerciseType.shoulderPress ||
      ExerciseType.overheadTricepsExtension ||
      ExerciseType.uprightRow ||
      ExerciseType.frontRaise ||
      ExerciseType.lyingTricepsExtension ||
      ExerciseType.floorChestPress ||
      ExerciseType.yRaise => ExerciseBodyRegion.upperBody,
      ExerciseType.plank ||
      ExerciseType.hollowHold ||
      ExerciseType.sitUp ||
      ExerciseType.crunch ||
      ExerciseType.reverseCrunch ||
      ExerciseType.lyingLegRaise ||
      ExerciseType.bentKneeLegRaise ||
      ExerciseType.sidePlank ||
      ExerciseType.standingKneeRaise ||
      ExerciseType.vUp => ExerciseBodyRegion.core,
      ExerciseType.jumpingJack => ExerciseBodyRegion.fullBody,
    };
  }
}

/// Declares whether an exercise is tracked as repetitions or as a timed hold.
enum ExerciseTrackingType { repetitions, hold }

/// Declarative analysis capabilities an exercise can opt into.
///
/// This is intentionally separate from EngineKind, which selects the current
/// primary runtime coordinator. Future supplemental engines can be added to an
/// exercise definition without changing the primary coordinator contract.
enum ExerciseAnalysisEngine {
  rangeRep,
  alternatingRep,
  hold,
  tempo,
  symmetry,
  stability,
}

/// Feedback rule families an exercise declares support for.
///
/// Concrete rule evaluation belongs to the later Form Rule Engine roadmap
/// step. These identifiers only describe the contract today.
enum ExerciseFeedbackRuleId { movementProgress, holdProgress, formCorrection }

/// Fields an exercise expects to expose in its session summary.
enum ExerciseSessionSummaryField {
  repetitionCount,
  validRepetitions,
  invalidRepetitions,
  holdDuration,
  averageScore,
  averageTempo,
  fastestRep,
  slowestRep,
  tempoConsistency,
  asymmetryScore,
  stabilityScore,
  sessionDuration,
}
