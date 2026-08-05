import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/application/repositories/auth_repository.dart';
import 'package:pose_estimation_app/features/auth/domain/models/auth_user.dart';
import 'package:pose_estimation_app/features/goals/application/repositories/workout_goal_repository.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/repositories/session_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/user_data_management_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  test('deleteAllHistory removes only sessions for the current user', () async {
    final auth = _RecordingAuthRepository('owner-1');
    final sessions = _RecordingSessionRepository();
    final goals = _RecordingGoalRepository();
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
      readWorkoutGoalRepository: () => goals,
    );

    await controller.deleteAllHistory();

    expect(sessions.deletedOwners, ['owner-1']);
    expect(goals.deletedOwners, isEmpty);
    expect(auth.deleteCalls, 0);
  });

  test('account deletion removes sessions and goals before auth', () async {
    final order = <String>[];
    final auth = _RecordingAuthRepository('owner-1', order: order);
    final sessions = _RecordingSessionRepository(order: order);
    final goals = _RecordingGoalRepository(order: order);
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
      readWorkoutGoalRepository: () => goals,
    );

    await controller.deleteAccountAndData();

    expect(order, ['sessions', 'goals', 'account']);
    expect(goals.deletedOwners, ['owner-1']);
    expect(auth.deleteCalls, 1);
  });

  test('account and goals are preserved when session deletion fails', () async {
    final auth = _RecordingAuthRepository('owner-1');
    final sessions = _RecordingSessionRepository(throwOnDeleteAll: true);
    final goals = _RecordingGoalRepository();
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
      readWorkoutGoalRepository: () => goals,
    );

    await expectLater(controller.deleteAccountAndData(), throwsStateError);

    expect(goals.deletedOwners, isEmpty);
    expect(auth.deleteCalls, 0);
  });

  test('account is preserved when goal deletion fails', () async {
    final auth = _RecordingAuthRepository('owner-1');
    final sessions = _RecordingSessionRepository();
    final goals = _RecordingGoalRepository(throwOnDeleteAll: true);
    final controller = UserDataManagementController(
      authRepository: auth,
      sessionRepository: sessions,
      readWorkoutGoalRepository: () => goals,
    );

    await expectLater(controller.deleteAccountAndData(), throwsStateError);

    expect(sessions.deletedOwners, ['owner-1']);
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

class _RecordingGoalRepository implements WorkoutGoalRepository {
  _RecordingGoalRepository({this.order, this.throwOnDeleteAll = false});

  final List<String>? order;
  final bool throwOnDeleteAll;
  final List<String> deletedOwners = <String>[];

  @override
  Future<List<UserWorkoutGoal>> listGoals({required String ownerId}) async {
    return const <UserWorkoutGoal>[];
  }

  @override
  Future<void> activateGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required double targetValue,
    required DateTime now,
  }) async {}

  @override
  Future<void> deleteAllGoals({required String ownerId}) async {
    if (throwOnDeleteAll) throw StateError('offline');
    deletedOwners.add(ownerId);
    order?.add('goals');
  }

  @override
  Future<void> pauseGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required DateTime now,
  }) async {}
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
    order?.add('sessions');
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
