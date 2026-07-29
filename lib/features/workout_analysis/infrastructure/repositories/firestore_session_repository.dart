import '../../domain/models/workout_rep.dart';
import '../../application/repositories/session_repository.dart';
import '../../domain/models/workout_session.dart';
import '../remote/firestore_session_remote_source.dart';

/// Firestore-backed implementation that keeps storage details in infrastructure.
class FirestoreSessionRepository implements SessionRepository {
  const FirestoreSessionRepository(this._remoteSource);

  final FirestoreSessionRemoteSource _remoteSource;

  @override
  Future<void> saveSession(WorkoutSession session) {
    return _remoteSource.saveSession(session);
  }

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) {
    return _remoteSource.getSessionById(ownerId: ownerId, sessionId: sessionId);
  }

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) {
    return _remoteSource.listSessionReps(
      ownerId: ownerId,
      sessionId: sessionId,
    );
  }

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) {
    return _remoteSource.listSessions(
      ownerId: ownerId,
      limit: limit,
      exerciseType: exerciseType,
      startAfter: startAfter,
    );
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) {
    return _remoteSource.deleteSession(ownerId: ownerId, sessionId: sessionId);
  }

  @override
  Future<void> deleteAllSessions({required String ownerId}) {
    return _remoteSource.deleteAllSessions(ownerId: ownerId);
  }
}
