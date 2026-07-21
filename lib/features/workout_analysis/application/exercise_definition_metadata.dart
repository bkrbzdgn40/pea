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
