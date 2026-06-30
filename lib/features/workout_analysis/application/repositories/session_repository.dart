import '../../domain/models/workout_session.dart';

abstract interface class SessionRepository {
  Future<void> saveSession(WorkoutSession session);

  Future<WorkoutSession?> getSessionById({
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
}
