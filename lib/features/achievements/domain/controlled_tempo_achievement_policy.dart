import '../../workout_analysis/domain/models/exercise_type.dart';
import '../../workout_analysis/domain/models/session_measurement_evidence.dart';
import '../../workout_analysis/domain/models/workout_rep.dart';
import '../../workout_analysis/domain/models/workout_session.dart';

class ControlledTempoAchievementPolicy {
  const ControlledTempoAchievementPolicy();

  static const Set<ExerciseType> supportedExercises = <ExerciseType>{
    ExerciseType.squat,
    ExerciseType.pushUp,
    ExerciseType.crunch,
    ExerciseType.bicepsCurl,
    ExerciseType.gluteBridge,
    ExerciseType.standingHipExtension,
  };

  bool qualifies({
    required WorkoutSession session,
    required Iterable<WorkoutRep> reps,
  }) {
    if (!_isTrusted(session) || session.analysisKind != 'rangeRep') {
      return false;
    }
    final exerciseType = ExerciseType.fromIdOrNull(session.exerciseType);
    if (exerciseType == null || !supportedExercises.contains(exerciseType)) {
      return false;
    }

    final eligible = reps
        .where((rep) {
          return rep.exerciseType == session.exerciseType &&
              rep.isValidatedAsValid &&
              rep.isTempoMeasurementEligible;
        })
        .toList(growable: false);
    if (eligible.length < 5) {
      return false;
    }
    final targetCount = eligible
        .where((rep) => rep.tempoQuality == 'target')
        .length;
    return targetCount / eligible.length >= 0.8;
  }

  bool _isTrusted(WorkoutSession session) {
    return session.measurementQuality == SessionMeasurementQuality.high ||
        session.measurementQuality == SessionMeasurementQuality.moderate;
  }
}
