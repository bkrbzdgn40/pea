import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

WorkoutSession buildWorkoutSession({
  required String id,
  required DateTime startedAt,
  String ownerId = 'owner-1',
  String exerciseType = 'squat',
  String analysisKind = 'rangeRep',
  int totalReps = 0,
  double averageScore = 0,
  double? bestScore,
  int durationSec = 600,
  PreparationOutcome preparationOutcome = PreparationOutcome.legacyUnknown,
  SessionMeasurementQuality measurementQuality =
      SessionMeasurementQuality.unknown,
  double? averageMeasurementConfidence,
  int measurementSampleCount = 0,
}) {
  return WorkoutSession(
    id: id,
    ownerId: ownerId,
    exerciseType: exerciseType,
    analysisKind: analysisKind,
    startedAt: startedAt,
    endedAt: startedAt.add(Duration(seconds: durationSec)),
    durationSec: durationSec,
    totalReps: totalReps,
    averageScore: averageScore,
    bestScore: bestScore ?? averageScore,
    worstScore: averageScore > 0 ? averageScore : 0,
    validReps: totalReps,
    invalidReps: 0,
    formWarningCount: 0,
    preparationOutcome: preparationOutcome,
    measurementQuality: measurementQuality,
    averageMeasurementConfidence: averageMeasurementConfidence,
    measurementSampleCount: measurementSampleCount,
  );
}

DateTime startOfCurrentWeek(DateTime now) {
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  return today.subtract(Duration(days: localNow.weekday - 1));
}

DateTime startOfNextWeek(DateTime now) {
  return startOfCurrentWeek(now).add(const Duration(days: 7));
}
