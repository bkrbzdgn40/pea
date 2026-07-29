import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/application/repositories/auth_repository.dart';
import 'package:pose_estimation_app/features/auth/domain/models/auth_user.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/user_data_management_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  test('deleteAllHistory removes sessions for the current user', () async {
    final auth = _RecordingAuthRepository('owner-1');
    final sessions = _RecordingSessionRepository();
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
    );

    await controller.deleteAllHistory();

    expect(sessions.deletedOwners, ['owner-1']);
    expect(auth.deleteCalls, 0);
  });

  test('account deletion removes data before deleting auth account', () async {
    final order = <String>[];
    final auth = _RecordingAuthRepository('owner-1', order: order);
    final sessions = _RecordingSessionRepository(order: order);
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
    );

    await controller.deleteAccountAndData();

    expect(order, ['data', 'account']);
    expect(auth.deleteCalls, 1);
  });

  test('account is preserved when workout data deletion fails', () async {
    final auth = _RecordingAuthRepository('owner-1');
    final sessions = _RecordingSessionRepository(throwOnDeleteAll: true);
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
    );

    await expectLater(controller.deleteAccountAndData(), throwsStateError);

    expect(auth.deleteCalls, 0);
  });
}

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository(this.currentUserId, {this.order});

  @override
  final String? currentUserId;
  final List<String>? order;
  int deleteCalls = 0;

  @override
  AuthUser? get currentUser => currentUserId == null
      ? null
      : AuthUser(
          uid: currentUserId!,
          email: null,
          displayName: null,
          isAnonymous: true,
        );

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<void> signInAnonymously() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls++;
    order?.add('account');
  }
}

class _RecordingSessionRepository implements SessionRepository {
  _RecordingSessionRepository({this.order, this.throwOnDeleteAll = false});

  final List<String>? order;
  final bool throwOnDeleteAll;
  final List<String> deletedOwners = <String>[];

  @override
  Future<void> deleteAllSessions({required String ownerId}) async {
    if (throwOnDeleteAll) throw StateError('offline');
    deletedOwners.add(ownerId);
    order?.add('data');
  }

  @override
  Future<void> deleteSession({
    required String ownerId,
    required String sessionId,
  }) async {}

  @override
  Future<WorkoutSession?> getSessionById({
    required String ownerId,
    required String sessionId,
  }) async => null;

  @override
  Future<List<WorkoutRep>> listSessionReps({
    required String ownerId,
    required String sessionId,
  }) async => const [];

  @override
  Future<List<WorkoutSession>> listSessions({
    required String ownerId,
    int limit = 20,
    String? exerciseType,
    WorkoutSession? startAfter,
  }) async => const [];

  @override
  Future<void> saveSession(WorkoutSession session) async {}
}
