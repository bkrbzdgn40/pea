import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/repositories/session_repository.dart';
import '../../infrastructure/remote/firestore_session_remote_source.dart';
import '../../infrastructure/repositories/firestore_session_repository.dart';

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firestoreSessionRemoteSourceProvider =
    Provider<FirestoreSessionRemoteSource>((ref) {
      return FirestoreSessionRemoteSource(ref.watch(firebaseFirestoreProvider));
    });

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return FirestoreSessionRepository(
    ref.watch(firestoreSessionRemoteSourceProvider),
  );
});
