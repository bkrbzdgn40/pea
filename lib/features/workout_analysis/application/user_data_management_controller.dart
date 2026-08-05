import '../../auth/application/repositories/auth_repository.dart';
import '../../goals/application/repositories/workout_goal_repository.dart';
import 'repositories/session_repository.dart';

class UserDataManagementController {
  const UserDataManagementController({
    required AuthRepository authRepository,
    required SessionRepository sessionRepository,
    required WorkoutGoalRepository Function() readWorkoutGoalRepository,
  }) : _authRepository = authRepository,
       _sessionRepository = sessionRepository,
       _readWorkoutGoalRepository = readWorkoutGoalRepository;

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;
  final WorkoutGoalRepository Function() _readWorkoutGoalRepository;

  Future<void> deleteAllHistory() async {
    final ownerId = _requireCurrentUserId();
    await _sessionRepository.deleteAllSessions(ownerId: ownerId);
  }

  Future<void> deleteAccountAndData() async {
    final ownerId = _requireCurrentUserId();
    await _sessionRepository.deleteAllSessions(ownerId: ownerId);
    await _readWorkoutGoalRepository().deleteAllGoals(ownerId: ownerId);
    await _authRepository.deleteCurrentUser();
  }

  String _requireCurrentUserId() {
    final ownerId = _authRepository.currentUserId;
    if (ownerId == null) {
      throw const UserDataManagementFailure('No authenticated user.');
    }
    return ownerId;
  }
}

class UserDataManagementFailure implements Exception {
  const UserDataManagementFailure(this.message);

  final String message;

  @override
  String toString() => 'UserDataManagementFailure: $message';
}
