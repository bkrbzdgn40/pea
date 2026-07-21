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

/// Stable, high-level metric identifiers declared by an exercise.
///
/// The Day 2 Metric Registry will own concrete metric definitions. Day 1 keeps
/// only the exercise-to-metric declaration here so the catalog is already the
/// single capability source.
enum ExerciseMetricId {
  repetitionCount,
  holdDuration,
  primaryMovement,
  form,
  rangeOfMotion,
  tempo,
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
  sessionDuration,
}
