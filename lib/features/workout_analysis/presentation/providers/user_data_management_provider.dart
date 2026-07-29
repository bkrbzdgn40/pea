import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/user_data_management_controller.dart';
import 'session_repository_provider.dart';

final userDataManagementControllerProvider =
    Provider<UserDataManagementController>((ref) {
      return UserDataManagementController(
        authRepository: ref.watch(authRepositoryProvider),
        sessionRepository: ref.watch(sessionRepositoryProvider),
      );
    });
