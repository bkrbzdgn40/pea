import '../../domain/models/workout_rep.dart';
import '../../domain/models/workout_session.dart';

/// Repository contract for saving and reading completed workout sessions.
abstract interface class SessionRepository {
  Future<void> saveSession(WorkoutSession session);

  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  });

  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  });

  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  });

  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  });

  Future<void> deleteAllSessions({required String ownerId});
}
