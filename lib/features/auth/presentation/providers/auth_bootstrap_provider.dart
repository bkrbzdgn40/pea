import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

final authBootstrapProvider = FutureProvider<AuthBootstrapState>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);

  if (authRepository.currentUserId != null) {
    return const AuthBootstrapState.ready(didCreateAnonymousSession: false);
  }

  try {
    await authRepository.signInAnonymously();

    if (authRepository.currentUserId == null) {
      return const AuthBootstrapState.error('Kullanıcı oturumu hazırlanamadı.');
    }

    return const AuthBootstrapState.ready(didCreateAnonymousSession: true);
  } catch (error) {
    return AuthBootstrapState.error(error.toString());
  }
});

class AuthBootstrapState {
  const AuthBootstrapState._({
    required this.isReady,
    required this.didCreateAnonymousSession,
    this.errorMessage,
  });

  const AuthBootstrapState.ready({required bool didCreateAnonymousSession})
    : this._(
        isReady: true,
        didCreateAnonymousSession: didCreateAnonymousSession,
      );

  const AuthBootstrapState.error(String errorMessage)
    : this._(
        isReady: false,
        didCreateAnonymousSession: false,
        errorMessage: errorMessage,
      );

  final bool isReady;
  final bool didCreateAnonymousSession;
  final String? errorMessage;
}
