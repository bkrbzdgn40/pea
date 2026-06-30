import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/repositories/auth_repository.dart';
import '../../domain/models/auth_user.dart';
import '../../infrastructure/repositories/firebase_auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentAuthUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentAuthUserProvider)?.uid;
});
