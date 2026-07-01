import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

// Uygulama acilisinda kullanici oturumunu hazirlar.
final authBootstrapProvider = FutureProvider<AuthBootstrapState>((ref) async {
  final authRepository = ref.read(authRepositoryProvider);

  if (authRepository.currentUserId != null) {
    return const AuthBootstrapState.ready(didCreateAnonymousSession: false);
  }

  try {
    await authRepository.signInAnonymously();

    if (authRepository.currentUserId == null) {
      return const AuthBootstrapState.error('Kullanici oturumu hazirlanamadi.');
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

  // Basarili bootstrap durumunu uretir.
  const AuthBootstrapState.ready({required bool didCreateAnonymousSession})
    : this._(
        isReady: true,
        didCreateAnonymousSession: didCreateAnonymousSession,
      );

  // Hata olusursa hata state'ini uretir.
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
