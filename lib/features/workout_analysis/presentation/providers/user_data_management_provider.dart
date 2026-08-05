import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../application/user_data_management_controller.dart';
import 'session_repository_provider.dart';

final userDataManagementControllerProvider =
    Provider<UserDataManagementController>((ref) {
      return UserDataManagementController(
        authRepository: ref.watch(authRepositoryProvider),
        sessionRepository: ref.watch(sessionRepositoryProvider),
        readWorkoutGoalRepository: () =>
            ref.read(workoutGoalRepositoryProvider),
      );
    });
