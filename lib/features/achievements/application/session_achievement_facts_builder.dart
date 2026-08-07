import '../../workout_analysis/application/exercise_definition_metadata.dart';
import '../../workout_analysis/domain/models/exercise_type.dart';
import '../../workout_analysis/domain/models/session_measurement_evidence.dart';
import '../../workout_analysis/domain/models/workout_session.dart';
import '../domain/models/achievement_body_region.dart';
import '../domain/models/achievement_facts.dart';

class SessionAchievementFactsBuilder {
  const SessionAchievementFactsBuilder();

  AchievementFacts build(Iterable<WorkoutSession> sessions) {
    final reliableSessionIds = <String>{};
    final reliableExerciseTypes = <ExerciseType>{};
    final reliableBodyRegions = <AchievementBodyRegion>{};

    for (final session in sessions) {
      if (!_isReliableCompletedSession(session)) {
        continue;
      }
      final exerciseType = ExerciseType.fromIdOrNull(session.exerciseType);
      if (exerciseType == null) {
        continue;
      }
      reliableSessionIds.add(session.id);
      reliableExerciseTypes.add(exerciseType);
      reliableBodyRegions.add(_achievementRegion(exerciseType.bodyRegion));
    }

    return AchievementFacts(
      reliableSessionIds: reliableSessionIds,
      reliableExerciseTypes: reliableExerciseTypes,
      reliableBodyRegions: reliableBodyRegions,
    );
  }

  bool _isReliableCompletedSession(WorkoutSession session) {
    final hasTrustedEvidence =
        session.measurementQuality == SessionMeasurementQuality.high ||
        session.measurementQuality == SessionMeasurementQuality.moderate;
    if (!hasTrustedEvidence) {
      return false;
    }
    if (session.isHoldSession) {
      return session.totalHoldSeconds >= 5;
    }
    return session.validReps >= 1;
  }

  AchievementBodyRegion _achievementRegion(ExerciseBodyRegion region) {
    return switch (region) {
      ExerciseBodyRegion.lowerBody => AchievementBodyRegion.lowerBody,
      ExerciseBodyRegion.upperBody => AchievementBodyRegion.upperBody,
      ExerciseBodyRegion.core => AchievementBodyRegion.core,
      ExerciseBodyRegion.fullBody => AchievementBodyRegion.fullBody,
    };
  }
}
