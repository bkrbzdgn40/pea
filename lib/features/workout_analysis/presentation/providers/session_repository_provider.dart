import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../application/repositories/session_repository.dart';
import '../../infrastructure/remote/firebase_session_write_auth_guard.dart';
import '../../infrastructure/remote/firestore_session_remote_source.dart';
import '../../infrastructure/repositories/firestore_session_repository.dart';

final sessionWriteAuthGuardProvider = Provider<SessionWriteAuthGuard>((ref) {
  return FirebaseSessionWriteAuthGuard(ref.watch(firebaseAuthProvider));
});

final firestoreSessionRemoteSourceProvider =
    Provider<FirestoreSessionRemoteSource>((ref) {
      return FirestoreSessionRemoteSource(
        ref.watch(firebaseFirestoreProvider),
        authGuard: ref.watch(sessionWriteAuthGuardProvider),
      );
    });

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return FirestoreSessionRepository(
    ref.watch(firestoreSessionRemoteSourceProvider),
  );
});
